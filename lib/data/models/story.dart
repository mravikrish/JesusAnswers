import 'package:flutter/material.dart';

import 'verse.dart';

/// A Bible story, told only in Scripture's own words: a title and the
/// passages that tell it. Verse text comes from the bundled translations.
class Story {
  const Story({
    required this.id,
    required this.oldTestament,
    required this.icon,
    required this.image,
    required this.titles,
    required this.passages,
  });

  final String id;
  final bool oldTestament;
  final IconData icon;
  final StoryImage image;

  /// Title by language code; English when a language has none.
  final Map<String, String> titles;

  /// Language-neutral passage refs, e.g. "LUK 15:11-32".
  final List<String> passages;

  String title(String lang) => titles[lang] ?? titles['en'] ?? id;

  factory Story.fromJson(Map<String, dynamic> j) => Story(
        id: j['id'] as String,
        oldTestament: j['testament'] == 'old',
        icon: _icons[j['icon']] ?? Icons.menu_book_rounded,
        image: StoryImage.fromJson(j['id'] as String, j['image'] as Map<String, dynamic>),
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
    'ladder': Icons.stairs_rounded,
    'basket': Icons.shopping_basket_rounded,
    'fire': Icons.local_fire_department_rounded,
    'trumpet': Icons.campaign_rounded,
    'listen': Icons.hearing_rounded,
    'bird': Icons.flutter_dash_rounded,
    'crown': Icons.workspace_premium_rounded,
    'flame': Icons.whatshot_rounded,
    'wine': Icons.wine_bar_rounded,
    'seed': Icons.eco_rounded,
    'hand': Icons.back_hand_rounded,
    'rest': Icons.chair_rounded,
    'thanks': Icons.favorite_border_rounded,
    'child': Icons.child_care_rounded,
    'serve': Icons.wash_rounded,
    'road': Icons.route_rounded,
    'light': Icons.flare_rounded,
  };
}

/// The story's picture, built from art/stories/ into assets/stories/ by tool/build_story_images.py.
class StoryImage {
  const StoryImage({required this.asset, this.focus = Alignment.center});

  final String asset;

  /// What to keep in frame when cover-cropping. (-1,-1) is top-left.
  final Alignment focus;

  factory StoryImage.fromJson(String id, Map<String, dynamic> j) => StoryImage(
        asset: 'assets/stories/$id.jpg',
        focus: Alignment((j['focusX'] as num? ?? 0).toDouble(), (j['focusY'] as num? ?? 0).toDouble()),
      );
}

/// One passage of a story in a given language, verse by verse.
class StoryPassage {
  const StoryPassage({required this.reference, required this.verses});

  /// Localized display reference, e.g. "లూకా 15:11-32".
  final String reference;

  /// A verse a translation bridges into the one before it is simply absent.
  final List<NumberedVerse> verses;
}
