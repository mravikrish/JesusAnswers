package com.jesusanswers.api.bible;

/** Same shape as the app's Verse model (lib/data/models/verse.dart). */
public record Verse(String ref, String reference, String text, String translation, String lang) {}
