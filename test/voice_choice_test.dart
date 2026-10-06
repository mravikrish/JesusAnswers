import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jesus_answers/core/widgets/playback_controls.dart';
import 'package:jesus_answers/l10n/app_localizations.dart';
import 'package:jesus_answers/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('the Bible and stories remember their own man or woman voice, apart from prayers', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(ProviderScope(
      overrides: [prefsProvider.overrideWithValue(prefs)],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: Column(children: [VoiceToggle.reading(), VoiceToggle.prayers()])),
      ),
    ));

    // A woman's voice until chosen otherwise.
    final reading = find.byType(VoiceToggle).first;
    await tester.tap(find.descendant(of: reading, matching: find.text('Male voice')).hitTestable().first);
    await tester.pumpAndSettle();

    expect(prefs.getBool('readingMale'), isTrue);
    expect(prefs.getBool('prayerMale'), isNull);
  });
}
