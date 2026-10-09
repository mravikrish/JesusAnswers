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
import 'package:jesus_answers/services/reminder_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers the reminders asked for, instead of the phone's notifications.
class _Reminders extends ReminderService {
  final set = <String, DateTime>{};

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> once(String key, DateTime at, {required String title, required String body}) async => set[key] = at;

  @override
  Future<void> cancelOnce(String key) async => set.remove(key);
}

void main() {
  Future<SharedPreferences> prefs() async {
    SharedPreferences.setMockInitialValues({});
    return SharedPreferences.getInstance();
  }

  CircleService service(SharedPreferences p, MockClientHandler handler) =>
      CircleService(p, baseUrl: 'https://api.example', installId: () => 'install-1234567890', client: MockClient(handler));

  final tomorrow = DateTime.now().add(const Duration(days: 1));
  final at = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 21).toUtc();

  /// Grace Church as its pastor sees it.
  Map<String, dynamic> church({List<Map<String, dynamic>> turns = const []}) => {
    'code': 'K7P3MX',
    'name': 'Grace Church',
    'owner': true,
    'leader': true,
    'approval': true,
    'members': [
      {'id': 1, 'name': 'Pastor John', 'owner': true, 'me': true},
      {'id': 2, 'name': 'Mary'},
    ],
    'waiting': [
      {'id': 9, 'name': 'Ravi'},
    ],
    'requests': [
      {
        'id': 20,
        'name': 'Pastor John',
        'text': "Sunday's sermon",
        'at': '2026-10-05T09:00:00Z',
        'mine': true,
        'leader': true,
        'verse': 'JHN 3:16',
      },
    ],
    'praise': [
      {
        'id': 21,
        'name': 'Mary',
        'text': 'Pray for my job interview',
        'at': '2026-10-01T09:00:00Z',
        'answered': true,
        'answeredAt': '2026-10-06T09:00:00Z',
        'testimony': 'I got the job!',
        'hearts': 3,
      },
      {
        'id': 22,
        'name': 'Anil',
        'text': 'God healed my mother',
        'at': '2026-10-04T09:00:00Z',
        'answered': true,
        'praise': true,
        'answeredAt': '2026-10-04T09:00:00Z',
      },
    ],
    'church': true,
    'groups': [
      {'code': 'YTH234', 'name': 'Youth', 'members': 12, 'joined': false},
      {'code': 'HME567', 'name': 'Home group', 'members': 8, 'joined': true},
    ],
    'chains': [
      {
        'id': 5,
        'title': '24 hours for revival',
        'startsAt': at.toIso8601String(),
        'slotMinutes': 60,
        'slots': 3,
        'mine': true,
        'turns': turns,
      },
    ],
  };

  Widget app(SharedPreferences p, CircleService circles, Widget home, {ReminderService? reminders}) => ProviderScope(
    overrides: [
      prefsProvider.overrideWithValue(p),
      circleServiceProvider.overrideWithValue(circles),
      if (reminders != null) reminderServiceProvider.overrideWithValue(reminders),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );

  test('the church calls: praise, verses, testimonies, approval, groups and chains', () async {
    final p = await prefs();
    final sent = <String>[];
    final circles = service(p, (r) async {
      sent.add('${r.method} ${r.url.path} ${r.body}');
      return http.Response(jsonEncode(church()), 200);
    });
    await circles.praise('K7P3MX', 'God healed my mother');
    await circles.shareVerse('K7P3MX', 'JHN 3:16', "Sunday's sermon");
    await circles.answered('K7P3MX', 21, testimony: ' I got the job! ');
    await circles.answered('K7P3MX', 21);
    await circles.setApproval('K7P3MX', on: true);
    await circles.approve('K7P3MX', 9);
    await circles.decline('K7P3MX', 9);
    await circles.createGroup('K7P3MX', 'Youth');
    await circles.createChain('K7P3MX', title: 'Fast', startsAt: at, slotMinutes: 1440, slots: 3);
    await circles.turn('K7P3MX', 5, 1, on: true);
    final c = await circles.turn('K7P3MX', 5, 1, on: false);
    expect(sent, [
      'POST /v1/circles/K7P3MX/requests {"text":"God healed my mother","praise":true}',
      'POST /v1/circles/K7P3MX/requests {"verse":"JHN 3:16","text":"Sunday\'s sermon"}',
      'POST /v1/circles/K7P3MX/requests/21/answered {"testimony":"I got the job!"}',
      'POST /v1/circles/K7P3MX/requests/21/answered ',
      'POST /v1/circles/K7P3MX/approval ',
      'POST /v1/circles/K7P3MX/waiting/9/approve ',
      'DELETE /v1/circles/K7P3MX/waiting/9 ',
      'POST /v1/circles/K7P3MX/groups {"name":"Youth"}',
      'POST /v1/circles/K7P3MX/chains {"title":"Fast","startsAt":"${at.toIso8601String()}","slotMinutes":1440,"slots":3}',
      'POST /v1/circles/K7P3MX/chains/5/turns/1 ',
      'DELETE /v1/circles/K7P3MX/chains/5/turns/1 ',
    ]);
    expect((c.approval, c.waiting.single.name, c.groups.length, c.praise.first.testimony), (true, 'Ravi', 2, 'I got the job!'));
    final chain = c.chains.single;
    expect((chain.fasting, chain.slotStart(2), chain.endsAt), (false, chain.startsAt.add(const Duration(hours: 2)), chain.startsAt.add(const Duration(hours: 3))));
  });

  test('a group knows its church, and someone waiting has nothing else to see', () {
    final group = CircleDetail.fromJson({
      'code': 'YTH234',
      'name': 'Youth',
      'parent': {'code': 'K7P3MX', 'name': 'Grace Church'},
    });
    expect((group.isGroup, group.parentCode, group.parentName), (true, 'K7P3MX', 'Grace Church'));
    final waiting = CircleDetail.fromJson({'code': 'K7P3MX', 'name': 'Grace Church', 'pending': true});
    expect((waiting.pending, waiting.requests.length, waiting.isGroup), (true, 0, false));
    final summary = CircleSummary.fromJson({'code': 'YTH234', 'name': 'Youth', 'members': 4, 'parent': 'Grace Church', 'pending': true});
    expect(CircleSummary.fromJson(summary.toJson()).parent, 'Grace Church');
  });

  testWidgets('the praise wall shows answered prayers with their testimony, and praise reports', (tester) async {
    final p = await tester.runAsync(prefs);
    final circles = service(p!, (_) async => http.Response(jsonEncode(church()), 200));
    await tester.pumpWidget(app(p, circles, const CircleScreen(code: 'K7P3MX')));
    await tester.pumpAndSettle();

    expect(find.text('Circles'), findsOneWidget);
    await tester.tap(find.text('Praise'));
    await tester.pumpAndSettle();
    expect(find.text('I got the job!'), findsOneWidget);
    expect(find.text('Pray for my job interview'), findsOneWidget);
    expect(find.text('Praise report'), findsOneWidget);
    expect(find.text('God healed my mother'), findsOneWidget);
  });

  testWidgets('taking a turn in a prayer chain sets a reminder for it; giving it back takes it away', (tester) async {
    final p = await tester.runAsync(prefs);
    final reminders = _Reminders();
    var turns = <Map<String, dynamic>>[];
    final circles = service(p!, (r) async {
      if (r.url.path.endsWith('/turns/1')) {
        turns = r.method == 'POST' ? [{'slot': 1, 'name': 'Pastor John', 'mine': true}] : [];
      }
      return http.Response(jsonEncode(church(turns: turns)), 200);
    });
    await tester.pumpWidget(app(p, circles, const CircleScreen(code: 'K7P3MX'), reminders: reminders));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chains'));
    await tester.pumpAndSettle();

    expect(find.text('24 hours for revival'), findsOneWidget);
    expect(find.text("I'll pray"), findsNWidgets(3));
    await tester.tap(find.text("I'll pray").at(1));
    await tester.pumpAndSettle();
    expect(reminders.set, {'chain:5:1': at.toLocal().add(const Duration(hours: 1))});
    expect(find.text('You'), findsOneWidget);

    await tester.tap(find.text('Give back'));
    await tester.pumpAndSettle();
    expect(reminders.set, isEmpty);
  });

  testWidgets('a circle of family and friends holds no circles of its own', (tester) async {
    final p = await tester.runAsync(prefs);
    final family = {...church(), 'name': 'Family', 'church': false, 'groups': <Object>[]};
    final circles = service(p!, (_) async => http.Response(jsonEncode(family), 200));
    await tester.pumpWidget(app(p, circles, const CircleScreen(code: 'K7P3MX')));
    await tester.pumpAndSettle();
    expect(find.text('Praise'), findsOneWidget);
    expect(find.text('Circles'), findsNothing);
  });

  testWidgets('Prayer Circles lists churches, each with its circles, apart from family and friends', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final p = await tester.runAsync(prefs);
    final circles = service(p!, (_) async => http.Response(jsonEncode([
      {'code': 'K7P3MX', 'name': 'Grace Church', 'members': 120, 'church': true},
      {'code': 'YTH234', 'name': 'Youth', 'members': 12, 'parent': 'Grace Church'},
      {'code': 'FAM789', 'name': 'Family', 'members': 4},
    ]), 200));
    await tester.pumpWidget(app(p, circles, const CirclesScreen()));
    await tester.pumpAndSettle();
    final churches = tester.getTopLeft(find.text('MY CHURCHES')).dy;
    final own = tester.getTopLeft(find.text('MY CIRCLES')).dy;
    double y(String name) => tester.getTopLeft(find.text(name)).dy;
    final top = [churches, y('Grace Church'), y('Youth'), own, y('Family')];
    expect(top, orderedEquals([...top]..sort()));
    // The church's circle sits under it.
    expect(tester.getTopLeft(find.text('Youth')).dx, greaterThan(tester.getTopLeft(find.text('Grace Church')).dx));
  });

  testWidgets('starting a church asks for its name, and a circle for family and friends stays as before', (tester) async {
    final p = await tester.runAsync(prefs);
    final sent = <String>[];
    final circles = service(p!, (r) async {
      sent.add('${r.method} ${r.url.path} ${r.body}');
      return http.Response(jsonEncode(r.method == 'GET' && r.url.path == '/v1/circles' ? [] : church()), 200);
    });
    await tester.pumpWidget(app(p, circles, const CirclesScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My church'));
    await tester.pumpAndSettle();
    expect(find.text('Set up your church'), findsWidgets);
    await tester.enterText(find.widgetWithText(TextField, 'Church name'), 'Grace Church');
    await tester.enterText(find.widgetWithText(TextField, 'Your name'), 'Pastor John');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Set up your church'));
    await tester.pumpAndSettle();
    expect(sent, contains('POST /v1/circles {"name":"Grace Church","memberName":"Pastor John","church":true}'));
  });

  testWidgets("a church's members join its groups with one tap", (tester) async {
    final p = await tester.runAsync(prefs);
    final sent = <String>[];
    final circles = service(p!, (r) async {
      sent.add('${r.method} ${r.url.path} ${r.body}');
      if (r.url.path.endsWith('/join')) {
        return http.Response(jsonEncode({'code': 'YTH234', 'name': 'Youth', 'pending': true}), 200);
      }
      return http.Response(jsonEncode(church()), 200);
    });
    await tester.pumpWidget(app(p, circles, const CircleScreen(code: 'K7P3MX')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Circles'));
    await tester.pumpAndSettle();

    expect(find.text('Home group'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Join'));
    await tester.pumpAndSettle();
    // Under the name they have in the church; this group lets people in once a leader approves.
    expect(sent, contains('POST /v1/circles/join {"code":"YTH234","memberName":"Pastor John"}'));
    expect(find.textContaining('A leader will let you in soon'), findsOneWidget);
  });

  testWidgets('the pastor lets in someone waiting, and can turn approval off', (tester) async {
    final p = await tester.runAsync(prefs);
    final sent = <String>[];
    final circles = service(p!, (r) async {
      sent.add('${r.method} ${r.url.path}');
      return http.Response(jsonEncode(church()), 200);
    });
    await tester.pumpWidget(app(p, circles, const CircleScreen(code: 'K7P3MX')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Waiting to join (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Ravi'), findsOneWidget);
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isTrue);
    await tester.tap(find.text('Let in'));
    await tester.pumpAndSettle();
    expect(sent.last, 'POST /v1/circles/K7P3MX/waiting/9/approve');
  });

  testWidgets('someone waiting to be let in sees so, and can stop waiting', (tester) async {
    final p = await tester.runAsync(prefs);
    final sent = <String>[];
    final circles = service(p!, (r) async {
      sent.add('${r.method} ${r.url.path}');
      return r.url.path.endsWith('/leave')
          ? http.Response('', 204)
          : http.Response(jsonEncode({'code': 'K7P3MX', 'name': 'Grace Church', 'pending': true}), 200);
    });
    await tester.pumpWidget(app(p, circles, const CircleScreen(code: 'K7P3MX')));
    await tester.pumpAndSettle();

    expect(find.textContaining('You asked to join Grace Church'), findsOneWidget);
    expect(find.text('Praise'), findsNothing);
    await tester.tap(find.text('Stop waiting'));
    await tester.pumpAndSettle();
    expect(sent.last, 'POST /v1/circles/K7P3MX/leave');
  });
}
