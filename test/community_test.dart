import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jesus_answers/core/widgets/community.dart';
import 'package:jesus_answers/l10n/app_localizations.dart';
import 'package:jesus_answers/providers.dart';
import 'package:jesus_answers/services/community_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<SharedPreferences> prefs([Map<String, Object> values = const {}]) async {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  const counts = {
    'today': 3200,
    'items': {
      'prayer:hopeless': {'hearts': 1240, 'prayed': 860, 'listened': 0, 'week': 300},
      'prayer:journey': {'hearts': 3, 'prayed': 40, 'listened': 0, 'week': 45},
      'prayer:exam': {'hearts': 0, 'prayed': 9, 'listened': 0, 'week': 9},
      'story:creation': {'hearts': 20, 'prayed': 0, 'listened': 500, 'week': 120},
    },
  };

  test('items are named the same way the server expects', () {
    expect(CommunityService.prayer('hopeless'), 'prayer:hopeless');
    expect(CommunityService.story('creation'), 'story:creation');
    expect(CommunityService.chapter('JHN', 3), 'chapter:JHN.3');
    expect(CommunityService.saying('MAT 11:28'), 'saying:MAT.11.28');
  });

  test('hearts work and are remembered with no server', () async {
    final p = await prefs();
    final community = CommunityService(p);
    await community.toggleHeart('prayer:hopeless');
    expect(community.loved('prayer:hopeless'), isTrue);
    expect(CommunityService(p).loved('prayer:hopeless'), isTrue);
    await community.toggleHeart('prayer:hopeless');
    expect(CommunityService(p).loved('prayer:hopeless'), isFalse);
  });

  test('counts come from the server, at most hourly, and are kept for offline', () async {
    final p = await prefs();
    var fetches = 0;
    final community = CommunityService(p, baseUrl: 'https://api.example', client: MockClient((r) async {
      expect(r.url.path, '/v1/counts');
      fetches++;
      return http.Response(jsonEncode(counts), 200);
    }));
    await community.refresh();
    await community.refresh();
    expect(fetches, 1);
    expect(community.today, 3200);
    expect(community.counts('prayer:hopeless').hearts, 1240);

    // Most loved this week, most first; too few to mean anything is left out.
    expect(community.popular('prayer:'), ['hopeless', 'journey']);
    expect(community.popular('story:'), ['creation']);

    // Offline next time: the last counts are still there.
    final offline = CommunityService(p, baseUrl: 'https://api.example', client: MockClient((_) async => throw 'offline'));
    await offline.refresh(force: true);
    expect(offline.counts('story:creation').listened, 500);
  });

  test('what could not be sent waits and goes with the next send, once', () async {
    final p = await prefs();
    var online = false;
    final sent = <String>[];
    final community = CommunityService(p, baseUrl: 'https://api.example', client: MockClient((r) async {
      if (!online) throw 'offline';
      expect(r.headers['X-Install-Id'], hasLength(36));
      final body = jsonDecode(r.body);
      sent.add('${body['item']} ${body['kind']}');
      return http.Response('', 204);
    }));
    await community.prayed('prayer:hopeless');
    await community.toggleHeart('prayer:hopeless');
    expect(sent, isEmpty);

    online = true;
    await community.listened('story:creation');
    expect(sent, ['prayer:hopeless PRAYED', 'prayer:hopeless HEART', 'story:creation LISTENED']);
    await community.listened('story:creation');
    expect(sent, hasLength(4));
  });

  testWidgets('shows real counts once there are enough, and a heart to tap', (tester) async {
    final p = await tester.runAsync(() => prefs({'communityCounts': jsonEncode(counts)}));
    await tester.pumpWidget(ProviderScope(
      overrides: [prefsProvider.overrideWithValue(p!)],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Column(children: [
            CommunityBar(item: 'prayer:hopeless'),
            CommunityBar(item: 'prayer:exam'),
            PrayedTodayLine(),
          ]),
        ),
      ),
    ));
    expect(find.text('1.24K loved · 860 prayed'), findsOneWidget);
    expect(find.textContaining('9 prayed'), findsNothing);
    expect(find.text('Today 3.2K people prayed with you'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.favorite_border_rounded).first);
    await tester.pump();
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
  });
}
