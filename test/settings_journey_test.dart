import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jesus_answers/data/models/answer.dart';
import 'package:jesus_answers/data/models/topic.dart';
import 'package:jesus_answers/services/answer/theme_classifier.dart';
import 'package:jesus_answers/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

Answer _entry(String id, int day) => Answer(
      id: id,
      kind: AnswerKind.question,
      question: 'q$id',
      lang: 'en',
      verses: const [],
      encouragement: 'e',
      prayer: 'p',
      createdAt: DateTime(2026, 10, day),
    );

Future<ProviderContainer> _container() async {
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('removing a journey entry and undoing puts it back in date order', () async {
    final c = await _container();
    final journey = c.read(journeyProvider.notifier);
    for (final (id, day) in [('a', 1), ('b', 2), ('c', 3)]) {
      journey.add(_entry(id, day));
    }
    final b = journey.byId('b')!;
    journey.remove('b');
    expect(c.read(journeyProvider).map((a) => a.id), ['c', 'a']);
    journey.restore(b);
    expect(c.read(journeyProvider).map((a) => a.id), ['c', 'b', 'a']);
  });

  test('welcome pages show once for new people, never for existing ones', () async {
    var c = await _container();
    expect(c.read(settingsProvider).onboarded, isFalse);
    await c.read(settingsProvider.notifier).finishOnboarding();
    c = await _container();
    expect(c.read(settingsProvider).onboarded, isTrue);

    // Chose a language before the welcome pages existed.
    SharedPreferences.setMockInitialValues({'lang': 'ta'});
    c = await _container();
    expect(c.read(settingsProvider).onboarded, isTrue);
  });

  test('text size and reminder are saved and can be turned off', () async {
    final c = await _container();
    final settings = c.read(settingsProvider.notifier);
    await settings.setTextScale(1.3);
    await settings.setReminder(7 * 60 + 30);
    expect(c.read(settingsProvider).textScale, 1.3);
    expect(c.read(settingsProvider).reminder, 450);

    final reopened = await _container(); // same prefs, fresh app
    expect(reopened.read(settingsProvider).reminder, 450);
    expect(reopened.read(settingsProvider).textScale, 1.3);

    await settings.setReminder(null);
    expect(c.read(settingsProvider).reminder, isNull);
  });

  test('every Scripture theme belongs to a Journey topic', () {
    final index = jsonDecode(File('tool/bible/themes.json').readAsStringSync()) as Map<String, dynamic>;
    final themes = {
      for (final v in index['verses'] as List) ...(v['themes'] as List).cast<String>(),
      ...ThemeClassifier.fallback,
    }..remove('crisis'); // crisis answers lead with helplines, not a topic
    final grouped = {for (final t in Topic.values) ...t.themes};
    expect(themes.difference(grouped), isEmpty);
  });
}
