import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jesus_answers/features/circles/circles_screen.dart';
import 'package:jesus_answers/l10n/app_localizations.dart';
import 'package:jesus_answers/providers.dart';
import 'package:jesus_answers/services/circle_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<SharedPreferences> prefs() async {
    SharedPreferences.setMockInitialValues({});
    return SharedPreferences.getInstance();
  }

  Map<String, dynamic> circle({bool prayed = false}) => {
    'code': 'K7P3MX',
    'name': 'Family',
    'owner': true,
    'members': [
      {'id': 1, 'name': 'Ravi', 'owner': true, 'me': true},
      {'id': 2, 'name': 'Mary', 'owner': false, 'me': false},
    ],
    'requests': [
      {
        'id': 10,
        'memberId': 2,
        'name': 'Mary',
        'text': 'Please pray for my mother. She is in hospital.',
        'at': '2026-10-06T09:00:00Z',
        'answered': false,
        'prayed': prayed ? 1 : 0,
        'prayedByMe': prayed,
        'mine': false,
      },
    ],
  };

  CircleService service(SharedPreferences p, MockClientHandler handler) =>
      CircleService(p, baseUrl: 'https://api.example', installId: () => 'install-1234567890', client: MockClient(handler));

  test('codes are shown in two halves', () {
    expect(CircleService.showCode('K7P3MX'), 'K7P-3MX');
  });

  test('joins with the install id, and reads the circle', () async {
    final p = await prefs();
    final circles = service(p, (r) async {
      expect(r.method, 'POST');
      expect(r.url.path, '/v1/circles/join');
      expect(r.headers['X-Install-Id'], 'install-1234567890');
      expect(jsonDecode(r.body), {'code': 'k7p-3mx', 'memberName': 'Ravi'});
      return http.Response(jsonEncode(circle()), 200);
    });
    final c = await circles.join('k7p-3mx', 'Ravi');
    expect(c.name, 'Family');
    expect(c.members.where((m) => m.me).single.name, 'Ravi');
    expect(c.requests.single.text, startsWith('Please pray'));
  });

  test('says why it could not join', () async {
    final p = await prefs();
    Future<CircleProblem> problem(int status) async {
      try {
        await service(p, (_) async => http.Response('', status)).join('ZZZZZZ', 'Ravi');
      } on CircleException catch (e) {
        return e.problem;
      }
      fail('joined');
    }

    expect(await problem(404), CircleProblem.notFound);
    expect(await problem(409), CircleProblem.full);
    expect(await problem(422), CircleProblem.tooMany);
    expect(await problem(403), CircleProblem.notAllowed);
    expect(await problem(500), CircleProblem.offline);
    expect(
      () => service(p, (_) async => throw 'offline').open('K7P3MX'),
      throwsA(isA<CircleException>().having((e) => e.problem, 'problem', CircleProblem.offline)),
    );
  });

  test('remembers the circles for offline, and what is new in them', () async {
    final p = await prefs();
    final circles = service(p, (_) async => http.Response(jsonEncode([
      {'code': 'K7P3MX', 'name': 'Family', 'members': 2, 'owner': true, 'latest': '2026-10-06T09:00:00Z'},
    ]), 200));
    await circles.mine();
    final saved = service(p, (_) async => throw 'offline').saved;
    expect(saved.single.name, 'Family');
    expect(circles.hasNew(saved.single), isTrue);

    await circles.markSeen(CircleDetail.fromJson(circle()));
    expect(circles.hasNew(saved.single), isFalse);
  });

  testWidgets('shows the code and requests, and "I prayed" tells the others', (tester) async {
    final p = await tester.runAsync(prefs);
    final sent = <String>[];
    final circles = service(p!, (r) async {
      sent.add('${r.method} ${r.url.path}');
      return http.Response(jsonEncode(circle(prayed: r.url.path.endsWith('/prayed'))), 200);
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [prefsProvider.overrideWithValue(p), circleServiceProvider.overrideWithValue(circles)],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CircleScreen(code: 'K7P3MX'),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('K7P-3MX'), findsOneWidget);
    expect(find.text('Please pray for my mother. She is in hospital.'), findsOneWidget);
    expect(find.text('1 prayed'), findsNothing);

    await tester.tap(find.text('I prayed'));
    await tester.pumpAndSettle();
    expect(sent, ['GET /v1/circles/K7P3MX', 'POST /v1/circles/K7P3MX/requests/10/prayed']);
    expect(find.text('1 prayed'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });
}
