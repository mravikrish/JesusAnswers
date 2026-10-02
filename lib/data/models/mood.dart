import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Entry points on the "What are you feeling?" grid, each mapped to Scripture themes.
enum Mood {
  worried('😟', ['anxiety', 'stress', 'peace']),
  sad('😔', ['sad', 'hope', 'grief']),
  afraid('😨', ['fear', 'strength']),
  angry('😠', ['anger', 'forgiveness', 'patience']),
  hurt('💔', ['hurt', 'healing', 'forgiveness']),
  lonely('🫂', ['loneliness']),
  lost('🧭', ['lost', 'decision', 'purpose']),
  tired('😴', ['tired', 'strength', 'peace']),
  needStrength('💪', ['strength']),
  needHope('💙', ['hope', 'future']),
  grateful('😊', ['gratitude']),
  cantSleep('🌙', ['sleep', 'peace']);

  const Mood(this.emoji, this.themes);

  final String emoji;
  final List<String> themes;

  String label(AppLocalizations l) => switch (this) {
        worried => l.moodWorried,
        sad => l.moodSad,
        afraid => l.moodAfraid,
        angry => l.moodAngry,
        hurt => l.moodHurt,
        lonely => l.moodLonely,
        lost => l.moodLost,
        tired => l.moodTired,
        needStrength => l.moodNeedStrength,
        needHope => l.moodNeedHope,
        grateful => l.moodGrateful,
        cantSleep => l.moodCantSleep,
      };

  Color get tint => switch (this) {
        worried || afraid || tired || cantSleep => const Color(0xFF8E9BE0),
        sad || lonely || needHope => const Color(0xFF6FA8DC),
        angry || hurt => const Color(0xFFE07A7A),
        lost => const Color(0xFF9AB89A),
        needStrength || grateful => const Color(0xFFE5B456),
      };

  static Mood? byName(String? name) =>
      name == null ? null : Mood.values.where((m) => m.name == name).firstOrNull;
}
