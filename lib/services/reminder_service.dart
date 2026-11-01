// 上课提醒服务：支持【系统推送消息 (Push Notification)】与【系统闹钟提醒 (System Alarm)】双模式
import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

enum ReminderMode {
  pushNotification, // 推送消息提醒
  systemAlarm,      // 系统闹钟提醒
  both,             // 推送 + 闹钟双重提醒
}

class CourseReminderService {
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _notifications.initialize(initSettings);
  }

  /// 发送本地推送消息提醒
  Future<void> triggerCourseNotification({
    required int id,
    required String courseName,
    required String classroom,
    required String teacher,
    required String startTime,
    required int leadMinutes,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'hautpocket_class_reminder',
      '上课提醒通知',
      channelDescription: '河南工业大学 Hautpocket 课前推送提醒',
      importance: Importance.max,
      priority: Priority.high,
    );
    await _notifications.show(
      id,
      '上课提醒：$courseName（$leadMinutes分钟后）',
      '时间：$startTime | 地点：$classroom | 教师：$teacher',
      const NotificationDetails(android: androidDetails),
    );
  }

  /// 调用 Android 原生系统时钟设置课前闹钟 (ACTION_SET_ALARM)
  Future<void> setSystemAlarmForCourse({
    required String courseName,
    required String classroom,
    required int hour,
    required int minute,
    required int leadMinutes,
  }) async {
    int totalMins = hour * 60 + minute - leadMinutes;
    if (totalMins < 0) totalMins += 24 * 60;
    final alarmHour = totalMins ~/ 60;
    final alarmMinute = totalMins % 60;

    final intent = AndroidIntent(
      action: 'android.intent.action.SET_ALARM',
      arguments: <String, dynamic>{
        'android.intent.extra.alarm.HOUR': alarmHour,
        'android.intent.extra.alarm.MINUTES': alarmMinute,
        'android.intent.extra.alarm.MESSAGE': 'Hautpocket 上课: $courseName @ $classroom',
        'android.intent.extra.alarm.SKIP_UI': false,
      },
    );
    await intent.launch();
  }
}
