import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/question.dart';

/// What someone chose for a day's question.
typedef QuestionAnswer = ({String id, String choice, bool right});

/// The daily Bible question: the same one for everyone each day, in turn, and the answers given —
/// kept on the phone.
class QuestionService extends ChangeNotifier {
  QuestionService(this._prefs, {DateTime Function()? now}) : _now = now ?? DateTime.now {
    try {
      final saved = jsonDecode(_prefs.getString(_key) ?? '{}') as Map<String, dynamic>;
      for (final MapEntry(:key, :value) in saved.entries) {
        final a = value as Map<String, dynamic>;
        _answers[key] = (id: a['id'] as String, choice: a['choice'] as String, right: a['right'] == true);
      }
    } catch (_) {}
  }

  final SharedPreferences _prefs;
  final DateTime Function() _now;
  final _answers = <String, QuestionAnswer>{};

  static const _key = 'bibleQuestions';

  /// Missed days can still be answered, this far back.
  static const daysBack = 7;

  /// Answers older than this are let go.
  static const _keepDays = 400;

  static String dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  DateTime get today {
    final n = _now();
    return DateTime(n.year, n.month, n.day);
  }

  /// Today and the days before it that can still be answered, newest first.
  List<DateTime> get days => [for (var i = 0; i < daysBack; i++) DateTime(today.year, today.month, today.day - i)];

  /// [day]'s question: they come in turn, the same for everyone on the same date.
  static BibleQuestion? questionFor(List<BibleQuestion> questions, DateTime day) {
    if (questions.isEmpty) return null;
    final n = DateTime.utc(day.year, day.month, day.day).difference(DateTime.utc(2026)).inDays;
    return questions[n % questions.length];
  }

  /// The options in their order for [day]: shuffled, but the same each time it is opened.
  static List<String> shuffled(BibleQuestion q, DateTime day) {
    var seed = day.year * 10000 + day.month * 100 + day.day;
    for (final unit in q.id.codeUnits) {
      seed = (seed * 31 + unit) & 0x7fffffff;
    }
    return [...q.options]..shuffle(Random(seed));
  }

  QuestionAnswer? answerFor(DateTime day) => _answers[dayKey(day)];

  int get answered => _answers.length;
  int get right => _answers.values.where((a) => a.right).length;

  Future<void> answer(DateTime day, BibleQuestion q, String choice) async {
    final key = dayKey(day);
    if (_answers.containsKey(key)) return;
    _answers[key] = (id: q.id, choice: choice, right: choice == q.answer);
    final oldest = dayKey(DateTime(today.year, today.month, today.day - _keepDays));
    _answers.removeWhere((k, _) => k.compareTo(oldest) < 0);
    await _prefs.setString(_key, jsonEncode({
      for (final MapEntry(:key, :value) in _answers.entries)
        key: {'id': value.id, 'choice': value.choice, 'right': value.right},
    }));
    notifyListeners();
  }
}
