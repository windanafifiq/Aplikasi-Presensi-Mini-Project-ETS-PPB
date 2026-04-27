import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../main.dart';

class NotificationService {
  Future<void> showAttendanceSuccess(String name, String sessionId) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'attendance_channel',
      'Attendance Notifications',
      channelDescription: 'Notifikasi keberhasilan presensi',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const NotificationDetails details =
        NotificationDetails(android: androidDetails);
    await flutterLocalNotificationsPlugin.show(
      0,
      '✅ Presensi Berhasil!',
      'Halo $name, presensi untuk sesi $sessionId tercatat.',
      details,
    );
  }

  Future<void> showLocationError() async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'attendance_channel',
      'Attendance Notifications',
      channelDescription: 'Notifikasi keberhasilan presensi',
      importance: Importance.high,
      priority: Priority.high,
    );
    const NotificationDetails details =
        NotificationDetails(android: androidDetails);
    await flutterLocalNotificationsPlugin.show(
      1,
      '❌ Presensi Gagal',
      'Kamu tidak berada dalam radius kampus.',
      details,
    );
  }
}