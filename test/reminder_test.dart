import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jesus_answers/core/languages.dart';
import 'package:jesus_answers/l10n/app_localizations.dart';

void main() {
  test('every language has a title and seven different daily reminders', () {
    for (final lang in appLanguages) {
      final l = lookupAppLocalizations(Locale(lang.code));
      final words = [l.reminder1, l.reminder2, l.reminder3, l.reminder4, l.reminder5, l.reminder6, l.reminder7];
      expect(l.reminderTitle, isNotEmpty, reason: lang.code);
      expect(words.toSet(), hasLength(7), reason: lang.code);
      expect(words.every((w) => w.trim().isNotEmpty), isTrue, reason: lang.code);
    }
  });
}
