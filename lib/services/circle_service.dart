import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

DateTime? _time(Object? s) => DateTime.tryParse(s as String? ?? '')?.toLocal();

List<T> _list<T>(Object? list, T Function(Map<String, dynamic>) read) => [
  for (final x in list as List? ?? const []) read(x as Map<String, dynamic>),
];

/// A circle the person is in, as listed on the Prayer Circles screen.
class CircleSummary {
  const CircleSummary({
    required this.code,
    required this.name,
    required this.members,
    this.owner = false,
    this.latest,
    this.parent,
    this.pending = false,
    this.church = false,
  });

  factory CircleSummary.fromJson(Map<String, dynamic> j) => CircleSummary(
    code: j['code'] as String,
    name: j['name'] as String,
    members: (j['members'] as num?)?.toInt() ?? 0,
    owner: j['owner'] == true,
    latest: DateTime.tryParse(j['latest'] as String? ?? ''),
    parent: j['parent'] as String?,
    pending: j['pending'] == true,
    church: j['church'] == true,
  );

  final String code, name;
  final int members;
  final bool owner;

  /// When the newest request came in; null with none yet.
  final DateTime? latest;

  /// For one of a church's circles: the church's name.
  final String? parent;

  /// Asked to join, and waiting for a leader to let them in.
  final bool pending;

  /// A church: the home of its circles, with its own prayer wall.
  final bool church;

  Map<String, dynamic> toJson() => {
    'code': code,
    'name': name,
    'members': members,
    'owner': owner,
    'latest': latest?.toIso8601String(),
    'parent': parent,
    'pending': pending,
    'church': church,
  };
}

class CircleMember {
  const CircleMember({required this.id, required this.name, this.owner = false, this.leader = false, this.me = false});

  factory CircleMember.fromJson(Map<String, dynamic> j) => CircleMember(
    id: (j['id'] as num).toInt(),
    name: j['name'] as String,
    owner: j['owner'] == true,
    leader: j['leader'] == true,
    me: j['me'] == true,
  );

  final int id;
  final String name;

  /// [leader]: made a leader by the owner (the owner isn't marked a leader).
  final bool owner, leader, me;
}

class CircleRequest {
  const CircleRequest({
    required this.id,
    required this.name,
    required this.text,
    required this.at,
    this.answered = false,
    this.prayed = 0,
    this.prayedByMe = false,
    this.mine = false,
    this.prayerId,
    this.hearts = 0,
    this.heartedByMe = false,
    this.leader = false,
    this.pinned = false,
    this.forLeaders = false,
    this.anonymous = false,
    this.praise = false,
    this.testimony,
    this.verse,
    this.answeredAt,
  });

  factory CircleRequest.fromJson(Map<String, dynamic> j) => CircleRequest(
    id: (j['id'] as num).toInt(),
    name: j['name'] as String,
    text: j['text'] as String,
    at: _time(j['at']) ?? DateTime.now(),
    answered: j['answered'] == true,
    prayed: (j['prayed'] as num?)?.toInt() ?? 0,
    prayedByMe: j['prayedByMe'] == true,
    mine: j['mine'] == true,
    prayerId: j['prayerId'] as String?,
    hearts: (j['hearts'] as num?)?.toInt() ?? 0,
    heartedByMe: j['heartedByMe'] == true,
    leader: j['leader'] == true,
    pinned: j['pinned'] == true,
    forLeaders: j['forLeaders'] == true,
    anonymous: j['anonymous'] == true,
    praise: j['praise'] == true,
    testimony: j['testimony'] as String?,
    verse: j['verse'] as String?,
    answeredAt: _time(j['answeredAt']),
  );

  final int id;
  final String name, text;
  final DateTime at;
  final bool answered;
  final int prayed;
  final bool prayedByMe, mine;

  /// A ready prayer shared to pray together; [text] is then an optional note.
  final String? prayerId;
  final int hearts;
  final bool heartedByMe;

  /// Asked by the owner or a leader.
  final bool leader;

  /// The circle's prayer focus, shown first.
  final bool pinned;

  /// Only the owner and leaders see it (and the asker).
  final bool forLeaders;

  /// Asked without a name. For members [name] is then empty; the asker and leaders still see it.
  final bool anonymous;

  /// A praise report, shared as such (never asked); [text] tells what God did.
  final bool praise;

  /// How God answered, added when it was marked answered.
  final String? testimony;

  /// A Bible verse shared ("JHN 3:16"), shown from the reader's own Bible; [text] is then an optional note.
  final String? verse;
  final DateTime? answeredAt;

  /// Who asked is hidden from the reader.
  bool get nameHidden => name.isEmpty;
}

/// A group of a church (Youth, a home group), as the church's members see it.
class CircleGroup {
  const CircleGroup({
    required this.code,
    required this.name,
    this.members = 0,
    this.joined = false,
    this.pending = false,
  });

  factory CircleGroup.fromJson(Map<String, dynamic> j) => CircleGroup(
    code: j['code'] as String,
    name: j['name'] as String,
    members: (j['members'] as num?)?.toInt() ?? 0,
    joined: j['joined'] == true,
    pending: j['pending'] == true,
  );

  final String code, name;
  final int members;

  /// The reader is in it, or waits to be let in.
  final bool joined, pending;
}

/// A turn someone took in a prayer chain.
class ChainTurn {
  const ChainTurn({required this.slot, required this.name, this.mine = false});

  factory ChainTurn.fromJson(Map<String, dynamic> j) =>
      ChainTurn(slot: (j['slot'] as num).toInt(), name: j['name'] as String, mine: j['mine'] == true);

  final int slot;
  final String name;
  final bool mine;
}

/// A prayer chain, or fasting days: [slots] turns of [slotMinutes] each, from [startsAt].
class PrayerChain {
  const PrayerChain({
    required this.id,
    required this.title,
    required this.startsAt,
    required this.slotMinutes,
    required this.slots,
    this.mine = false,
    this.turns = const [],
  });

  factory PrayerChain.fromJson(Map<String, dynamic> j) => PrayerChain(
    id: (j['id'] as num).toInt(),
    title: j['title'] as String,
    startsAt: _time(j['startsAt']) ?? DateTime.now(),
    slotMinutes: (j['slotMinutes'] as num).toInt(),
    slots: (j['slots'] as num).toInt(),
    mine: j['mine'] == true,
    turns: _list(j['turns'], ChainTurn.fromJson),
  );

  final int id;
  final String title;
  final DateTime startsAt;
  final int slotMinutes, slots;

  /// The reader started it.
  final bool mine;
  final List<ChainTurn> turns;

  /// Turns of a day: fasting days, rather than hours of prayer.
  bool get fasting => slotMinutes >= 1440;

  DateTime slotStart(int slot) => startsAt.add(Duration(minutes: slotMinutes * slot));
  DateTime get endsAt => slotStart(slots);
  List<ChainTurn> turnsAt(int slot) => [
    for (final t in turns)
      if (t.slot == slot) t,
  ];
}

class CircleDetail {
  const CircleDetail({
    required this.code,
    required this.name,
    this.owner = false,
    this.leader = false,
    this.members = const [],
    this.requests = const [],
    this.pending = false,
    this.approval = false,
    this.waiting = const [],
    this.parentCode,
    this.parentName,
    this.groups = const [],
    this.praise = const [],
    this.chains = const [],
    this.church = false,
  });

  factory CircleDetail.fromJson(Map<String, dynamic> j) {
    final parent = j['parent'] as Map<String, dynamic>?;
    return CircleDetail(
      code: j['code'] as String,
      name: j['name'] as String,
      owner: j['owner'] == true,
      leader: j['leader'] == true,
      members: _list(j['members'], CircleMember.fromJson),
      requests: _list(j['requests'], CircleRequest.fromJson),
      pending: j['pending'] == true,
      approval: j['approval'] == true,
      waiting: _list(j['waiting'], CircleMember.fromJson),
      parentCode: parent?['code'] as String?,
      parentName: parent?['name'] as String?,
      groups: _list(j['groups'], CircleGroup.fromJson),
      praise: _list(j['praise'], CircleRequest.fromJson),
      chains: _list(j['chains'], PrayerChain.fromJson),
      church: j['church'] == true,
    );
  }

  final String code, name;

  /// The person started the circle (or it passed to them).
  final bool owner;

  /// The person is the owner or a leader: can pin, delete requests and remove members.
  final bool leader;
  final List<CircleMember> members;

  /// The pinned one first, then newest first.
  final List<CircleRequest> requests;

  /// The person asked to join and waits for a leader; nothing else is filled in then.
  final bool pending;

  /// New members wait for a leader to let them in.
  final bool approval;

  /// Who waits to be let in (for the owner and leaders only).
  final List<CircleMember> waiting;

  /// For one of a church's circles: its church. [parentCode] only when the person is in the church too.
  final String? parentCode, parentName;

  /// A church's circles (none for a circle).
  final List<CircleGroup> groups;

  /// The praise wall: answered prayers and praise reports, the newest answer first.
  final List<CircleRequest> praise;
  final List<PrayerChain> chains;

  /// A church: the home of its circles, with a prayer wall for the whole church. Only a church holds
  /// circles.
  final bool church;

  /// One of a church's circles.
  bool get isGroup => parentName != null;
}

enum CircleNewsKind { request, prayer, verse, prayed, answered, joined, waiting, approved, chain, group }

/// Something new in one of the person's circles, shown as a popup when they open the app.
class CircleNews {
  const CircleNews({
    required this.kind,
    required this.circle,
    required this.circleName,
    this.requestId,
    this.name = '',
    this.text = '',
    this.prayerId,
    this.count = 0,
    this.crisis = false,
    this.verse,
    this.testimony,
    this.group,
  });

  /// Null for a kind this version of the app doesn't know.
  static CircleNews? fromJson(Map<String, dynamic> j) {
    final kind = CircleNewsKind.values.where((k) => k.name == j['kind']).firstOrNull;
    if (kind == null) return null;
    return CircleNews(
      kind: kind,
      circle: j['circle'] as String,
      circleName: j['circleName'] as String,
      requestId: (j['requestId'] as num?)?.toInt(),
      name: j['name'] as String? ?? '',
      text: j['text'] as String? ?? '',
      prayerId: j['prayerId'] as String?,
      count: (j['count'] as num?)?.toInt() ?? 0,
      crisis: j['crisis'] == true,
      verse: j['verse'] as String?,
      testimony: j['testimony'] as String?,
      group: j['group'] as String?,
    );
  }

  final CircleNewsKind kind;

  /// The circle's code and name.
  final String circle, circleName;

  /// The request, or for [CircleNewsKind.chain] the chain.
  final int? requestId;

  /// Who asked, shared or joined; for [CircleNewsKind.group], the new group.
  final String name;

  /// The request, the note with a shared prayer or verse, or a chain's title.
  final String text;
  final String? prayerId;

  /// How many prayed ([CircleNewsKind.prayed]), joined or wait, the latest of them [name].
  final int count;

  /// For a leader: whoever asked may be thinking of ending their life. Shown before anything else.
  final bool crisis;

  /// A shared Bible verse ("JHN 3:16").
  final String? verse;

  /// How God answered ([CircleNewsKind.answered]).
  final String? testimony;

  /// A new group's code ([CircleNewsKind.group]).
  final String? group;
}

/// [notAllowed]: taken out of the circle, or not theirs to change.
enum CircleProblem { offline, notFound, full, tooMany, notAllowed }

class CircleException implements Exception {
  const CircleException(this.problem);
  final CircleProblem problem;

  @override
  String toString() => 'CircleException($problem)';
}

/// Prayer circles: a few people who pray for each other, joined with a short code.
///
/// Contract — {baseUrl}/v1/circles…, anonymous with the random install id (X-Install-Id), as for the counts:
///   GET    /v1/circles                                → [CircleSummary]
///   POST   /v1/circles            {name, memberName, church?} → CircleDetail (a church starts with approval on)
///   POST   /v1/circles/join       {code, memberName}  → CircleDetail (pending when approval is on)
///   GET    /v1/circles/{code}                         → CircleDetail
///   POST   /v1/circles/{code}/requests {text, forLeaders?, anonymous?} → CircleDetail
///   POST   /v1/circles/{code}/requests {prayerId | verse, text?} → CircleDetail (a ready prayer or verse, with a note)
///   POST   /v1/circles/{code}/requests {text, praise: true} → CircleDetail (a praise report)
///   POST | DELETE /v1/circles/{code}/requests/{id}/heart → CircleDetail
///   POST   /v1/circles/{code}/requests/{id}/prayed | report → CircleDetail
///   POST   /v1/circles/{code}/requests/{id}/answered {testimony?} → CircleDetail
///   POST | DELETE /v1/circles/{code}/requests/{id}/pin → CircleDetail (owner or leader)
///   DELETE /v1/circles/{code}/requests/{id}           → CircleDetail
///   DELETE /v1/circles/{code}/members/{id}            → CircleDetail (owner, or a leader for members)
///   POST | DELETE /v1/circles/{code}/members/{id}/leader → CircleDetail (owner only)
///   POST | DELETE /v1/circles/{code}/approval         → CircleDetail (owner only)
///   POST   /v1/circles/{code}/waiting/{id}/approve, DELETE /v1/circles/{code}/waiting/{id} → CircleDetail
///   POST   /v1/circles/{code}/groups {name}           → CircleDetail (a circle in a church; the church's owner or a leader)
///   POST   /v1/circles/{code}/chains {title, startsAt, slotMinutes, slots} → CircleDetail (owner or leader)
///   DELETE /v1/circles/{code}/chains/{id}             → CircleDetail
///   POST | DELETE /v1/circles/{code}/chains/{id}/turns/{slot} → CircleDetail
///   POST   /v1/circles/{code}/leave                   → 204 (also stops waiting)
///   GET    /v1/circles/news?since=…                   → {now, items: [CircleNews]}
///
/// The list of circles is kept on the phone, so it still shows offline.
class CircleService {
  CircleService(this._prefs, {required this.baseUrl, required this.installId, http.Client? client})
    : _client = client ?? http.Client();

  final SharedPreferences _prefs;
  final String baseUrl;
  final String Function() installId;
  final http.Client _client;

  /// The server's limits (backend CircleService), shown in "How prayer circles work".
  static const maxMembers = 500, maxCircles = 20, keepDays = 60, keepPraiseDays = 365;

  static const _listKey = 'circles';
  static const _newsKey = 'circleNewsSince';
  static String _seenKey(String code) => 'circleSeen:$code';

  /// "K7P3MX" → "K7P-3MX", easier to read out and type.
  static String showCode(String code) => code.length == 6 ? '${code.substring(0, 3)}-${code.substring(3)}' : code;

  /// What a QR code on the church's screen and a shared invite hold: the server's web page for the invite
  /// ([baseUrl]/join/K7P3MX), which opens the app to join, or shows someone without the app where to get
  /// it. Without a server, the app's own link (only for phones that have the app).
  static String joinLink(String code, {String baseUrl = ''}) =>
      baseUrl.isEmpty ? 'jesusanswers://app/join/$code' : '$baseUrl/join/$code';

  /// A code as people type or copy it ("k7p-3mx", "K7P3MX"), or null when [text] isn't one.
  static String? codeIn(String? text) {
    final code = (text ?? '').trim().toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
    return RegExp(r'^[A-HJ-NP-Z2-9]{6}$').hasMatch(code) ? code : null;
  }

  /// The circles as last fetched.
  List<CircleSummary> get saved {
    try {
      return [
        for (final c in jsonDecode(_prefs.getString(_listKey) ?? '[]') as List)
          CircleSummary.fromJson(c as Map<String, dynamic>),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Something came in since the person last opened [c].
  bool hasNew(CircleSummary c) {
    final seen = DateTime.tryParse(_prefs.getString(_seenKey(c.code)) ?? '');
    return c.latest != null && (seen == null || c.latest!.isAfter(seen));
  }

  Future<void> markSeen(CircleDetail c) async {
    // Not simply the first: a pinned prayer focus comes first, however old.
    final newest = c.requests.isEmpty
        ? null
        : c.requests.map((r) => r.at).reduce((a, b) => a.isAfter(b) ? a : b).toUtc();
    if (newest != null) await _prefs.setString(_seenKey(c.code), newest.toIso8601String());
  }

  /// After taking on the old phone's install id: forget this phone's own list, and start the news afresh
  /// rather than bring everything that happened as popups.
  Future<void> startOver() async {
    await _prefs.remove(_listKey);
    await _prefs.remove(_newsKey);
  }

  Future<List<CircleSummary>> mine() async {
    final list = [for (final c in await _call('GET', '') as List) CircleSummary.fromJson(c as Map<String, dynamic>)];
    await _prefs.setString(_listKey, jsonEncode([for (final c in list) c.toJson()]));
    return list;
  }

  /// What happened in the person's circles since they last asked, oldest first. The first time
  /// there is nothing yet: it only notes where to start from.
  Future<List<CircleNews>> news() async {
    if (baseUrl.isEmpty || saved.isEmpty) return const [];
    final since = _prefs.getString(_newsKey);
    final page = await _call(
      'GET',
      '/news${since == null ? '' : '?since=${Uri.encodeQueryComponent(since)}'}',
    ) as Map<String, dynamic>;
    await _prefs.setString(_newsKey, page['now'] as String);
    return [for (final n in page['items'] as List? ?? const []) ?CircleNews.fromJson(n as Map<String, dynamic>)];
  }

  /// Starts a circle, or with [church] a church.
  Future<CircleDetail> create(String name, String memberName, {bool church = false}) =>
      _detail('POST', '', {'name': name, 'memberName': memberName, if (church) 'church': true});

  /// Joins; or with approval on, asks to join ([CircleDetail.pending]).
  Future<CircleDetail> join(String code, String memberName) =>
      _detail('POST', '/join', {'code': code, 'memberName': memberName});

  Future<CircleDetail> open(String code) => _detail('GET', '/$code');

  /// [forLeaders]: only the owner and leaders will see it. [anonymous]: members won't see who asked.
  Future<CircleDetail> ask(String code, String text, {bool forLeaders = false, bool anonymous = false}) => _detail(
    'POST',
    '/$code/requests',
    {'text': text, if (forLeaders) 'forLeaders': true, if (anonymous) 'anonymous': true},
  );

  Future<CircleDetail> sharePrayer(String code, String prayerId, String note) =>
      _detail('POST', '/$code/requests', {'prayerId': prayerId, 'text': note});

  /// A Bible verse ("JHN 3:16"), with a note: the week's sermon, say.
  Future<CircleDetail> shareVerse(String code, String verse, String note) =>
      _detail('POST', '/$code/requests', {'verse': verse, 'text': note});

  /// A praise report for the praise wall: what God did, never asked as a request.
  Future<CircleDetail> praise(String code, String text) =>
      _detail('POST', '/$code/requests', {'text': text, 'praise': true});

  Future<CircleDetail> heart(String code, int request, {required bool on}) =>
      _detail(on ? 'POST' : 'DELETE', '/$code/requests/$request/heart');

  Future<CircleDetail> prayed(String code, int request) => _detail('POST', '/$code/requests/$request/prayed');

  /// [testimony]: how God answered, for the praise wall.
  Future<CircleDetail> answered(String code, int request, {String? testimony}) => _detail(
    'POST',
    '/$code/requests/$request/answered',
    testimony == null || testimony.trim().isEmpty ? null : {'testimony': testimony.trim()},
  );

  Future<CircleDetail> report(String code, int request) => _detail('POST', '/$code/requests/$request/report');

  Future<CircleDetail> deleteRequest(String code, int request) => _detail('DELETE', '/$code/requests/$request');

  Future<CircleDetail> pin(String code, int request, {required bool on}) =>
      _detail(on ? 'POST' : 'DELETE', '/$code/requests/$request/pin');

  Future<CircleDetail> removeMember(String code, int member) => _detail('DELETE', '/$code/members/$member');

  Future<CircleDetail> setLeader(String code, int member, {required bool on}) =>
      _detail(on ? 'POST' : 'DELETE', '/$code/members/$member/leader');

  Future<CircleDetail> setApproval(String code, {required bool on}) =>
      _detail(on ? 'POST' : 'DELETE', '/$code/approval');

  Future<CircleDetail> approve(String code, int waiting) => _detail('POST', '/$code/waiting/$waiting/approve');

  Future<CircleDetail> decline(String code, int waiting) => _detail('DELETE', '/$code/waiting/$waiting');

  /// Adds a group to a church; answers with the church.
  Future<CircleDetail> createGroup(String code, String name) => _detail('POST', '/$code/groups', {'name': name});

  Future<CircleDetail> createChain(
    String code, {
    required String title,
    required DateTime startsAt,
    required int slotMinutes,
    required int slots,
  }) => _detail('POST', '/$code/chains', {
    'title': title,
    'startsAt': startsAt.toUtc().toIso8601String(),
    'slotMinutes': slotMinutes,
    'slots': slots,
  });

  Future<CircleDetail> deleteChain(String code, int chain) => _detail('DELETE', '/$code/chains/$chain');

  Future<CircleDetail> turn(String code, int chain, int slot, {required bool on}) =>
      _detail(on ? 'POST' : 'DELETE', '/$code/chains/$chain/turns/$slot');

  /// Leaves, or stops waiting to be let in.
  Future<void> leave(String code) async {
    await _call('POST', '/$code/leave');
    await _forget(code);
  }

  /// Owner only: deletes the circle for everyone; a church with all its circles.
  Future<void> delete(String code) async {
    await _call('DELETE', '/$code');
    await _forget(code);
  }

  Future<void> _forget(String code) async {
    await _prefs.remove(_seenKey(code));
    await _prefs.setString(
      _listKey,
      jsonEncode([
        for (final c in saved)
          if (c.code != code) c.toJson(),
      ]),
    );
  }

  Future<CircleDetail> _detail(String method, String path, [Map<String, dynamic>? body]) async =>
      CircleDetail.fromJson(await _call(method, path, body) as Map<String, dynamic>);

  Future<Object?> _call(String method, String path, [Map<String, dynamic>? body]) async {
    if (baseUrl.isEmpty) throw const CircleException(CircleProblem.offline);
    final http.Response r;
    try {
      final request = http.Request(method, Uri.parse('$baseUrl/v1/circles$path'))
        ..headers.addAll({'X-Install-Id': installId(), 'content-type': 'application/json'});
      if (body != null) request.body = jsonEncode(body);
      r = await http.Response.fromStream(await _client.send(request).timeout(const Duration(seconds: 15)));
    } catch (_) {
      throw const CircleException(CircleProblem.offline);
    }
    switch (r.statusCode) {
      case 200:
        return jsonDecode(utf8.decode(r.bodyBytes));
      case 204:
        return null;
      case 404:
        throw const CircleException(CircleProblem.notFound);
      case 403:
        throw const CircleException(CircleProblem.notAllowed);
      case 409:
        throw const CircleException(CircleProblem.full);
      case 422:
        throw const CircleException(CircleProblem.tooMany);
      default:
        throw const CircleException(CircleProblem.offline);
    }
  }
}
