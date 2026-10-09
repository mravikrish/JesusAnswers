import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppColors {
  static const midnight = Color(0xFF0A1430);
  static const navy = Color(0xFF13234A);
  static const navyLight = Color(0xFF1F3366);
  static const dusk = Color(0xFF3B3557);
  static const ember = Color(0xFF9A6A45);
  static const ivory = Color(0xFFFBF6EC);
  static const ivoryCard = Color(0xFFFFFCF6);
  static const sand = Color(0xFFEFE5D3);
  static const gold = Color(0xFFD9A54A);
  static const goldSoft = Color(0xFFF2D293);
  static const lavender = Color(0xFF8E9BE0);
  static const ink = Color(0xFF1C2333);
  static const inkSoft = Color(0xFF5C6475);
  static const heart = Color(0xFFD94A5A);

  /// Cancel buttons: red, with white text that stays readable on it.
  static const cancel = Color(0xFFC62828);

  /// Words of Jesus — red letters on the night sky, and on ivory cards.
  static const redLetter = Color(0xFFFF9E94);
  static const redLetterInk = Color(0xFFB3261E);
}

abstract final class AppText {
  /// Elegant serif for headings and Scripture. Non-Latin scripts fall back to
  /// the platform's Noto fonts automatically.
  static TextStyle serif(double size, {Color? color, FontWeight weight = FontWeight.w500, double? height}) =>
      GoogleFonts.cormorantGaramond(fontSize: size, color: color, fontWeight: weight, height: height);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: GoogleFonts.inter().fontFamily,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.navy,
      primary: AppColors.navy,
      secondary: AppColors.gold,
      surface: AppColors.ivory,
    ),
    scaffoldBackgroundColor: AppColors.ivory,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: AppColors.ink, displayColor: AppColors.ink),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: AppColors.ink,
      centerTitle: true,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        minimumSize: const Size(200, 52),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.ivoryCard,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.sand),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.sand),
      ),
    ),
  );
}
