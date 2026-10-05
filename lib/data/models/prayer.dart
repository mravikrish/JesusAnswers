import 'package:flutter/material.dart';

import 'painting.dart';

/// A ready prayer to read or hear. One with a [passage] is prayed in
/// Scripture's own words; every other one has its words in [text].
class Prayer {
  const Prayer({
    required this.id,
    required this.group,
    required this.icon,
    required this.title,
    this.text,
    this.passage,
    this.forText,
    this.forTitle,
    this.picture,
    this.crisis = false,
  });

  final String id;

  /// The group it is listed under, e.g. daily, needs or beginnings (assets/prayers/prayers.json).
  final String group;
  final IconData icon;
  final String title;
  final String? text;

  /// Language-neutral passage ref, e.g. "PSA 23:1-6".
  final String? passage;

  /// The same prayer prayed for someone else, with `{name}` where their name goes.
  final String? forText;

  /// The title when prayed for someone else, if it has to change.
  final String? forTitle;

  /// The painting of Jesus shown behind it.
  final Painting? picture;

  /// Someone reading it may be at risk: the helplines are shown above it.
  final bool crisis;

  bool get canPrayForSomeone => forText != null;

  /// [forText] for [name], or [text] when [name] is null.
  String? words({String? name}) => name == null ? text : forText?.replaceAll('{name}', name.trim());
}

/// A group of ready prayers, e.g. "Every Day".
class PrayerGroup {
  const PrayerGroup({required this.id, required this.title, required this.prayers});
  final String id;
  final String title;
  final List<Prayer> prayers;
}

/// A Scripture prayer in one language: where it is from, and its verses as one text.
class PrayerPassage {
  const PrayerPassage({required this.reference, required this.text});
  final String reference;
  final String text;
}

const prayerIcons = {
  'hands': Icons.front_hand_rounded,
  'sheep': Icons.grass_rounded,
  'shield': Icons.shield_rounded,
  'mountain': Icons.landscape_rounded,
  'light': Icons.flare_rounded,
  'praise': Icons.music_note_rounded,
  'heart': Icons.favorite_rounded,
  'search': Icons.search_rounded,
  'sunrise': Icons.wb_sunny_rounded,
  'star': Icons.star_rounded,
  'love': Icons.favorite_border_rounded,
  'people': Icons.groups_rounded,
  'moon': Icons.nightlight_round,
  'meal': Icons.restaurant_rounded,
  'work': Icons.work_rounded,
  'thanks': Icons.volunteer_activism_rounded,
  'healing': Icons.healing_rounded,
  'peace': Icons.spa_rounded,
  'strength': Icons.fitness_center_rounded,
  'road': Icons.route_rounded,
  'tear': Icons.water_drop_rounded,
  'hug': Icons.emoji_people_rounded,
  'basket': Icons.shopping_basket_rounded,
  'family': Icons.family_restroom_rounded,
  'child': Icons.child_care_rounded,
  'rings': Icons.diversity_1_rounded,
  'flag': Icons.flag_rounded,
  'cross': Icons.add_rounded,
  'surrender': Icons.waving_hand_rounded,
  'cake': Icons.cake_rounded,
  'home': Icons.home_rounded,
  'trophy': Icons.emoji_events_rounded,
  'calendar': Icons.event_rounded,
  'travel': Icons.flight_takeoff_rounded,
  'store': Icons.storefront_rounded,
  'handshake': Icons.handshake_rounded,
  'school': Icons.school_rounded,
  'exam': Icons.edit_note_rounded,
  'car': Icons.directions_car_rounded,
  'hospital': Icons.local_hospital_rounded,
  'bed': Icons.hotel_rounded,
  'pregnant': Icons.pregnant_woman_rounded,
  'chain': Icons.link_off_rounded,
  'warning': Icons.warning_amber_rounded,
  'work_off': Icons.work_off_rounded,
  'money': Icons.account_balance_wallet_rounded,
  'gavel': Icons.gavel_rounded,
  'storm': Icons.thunderstorm_rounded,
};
