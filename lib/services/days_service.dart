import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A milestone of days with Jesus, and the verse it is celebrated with.
typedef Milestone = ({int days, String ref});

/// Days with Jesus: the days someone prayed, read or listened — kept on the phone.
///
/// Gentle on purpose: the total never goes down, and one missed day a week is
/// forgiven in the run of days, so missing a day never wipes out what they built.
class DaysService extends ChangeNotifier {
  DaysService(this._prefs, {DateTime Function()? now}) : _now = now ?? DateTime.now {
    _days.addAll(_prefs.getStringList(_daysKey) ?? const []);
  }

  final SharedPreferences _prefs;
  final DateTime Function() _now;
  final _days = <String>{};

  static const _daysKey = 'faithfulDays', _shownKey = 'milestonesShown', _pendingKey = 'milestonePending';

  /// Celebrated once each, with a verse from the reader's own Bible.
  static const List<Milestone> milestones = [
    (days: 7, ref: 'LAM 3:23'), // His mercies are new every morning
    (days: 21, ref: 'PSA 1:2'), // in his law doth he meditate day and night
    (days: 40, ref: 'MAT 4:4'), // as Jesus in the wilderness forty days
    (days: 100, ref: 'PHP 1:6'), // he which hath begun a good work in you will perform it
    (days: 365, ref: 'PSA 65:11'), // thou crownest the year with thy goodness
  ];

  static String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  DateTime get _today {
    final n = _now();
    return DateTime(n.year, n.month, n.day);
  }

  /// The day before [d] (by the calendar, so clock changes don't skip a day).
  static DateTime _before(DateTime d) => DateTime(d.year, d.month, d.day - 1);

  bool _marked(DateTime d) => _days.contains(_key(d));

  /// Every day with Jesus so far. Never goes down.
  int get total => _days.length;

  bool get today => _marked(_today);

  /// Days in a row up to today — still alive until today has passed, and with one missed day a
  /// week forgiven.
  int get streak {
    var d = today ? _today : _before(_today);
    DateTime? forgiven;
    var n = 0;
    while (true) {
      if (_marked(d)) {
        n++;
      } else if (_marked(_before(d)) &&
          (forgiven == null || (forgiven.difference(d).inHours / 24).round() >= 7)) {
        forgiven = d;
      } else {
        return n;
      }
      d = _before(d);
    }
  }

  /// A milestone reached and not yet seen, to celebrate on Home.
  Milestone? get pending {
    final days = _prefs.getInt(_pendingKey);
    return milestones.where((m) => m.days == days).firstOrNull;
  }

  /// Counts today as a day with Jesus: called when they pray, read or listen.
  Future<void> mark() async {
    if (today) return;
    _days.add(_key(_today));
    await _prefs.setStringList(_daysKey, _days.toList());
    final shown = _prefs.getStringList(_shownKey) ?? const [];
    final reached = milestones.where((m) => m.days == total && !shown.contains('${m.days}')).firstOrNull;
    if (reached != null) {
      await _prefs.setStringList(_shownKey, [...shown, '${reached.days}']);
      await _prefs.setInt(_pendingKey, reached.days);
    }
    notifyListeners();
  }

  Future<void> dismissMilestone() async {
    await _prefs.remove(_pendingKey);
    notifyListeners();
  }
}
