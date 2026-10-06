import 'package:flutter_test/flutter_test.dart';
import 'package:jesus_answers/core/languages.dart';
import 'package:jesus_answers/data/bible/bible_repository.dart';
import 'package:jesus_answers/services/days_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late DateTime now;
  DaysService days() => DaysService(prefs, now: () => now);

  /// Marks a day with Jesus on each of [dates] (October 2026), in order.
  Future<DaysService> visit(List<int> dates) async {
    final d = days();
    for (final date in dates) {
      now = DateTime(2026, 10, date, 21);
      await d.mark();
    }
    return d;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    now = DateTime(2026, 10, 1, 9);
  });

  test('nothing yet on the first visit', () {
    expect(days().total, 0);
    expect(days().streak, 0);
    expect(days().pending, isNull);
  });

  test('a day counts once, however much is done in it', () async {
    final d = await visit([1, 1, 1]);
    expect(d.total, 1);
    expect(d.streak, 1);
  });

  test('the run stays alive until today has passed', () async {
    final d = await visit([1, 2, 3]);
    now = DateTime(2026, 10, 4, 8); // morning, not opened yet today
    expect(d.streak, 3);
    expect(d.today, isFalse);
  });

  test('one missed day a week is forgiven; the total never goes down', () async {
    // Missed the 4th: forgiven.
    var d = await visit([1, 2, 3, 5, 6]);
    expect(d.streak, 5);
    // Missed the 7th too, in the same week: the 7th is forgiven, the 4th no longer is — 5th, 6th, 8th.
    d = await visit([8]);
    expect(d.streak, 3);
    expect(d.total, 6);
    // Two days missed in a row are not forgiven.
    d = await visit([11]);
    expect(d.streak, 1);
    expect(d.total, 7);
  });

  test('a missed day after a week is forgiven again', () async {
    final d = await visit([1, 2, 4, 5, 6, 7, 8, 9, 10, 12]);
    expect(d.streak, 10);
  });

  test('each milestone is celebrated once, until put away', () async {
    final d = await visit([for (var i = 1; i <= 6; i++) i]);
    expect(d.pending, isNull);
    await visit([7]);
    expect(days().pending?.days, 7);
    expect(days().pending?.ref, 'LAM 3:23');
    await days().dismissMilestone();
    expect(days().pending, isNull);
    await visit([8]);
    expect(days().pending, isNull);
  });

  test('every milestone verse is in the Bible, in every language', () async {
    final bible = BibleRepository();
    for (final lang in appLanguages) {
      for (final m in DaysService.milestones) {
        final v = await bible.fullVerse(m.ref, lang.code);
        expect(v?.text, isNotEmpty, reason: '${lang.code} ${m.ref}');
      }
    }
  });
}
