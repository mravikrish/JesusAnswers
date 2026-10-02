import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// The Daily Word reminder: one local notification a day at the user's chosen time.
/// Scheduled on the device, so it needs no server and works offline.
class ReminderService {
  static const _id = 1;
  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _ready;

  Future<void> _init() => _ready ??= () async {
        tzdata.initializeTimeZones();
        try {
          tz.setLocalLocation(tz.getLocation((await FlutterTimezone.getLocalTimezone()).identifier));
        } catch (_) {
          // Unknown zone name: fall back to UTC + today's offset, right everywhere without daylight saving.
          final zone = tz.TimeZone(DateTime.now().timeZoneOffset, isDst: false, abbreviation: 'LOCAL');
          tz.setLocalLocation(tz.Location('Local', const [], const [], [zone]));
        }
        await _plugin.initialize(
          settings: const InitializationSettings(
            android: AndroidInitializationSettings('@mipmap/ic_launcher'),
            iOS: DarwinInitializationSettings(
              requestAlertPermission: false,
              requestBadgePermission: false,
              requestSoundPermission: false,
            ),
          ),
        );
      }();

  /// Asks for notification permission (Android 13+, iOS). Returns false if the user declines.
  Future<bool> requestPermission() async {
    await _init();
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ??
        await ios?.requestPermissions(alert: true, sound: true) ??
        true;
  }

  /// Schedules the reminder daily at [minuteOfDay] (e.g. 7:30 → 450), or cancels it when null.
  Future<void> sync(int? minuteOfDay, {required String title, required String body}) async {
    await _init();
    await _plugin.cancel(id: _id);
    if (minuteOfDay == null) return;

    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(tz.local, now.year, now.month, now.day, minuteOfDay ~/ 60, minuteOfDay % 60);
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));

    await _plugin.zonedSchedule(
      id: _id,
      scheduledDate: at,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails('daily_word', 'Daily Word', importance: Importance.defaultImportance),
        iOS: DarwinNotificationDetails(),
      ),
      // Inexact is fine for a daily reminder and needs no "exact alarm" permission.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}
