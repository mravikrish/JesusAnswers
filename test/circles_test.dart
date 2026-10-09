import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jesus_answers/features/circles/circle_show_screen.dart';
import 'package:jesus_answers/features/circles/circles_screen.dart';
import 'package:jesus_answers/l10n/app_localizations.dart';
import 'package:jesus_answers/providers.dart';
import 'package:jesus_answers/services/circle_service.dart';
import 'package:jesus_answers/services/community_service.dart';
import 'package:qr_flutter/qr_flutter.dart';
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

  Widget app(SharedPreferences p, CircleService circles, Widget home) => ProviderScope(
    overrides: [prefsProvider.overrideWithValue(p), circleServiceProvider.overrideWithValue(circles)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );

  /// The install id of the person's old phone.
  const oldKey = '3f2a9c1e-7b4d-4e8a-9f00-1234567890ab';

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

  test('shares a ready prayer with a note, and hearts it', () async {
    final p = await prefs();
    final sent = <String>[];
    final shared = {
      ...circle(),
      'requests': [
        {
          'id': 11,
          'memberId': 1,
          'name': 'Ravi',
          'text': 'Tonight at 9',
          'at': '2026-10-06T09:00:00Z',
          'prayerId': 'psalm23',
          'hearts': 2,
          'heartedByMe': true,
          'mine': true,
        },
      ],
    };
    final circles = service(p, (r) async {
      sent.add('${r.method} ${r.url.path} ${r.body}');
      return http.Response(jsonEncode(shared), 200);
    });
    final c = await circles.sharePrayer('K7P3MX', 'psalm23', 'Tonight at 9');
    await circles.heart('K7P3MX', 11, on: false);
    expect(sent, [
      'POST /v1/circles/K7P3MX/requests {"prayerId":"psalm23","text":"Tonight at 9"}',
      'DELETE /v1/circles/K7P3MX/requests/11/heart ',
    ]);
    final r = c.requests.single;
    expect((r.prayerId, r.hearts, r.heartedByMe), ('psalm23', 2, true));
  });

  test('leaders pin a prayer focus, and the owner makes leaders', () async {
    final p = await prefs();
    final sent = <String>[];
    final circles = service(p, (r) async {
      sent.add('${r.method} ${r.url.path}');
      return http.Response(jsonEncode({...circle(), 'leader': true}), 200);
    });
    final c = await circles.pin('K7P3MX', 10, on: true);
    await circles.pin('K7P3MX', 10, on: false);
    await circles.setLeader('K7P3MX', 2, on: true);
    await circles.setLeader('K7P3MX', 2, on: false);
    expect(sent, [
      'POST /v1/circles/K7P3MX/requests/10/pin',
      'DELETE /v1/circles/K7P3MX/requests/10/pin',
      'POST /v1/circles/K7P3MX/members/2/leader',
      'DELETE /v1/circles/K7P3MX/members/2/leader',
    ]);
    expect(c.leader, isTrue);
  });

  test('a request can go only to the leaders, or without a name', () async {
    final p = await prefs();
    final bodies = <Object?>[];
    final circles = service(p, (r) async {
      bodies.add(jsonDecode(r.body));
      return http.Response(jsonEncode(circle()), 200);
    });
    await circles.ask('K7P3MX', 'My marriage is struggling', forLeaders: true, anonymous: true);
    await circles.ask('K7P3MX', 'Pray for my exam');
    expect(bodies, [
      {'text': 'My marriage is struggling', 'forLeaders': true, 'anonymous': true},
      {'text': 'Pray for my exam'},
    ]);
  });

  test("an invite is the server's web page for it, so phones without the app find it too", () {
    expect(CircleService.joinLink('K7P3MX', baseUrl: 'https://api.example'), 'https://api.example/join/K7P3MX');
    expect(CircleService.joinLink('K7P3MX'), 'jesusanswers://app/join/K7P3MX'); // no server
    expect(CircleService.codeIn(' k7p-3mx '), 'K7P3MX');
    expect([for (final t in ['Pray for me', 'K7P3M', 'K7P3MO', null]) CircleService.codeIn(t)], [null, null, null, null]);
  });

  test('a key from the old phone is its install id, as typed or pasted', () {
    expect(CommunityService.keyIn(' 3F2A9C1E-7B4D-4E8A-9F00-1234567890AB '), '3f2a9c1e-7b4d-4e8a-9f00-1234567890ab');
    expect(CommunityService.keyIn('K7P-3MX'), isNull);
  });

  testWidgets("Join fills in a code copied from an invite's web page", (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      return call.method == 'Clipboard.getData' ? {'text': 'K7P-3MX'} : null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final p = await tester.runAsync(prefs);
    final circles = service(p!, (_) async => http.Response('[]', 200));
    await tester.pumpWidget(app(p, circles, const CirclesScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Join with a code'));
    await tester.pumpAndSettle();
    expect(tester.widgetList<TextField>(find.byType(TextField)).first.controller!.text, 'K7P-3MX');
  });

  testWidgets("a new phone takes on the old phone's key, and with it the circles", (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final p = await tester.runAsync(prefs);
    final ids = <String?>[];
    final community = CommunityService(p!, baseUrl: '');
    final circles = CircleService(
      p,
      baseUrl: 'https://api.example',
      installId: () => community.installId,
      client: MockClient((r) async {
        ids.add(r.headers['X-Install-Id']);
        return http.Response(jsonEncode([if (r.headers['X-Install-Id'] == oldKey) {'code': 'K7P3MX', 'name': 'Grace Church', 'members': 120, 'church': true}]), 200);
      }),
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(p),
        communityProvider.overrideWithValue(community),
        circleServiceProvider.overrideWithValue(circles),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CirclesScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Grace Church'), findsNothing);
    final mine = community.installId;

    await tester.scrollUntilVisible(find.text('Move to a new phone'), 200);
    await tester.tap(find.text('Move to a new phone'));
    await tester.pumpAndSettle();
    expect(find.text(mine), findsOneWidget); // this phone's key, to take to a new one
    await tester.tap(find.text('I have a key from my old phone'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'not a key');
    await tester.pump();
    await tester.tap(find.text('Use this key'));
    await tester.pumpAndSettle();
    expect(find.text("That isn't a key from this app."), findsOneWidget);
    await tester.enterText(find.byType(TextField), oldKey.toUpperCase());
    await tester.pump();
    await tester.tap(find.text('Use this key'));
    await tester.pumpAndSettle();

    expect(community.installId, oldKey);
    expect(ids.last, oldKey);
    await tester.scrollUntilVisible(find.text('Grace Church'), -200);
    expect(find.text('Grace Church'), findsOneWidget);
  });

  test('news starts from the server time, then asks for what came after', () async {
    final p = await prefs();
    await p.setString('circles', jsonEncode([{'code': 'K7P3MX', 'name': 'Family', 'members': 2}]));
    final asked = <String>[];
    final circles = service(p, (r) async {
      asked.add(r.url.query);
      return http.Response(
        jsonEncode({
          'now': '2026-10-07T10:00:00Z',
          'items': asked.length == 1
              ? []
              : [
                  {'kind': 'request', 'circle': 'K7P3MX', 'circleName': 'Family', 'requestId': 10, 'name': 'Mary', 'text': 'Pray for my exam'},
                  {'kind': 'prayed', 'circle': 'K7P3MX', 'circleName': 'Family', 'requestId': 11, 'count': 3},
                  {'kind': 'something-new', 'circle': 'K7P3MX', 'circleName': 'Family'},
                  {'kind': 'request', 'circle': 'K7P3MX', 'circleName': 'Family', 'requestId': 12, 'name': 'Anil', 'text': 'I cannot go on', 'crisis': true},
                ],
        }),
        200,
      );
    });
    expect(await circles.news(), isEmpty);
    final news = await circles.news();
    expect(asked, ['', 'since=2026-10-07T10%3A00%3A00Z']);
    expect([for (final n in news) (n.kind, n.name, n.count, n.crisis)], [
      (CircleNewsKind.request, 'Mary', 0, false),
      (CircleNewsKind.prayed, '', 3, false),
      (CircleNewsKind.request, 'Anil', 0, true),
    ]);
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

  testWidgets("the pastor's pinned prayer focus comes first, marked Leader", (tester) async {
    final p = await tester.runAsync(prefs);
    final church = {
      'code': 'K7P3MX',
      'name': 'Grace Church',
      'owner': false,
      'leader': false,
      'members': [
        {'id': 1, 'name': 'Pastor John', 'owner': true},
        {'id': 2, 'name': 'Mary', 'me': true},
      ],
      'requests': [
        {
          'id': 20,
          'name': 'Pastor John',
          'text': 'This week we pray for the Sharma family.',
          'at': '2026-10-05T09:00:00Z',
          'leader': true,
          'pinned': true,
        },
        {'id': 21, 'name': 'Mary', 'text': 'Pray for my exam', 'at': '2026-10-06T09:00:00Z', 'mine': true},
      ],
    };
    final circles = service(p!, (_) async => http.Response(jsonEncode(church), 200));
    await tester.pumpWidget(ProviderScope(
      overrides: [prefsProvider.overrideWithValue(p), circleServiceProvider.overrideWithValue(circles)],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CircleScreen(code: 'K7P3MX'),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('PRAYER FOCUS'), findsOneWidget);
    expect(find.text('Leader'), findsOneWidget);
    final focus = tester.getTopLeft(find.text('This week we pray for the Sharma family.'));
    expect(focus.dy, lessThan(tester.getTopLeft(find.text('Pray for my exam')).dy));

    // A member can report the pastor's post, but can't pin it or delete it.
    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pumpAndSettle();
    expect(find.text('Report'), findsOneWidget);
    expect(find.text('Pin as prayer focus'), findsNothing);
    expect(find.text('Delete'), findsNothing);
  });

  testWidgets('a request without a name hides who asked, and one can go only to the leaders', (tester) async {
    final p = await tester.runAsync(prefs);
    final sent = <Object?>[];
    final church = {
      'code': 'K7P3MX',
      'name': 'Grace Church',
      'members': [
        {'id': 1, 'name': 'Pastor John', 'owner': true},
        {'id': 2, 'name': 'Mary', 'me': true},
      ],
      'requests': [
        // Someone else's, without a name: the server sends no name.
        {'id': 30, 'name': '', 'text': 'Pray for my family', 'at': '2026-10-08T09:00:00Z', 'anonymous': true},
        // Mary's own, for the leaders only and without her name: she is told who can see it.
        {
          'id': 31,
          'name': 'Mary',
          'text': 'I lost my job',
          'at': '2026-10-07T09:00:00Z',
          'mine': true,
          'forLeaders': true,
          'anonymous': true,
        },
      ],
    };
    final circles = service(p!, (r) async {
      if (r.method == 'POST') sent.add(jsonDecode(r.body));
      return http.Response(jsonEncode(church), 200);
    });
    await tester.pumpWidget(app(p, circles, const CircleScreen(code: 'K7P3MX')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Someone in the circle'), findsOneWidget);
    expect(find.text('Only leaders can see this'), findsOneWidget);
    expect(find.text("Members don't see who asked"), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Please pray for my health');
    await tester.tap(find.text('Only leaders'));
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    expect(sent, [
      {'text': 'Please pray for my health', 'forLeaders': true},
    ]);
    // Back to everyone for the next one.
    expect(tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'Only leaders')).selected, isFalse);
  });

  testWidgets("the church's screen shows the code and a QR code to join", (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: CircleShowScreen(code: 'K7P3MX', name: 'Grace Church'),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Grace Church'), findsOneWidget);
    expect(find.text('K7P-3MX'), findsOneWidget);
    expect(tester.widget<QrImageView>(find.byType(QrImageView)), isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a QR code from church opens Join with the code filled in', (tester) async {
    final p = await tester.runAsync(prefs);
    final circles = service(p!, (_) async => http.Response('[]', 200));
    await tester.pumpWidget(app(p, circles, const CirclesScreen(joinCode: 'K7P3MX')));
    await tester.pumpAndSettle();
    final code = tester.widgetList<TextField>(find.byType(TextField)).first;
    expect(code.controller!.text, 'K7P-3MX');
  });
}
