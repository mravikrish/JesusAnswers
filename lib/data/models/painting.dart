import 'dart:convert';

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

/// A public-domain painting of Jesus, shown as the day's picture on Home.
/// Bundled under assets/jesus/ by tool/fetch_paintings.py; see paintings.json for sources.
class Painting {
  const Painting({
    required this.asset,
    required this.title,
    required this.artist,
    this.year,
    this.focus = Alignment.center,
  });

  final String asset;
  final String title;
  final String artist;
  final String? year;

  /// Where to keep in frame when cover-cropping — His face. (-1,-1) is top-left.
  final Alignment focus;

  String get credit => [artist, ?year].join(', ');

  factory Painting.fromJson(Map<String, dynamic> j) => Painting(
        asset: 'assets/jesus/${j['file']}',
        title: j['title'] as String,
        artist: j['artist'] as String,
        year: j['year'] as String?,
        focus: Alignment((j['focusX'] as num? ?? 0).toDouble(), (j['focusY'] as num? ?? -0.4).toDouble()),
      );

  static List<Painting>? _all;

  static Future<List<Painting>> all([AssetBundle? bundle]) async =>
      _all ??= [
        for (final p in jsonDecode(await (bundle ?? rootBundle).loadString('assets/jesus/paintings.json'))['paintings']
            as List)
          Painting.fromJson(p as Map<String, dynamic>),
      ];

  /// A different painting each day, cycling through the whole collection.
  static Future<Painting> forDay(DateTime day, [AssetBundle? bundle]) async {
    final list = await all(bundle);
    final dayNumber = DateTime.utc(day.year, day.month, day.day).difference(DateTime.utc(2024)).inDays;
    return list[dayNumber % list.length];
  }
}
