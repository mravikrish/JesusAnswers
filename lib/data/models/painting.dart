import 'dart:convert';

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

/// A picture of Jesus: the day's picture on Home, and one page of the Pictures gallery.
/// Bundled under assets/jesus/; see paintings.json.
class Painting {
  const Painting({
    required this.asset,
    required this.title,
    this.artist,
    this.year,
    this.focus = Alignment.center,
  });

  final String asset;
  final String title;
  final String? artist;
  final String? year;

  /// Where to keep in frame when cover-cropping — His face. (-1,-1) is top-left.
  final Alignment focus;

  /// "Artist, year" — null when the picture needs no credit line.
  String? get credit => artist == null ? null : [artist, ?year].join(', ');

  factory Painting.fromJson(Map<String, dynamic> j) => Painting(
        asset: 'assets/jesus/${j['file']}',
        title: j['title'] as String,
        artist: j['artist'] as String?,
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
    return list[indexForDay(day, list.length)];
  }

  /// Position of [day]'s picture in [all].
  static int indexForDay(DateTime day, int count) =>
      DateTime.utc(day.year, day.month, day.day).difference(DateTime.utc(2024)).inDays % count;
}
