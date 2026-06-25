import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    if (kIsWeb) return; // Notifications not natively supported on web in this setup
    
    tz.initializeTimeZones();
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      // Handle both String (web) and TimezoneInfo (native)
      final String timeZoneName = tzInfo is String ? tzInfo : (tzInfo as dynamic).name;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      // Fallback
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    try {
      await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings: initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          // Handle notification tap
        },
      );
    } catch (e) {
      // Ignore
    }
  }

  Future<void> scheduleInterviewReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    if (kIsWeb || scheduledDate.isBefore(DateTime.now())) return;

    try {
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(scheduledDate, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'interview_reminders',
            'Interview Reminders',
            channelDescription: 'Reminders for your upcoming job interviews',
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        // uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      // Handle gracefully
    }
  }

  Future<void> cancelReminder(int id) async {
    if (kIsWeb) return;
    try {
      await _flutterLocalNotificationsPlugin.cancel(id: id);
    } catch (e) {
      // Ignore
    }
  }
}
