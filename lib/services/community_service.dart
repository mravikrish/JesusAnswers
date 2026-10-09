import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// How many people loved, prayed or listened to one item.
class ItemCounts {
  const ItemCounts({this.hearts = 0, this.prayed = 0, this.listened = 0, this.week = 0});

  factory ItemCounts.fromJson(Map<String, dynamic> j) => ItemCounts(
    hearts: (j['hearts'] as num?)?.toInt() ?? 0,
    prayed: (j['prayed'] as num?)?.toInt() ?? 0,
    listened: (j['listened'] as num?)?.toInt() ?? 0,
    week: (j['week'] as num?)?.toInt() ?? 0,
  );

  final int hearts, prayed, listened;

  /// Prayed + listened in the last 7 days.
  final int week;

  Map<String, int> toJson() => {'hearts': hearts, 'prayed': prayed, 'listened': listened, 'week': week};

  ItemCounts withHearts(int n) => ItemCounts(hearts: n < 0 ? 0 : n, prayed: prayed, listened: listened, week: week);
}

/// What other people loved, prayed and listened to, to draw people in: "1.2K prayed this".
///
/// Contract — {baseUrl}/v1/…, anonymous, with a random install id (X-Install-Id), never who the person is:
///   POST /v1/reactions  { "item": "prayer:hopeless", "kind": "HEART"|"UNHEART"|"PRAYED"|"LISTENED" }
///   GET  /v1/counts     { "today": 3200, "items": { "prayer:hopeless": {hearts, prayed, listened, week} } }
///
/// Hearts are kept on the phone too, so they work with no server. Only real counts are shown, and
/// only from [shownFrom] up; what couldn't be sent waits on the phone and goes with the next send.
class CommunityService extends ChangeNotifier {
  CommunityService(this._prefs, {this.baseUrl = '', http.Client? client}) : _client = client ?? http.Client() {
    _hearts.addAll(_prefs.getStringList(_heartsKey) ?? const []);
    try {
      final saved = jsonDecode(_prefs.getString(_countsKey) ?? '{}') as Map<String, dynamic>;
      _today = (saved['today'] as num?)?.toInt() ?? 0;
      (saved['items'] as Map<String, dynamic>? ?? {}).forEach(
        (k, v) => _counts[k] = ItemCounts.fromJson(v as Map<String, dynamic>),
      );
    } catch (_) {}
  }

  final SharedPreferences _prefs;
  final String baseUrl;
  final http.Client _client;

  /// Counts below this aren't shown: "3 prayed" draws no one in.
  static const shownFrom = 10;

  static const _installKey = 'installId',
      _heartsKey = 'hearts',
      _countsKey = 'communityCounts',
      _fetchedKey = 'communityFetchedAt',
      _queueKey = 'communityQueue';

  static const _refreshEvery = Duration(hours: 1);

  final _hearts = <String>{};
  final _counts = <String, ItemCounts>{};
  int _today = 0;

  static String prayer(String id) => 'prayer:$id';
  static String story(String id) => 'story:$id';
  static String chapter(String book, int chapter) => 'chapter:$book.$chapter';

  /// "MAT 11:28" → "saying:MAT.11.28".
  static String saying(String ref) => 'saying:${ref.replaceAll(RegExp('[ :]'), '.')}';

  String get installId {
    var id = _prefs.getString(_installKey);
    if (id == null) {
      id = const Uuid().v4();
      _prefs.setString(_installKey, id);
    }
    return id;
  }

  /// A key from the person's old phone ([installId] there), as they typed or pasted it; null if it isn't one.
  static String? keyIn(String text) {
    final id = text.trim().toLowerCase();
    return RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$').hasMatch(id) ? id : null;
  }

  /// Carries on as the person's old phone, whose [installId] this was: their prayer circles come along.
  Future<void> useInstallId(String id) => _prefs.setString(_installKey, id);

  bool loved(String item) => _hearts.contains(item);

  ItemCounts counts(String item) => _counts[item] ?? const ItemCounts();

  /// How many people prayed or listened today, everywhere.
  int get today => _today;

  /// The items of a kind ("prayer:", "story:") most prayed and listened to this week, most first.
  List<String> popular(String prefix, {int limit = 4}) {
    final list = [
      for (final MapEntry(:key, :value) in _counts.entries)
        if (key.startsWith(prefix) && value.week >= shownFrom) (key, value.week),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    return [for (final (item, _) in list.take(limit)) item.substring(prefix.length)];
  }

  Future<void> toggleHeart(String item) async {
    final on = !_hearts.contains(item);
    on ? _hearts.add(item) : _hearts.remove(item);
    // Shown at once; the next fetch brings the real number.
    _counts[item] = counts(item).withHearts(counts(item).hearts + (on ? 1 : -1));
    notifyListeners();
    await _prefs.setStringList(_heartsKey, _hearts.toList());
    await _send(item, on ? 'HEART' : 'UNHEART');
  }

  Future<void> prayed(String item) => _send(item, 'PRAYED');
  Future<void> listened(String item) => _send(item, 'LISTENED');

  /// One send at a time, so nothing waiting goes twice.
  Future<void> _sending = Future.value();

  Future<void> _send(String item, String kind) => _sending = _sending.then((_) => _sendNow(item, kind));

  /// Sends [kind] for [item] after anything still waiting; keeps what can't be sent for next time.
  Future<void> _sendNow(String item, String kind) async {
    if (baseUrl.isEmpty) return;
    final queue = [...?_prefs.getStringList(_queueKey), '$item|$kind'];
    var sent = 0;
    for (final entry in queue) {
      final [i, k] = entry.split('|');
      if (!await _post(i, k)) break;
      sent++;
    }
    // Keep at most a few hundred waiting, newest last.
    final left = queue.skip(sent).toList();
    await _prefs.setStringList(_queueKey, left.skip(left.length > 300 ? left.length - 300 : 0).toList());
  }

  Future<bool> _post(String item, String kind) async {
    try {
      final r = await _client
          .post(
            Uri.parse('$baseUrl/v1/reactions'),
            headers: {'content-type': 'application/json', 'X-Install-Id': installId},
            body: jsonEncode({'item': item, 'kind': kind}),
          )
          .timeout(const Duration(seconds: 10));
      // A rejected one (4xx) would never go through: drop it rather than block the rest.
      return r.statusCode < 500 && r.statusCode != 429;
    } catch (_) {
      return false;
    }
  }

  /// Fetches the counts, at most once an hour unless [force]d. Keeps the last ones if it can't.
  Future<void> refresh({bool force = false}) async {
    if (baseUrl.isEmpty) return;
    final last = DateTime.fromMillisecondsSinceEpoch(_prefs.getInt(_fetchedKey) ?? 0);
    if (!force && DateTime.now().difference(last) < _refreshEvery) return;
    try {
      final r = await _client.get(Uri.parse('$baseUrl/v1/counts')).timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return;
      final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      _today = (j['today'] as num?)?.toInt() ?? 0;
      _counts
        ..clear()
        ..addAll({
          for (final MapEntry(:key, :value) in (j['items'] as Map<String, dynamic>? ?? {}).entries)
            key: ItemCounts.fromJson(value as Map<String, dynamic>),
        });
      notifyListeners();
      await _prefs.setString(_countsKey, jsonEncode({'today': _today, 'items': _counts}));
      await _prefs.setInt(_fetchedKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }
}
