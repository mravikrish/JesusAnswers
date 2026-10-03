import 'package:flutter/material.dart';

/// A Bible story, told only in Scripture's own words: a title and the
/// passages that tell it. Verse text comes from the bundled translations.
class Story {
  const Story({
    required this.id,
    required this.oldTestament,
    required this.icon,
    required this.titles,
    required this.passages,
  });

  final String id;
  final bool oldTestament;
  final IconData icon;

  /// Title by language code; English when a language has none.
  final Map<String, String> titles;

  /// Language-neutral passage refs, e.g. "LUK 15:11-32".
  final List<String> passages;

  String title(String lang) => titles[lang] ?? titles['en'] ?? id;

  factory Story.fromJson(Map<String, dynamic> j) => Story(
        id: j['id'] as String,
        oldTestament: j['testament'] == 'old',
        icon: _icons[j['icon']] ?? Icons.menu_book_rounded,
        titles: (j['title'] as Map).cast<String, String>(),
        passages: (j['passages'] as List).cast<String>(),
      );

  static const _icons = {
    'creation': Icons.public_rounded,
    'ark': Icons.sailing_rounded,
    'family': Icons.diversity_3_rounded,
    'sea': Icons.waves_rounded,
    'loyalty': Icons.favorite_rounded,
    'courage': Icons.shield_rounded,
    'lions': Icons.pets_rounded,
    'fish': Icons.set_meal_rounded,
    'star': Icons.star_rounded,
    'storm': Icons.thunderstorm_rounded,
    'bread': Icons.bakery_dining_rounded,
    'water': Icons.water_rounded,
    'kindness': Icons.volunteer_activism_rounded,
    'sheep': Icons.grass_rounded,
    'home': Icons.home_rounded,
    'tree': Icons.park_rounded,
    'sight': Icons.visibility_rounded,
    'life': Icons.wb_twilight_rounded,
    'sunrise': Icons.wb_sunny_rounded,
  };
}

/// One passage of a story in a given language, verse by verse.
class StoryPassage {
  const StoryPassage({required this.reference, required this.verses});

  /// Localized display reference, e.g. "లూకా 15:11-32".
  final String reference;

  /// (verse number, text). A verse a translation bridges into the one
  /// before it is simply absent.
  final List<(int, String)> verses;
}
