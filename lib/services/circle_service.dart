import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// A circle the person is in, as listed on the Prayer Circles screen.
class CircleSummary {
  const CircleSummary({required this.code, required this.name, required this.members, this.owner = false, this.latest});

  factory CircleSummary.fromJson(Map<String, dynamic> j) => CircleSummary(
    code: j['code'] as String,
    name: j['name'] as String,
    members: (j['members'] as num?)?.toInt() ?? 0,
    owner: j['owner'] == true,
    latest: DateTime.tryParse(j['latest'] as String? ?? ''),
  );

  final String code, name;
  final int members;
  final bool owner;

  /// When the newest request came in; null with none yet.
  final DateTime? latest;

  Map<String, dynamic> toJson() => {
    'code': code,
    'name': name,
    'members': members,
    'owner': owner,
    'latest': latest?.toIso8601String(),
  };
}

class CircleMember {
  const CircleMember({required this.id, required this.name, this.owner = false, this.me = false});

  factory CircleMember.fromJson(Map<String, dynamic> j) => CircleMember(
    id: (j['id'] as num).toInt(),
    name: j['name'] as String,
    owner: j['owner'] == true,
    me: j['me'] == true,
  );

  final int id;
  final String name;
  final bool owner, me;
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
  });

  factory CircleRequest.fromJson(Map<String, dynamic> j) => CircleRequest(
    id: (j['id'] as num).toInt(),
    name: j['name'] as String,
    text: j['text'] as String,
    at: DateTime.tryParse(j['at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
    answered: j['answered'] == true,
    prayed: (j['prayed'] as num?)?.toInt() ?? 0,
    prayedByMe: j['prayedByMe'] == true,
    mine: j['mine'] == true,
  );

  final int id;
  final String name, text;
  final DateTime at;
  final bool answered;
  final int prayed;
  final bool prayedByMe, mine;
}

class CircleDetail {
  const CircleDetail({
    required this.code,
    required this.name,
    this.owner = false,
    this.members = const [],
    this.requests = const [],
  });

  factory CircleDetail.fromJson(Map<String, dynamic> j) => CircleDetail(
    code: j['code'] as String,
    name: j['name'] as String,
    owner: j['owner'] == true,
    members: [for (final m in j['members'] as List? ?? const []) CircleMember.fromJson(m as Map<String, dynamic>)],
    requests: [for (final r in j['requests'] as List? ?? const []) CircleRequest.fromJson(r as Map<String, dynamic>)],
  );

  final String code, name;

  /// The person started the circle (or it passed to them).
  final bool owner;
  final List<CircleMember> members;

  /// Newest first.
  final List<CircleRequest> requests;
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
///   POST   /v1/circles            {name, memberName}  → CircleDetail
///   POST   /v1/circles/join       {code, memberName}  → CircleDetail
///   GET    /v1/circles/{code}                         → CircleDetail
///   POST   /v1/circles/{code}/requests {text}         → CircleDetail
///   POST   /v1/circles/{code}/requests/{id}/prayed | answered | report → CircleDetail
///   DELETE /v1/circles/{code}/requests/{id}           → CircleDetail
///   DELETE /v1/circles/{code}/members/{id}            → CircleDetail (owner only)
///   POST   /v1/circles/{code}/leave                   → 204
///
/// The list of circles is kept on the phone, so it still shows offline.
class CircleService {
  CircleService(this._prefs, {required this.baseUrl, required this.installId, http.Client? client})
    : _client = client ?? http.Client();

  final SharedPreferences _prefs;
  final String baseUrl;
  final String Function() installId;
  final http.Client _client;

  static const _listKey = 'circles';
  static String _seenKey(String code) => 'circleSeen:$code';

  /// "K7P3MX" → "K7P-3MX", easier to read out and type.
  static String showCode(String code) => code.length == 6 ? '${code.substring(0, 3)}-${code.substring(3)}' : code;

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
    final newest = c.requests.isEmpty ? null : c.requests.first.at.toUtc();
    if (newest != null) await _prefs.setString(_seenKey(c.code), newest.toIso8601String());
  }

  Future<List<CircleSummary>> mine() async {
    final list = [for (final c in await _call('GET', '') as List) CircleSummary.fromJson(c as Map<String, dynamic>)];
    await _prefs.setString(_listKey, jsonEncode([for (final c in list) c.toJson()]));
    return list;
  }

  Future<CircleDetail> create(String name, String memberName) =>
      _detail('POST', '', {'name': name, 'memberName': memberName});

  Future<CircleDetail> join(String code, String memberName) =>
      _detail('POST', '/join', {'code': code, 'memberName': memberName});

  Future<CircleDetail> open(String code) => _detail('GET', '/$code');

  Future<CircleDetail> ask(String code, String text) => _detail('POST', '/$code/requests', {'text': text});

  Future<CircleDetail> prayed(String code, int request) => _detail('POST', '/$code/requests/$request/prayed');

  Future<CircleDetail> answered(String code, int request) => _detail('POST', '/$code/requests/$request/answered');

  Future<CircleDetail> report(String code, int request) => _detail('POST', '/$code/requests/$request/report');

  Future<CircleDetail> deleteRequest(String code, int request) => _detail('DELETE', '/$code/requests/$request');

  Future<CircleDetail> removeMember(String code, int member) => _detail('DELETE', '/$code/members/$member');

  Future<void> leave(String code) async {
    await _call('POST', '/$code/leave');
    await _prefs.remove(_seenKey(code));
    await _prefs.setString(_listKey, jsonEncode([for (final c in saved) if (c.code != code) c.toJson()]));
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
