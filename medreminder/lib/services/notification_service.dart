import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static const String _medicinePrefix = 'medreminder-med:';
  static const String _controlPrefix = 'medreminder-control:';

  static const NotificationDetails _medicineDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'medreminder_medicine',
      'Pengingat Minum Obat',
      channelDescription: 'Jadwal minum obat MedReminder',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  static const NotificationDetails _controlDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'medreminder_control',
      'Pengingat Jadwal Kontrol',
      channelDescription: 'Pengingat jadwal kontrol MedReminder',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  static Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    final zone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zone.identifier));

    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );

    _initialized = true;
    debugPrint('NOTIF zona waktu: ${tz.local.name}');
  }

  static Future<bool> requestPermission() async {
    await init();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.requestNotificationsPermission() ?? false;
  }

  static Future<bool> requestExactAlarmPermission() async {
    await init();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.requestExactAlarmsPermission() ?? false;
  }

  static int _notificationId(String key) {
    var hash = 2166136261;
    for (final char in key.codeUnits) {
      hash = ((hash ^ char) * 16777619) & 0x7fffffff;
    }
    return hash;
  }

  static bool _isOurReminder(String? payload) {
    return (payload ?? '').startsWith(_medicinePrefix) ||
        (payload ?? '').startsWith(_controlPrefix);
  }

  /// Sinkronisasi pengingat obat dan kontrol dari Firestore.
  /// Jadwal yang tidak berubah tetap dipertahankan.
  static Future<void> syncReminders() async {
    await init();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final allowed = await requestPermission();
    if (!allowed) {
      debugPrint('NOTIF: izin notifikasi ditolak.');
      return;
    }

    // Jika izin exact alarm belum diberikan, gunakan alarm inexact.
    final exactAllowed = await requestExactAlarmPermission();
    debugPrint('NOTIF: izin alarm presisi = $exactAllowed');
    final scheduleMode = exactAllowed
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    // Sufiks mode mengganti alarm inexact ketika izin exact diberikan.
    final modeSuffix = exactAllowed ? ':exact' : ':inexact';

    final db = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final results = await Future.wait([
      db.collection('medications').get(),
      db.collection('appointments').get(),
    ]);

    final desired =
        <String, ({String title, String body, DateTime date, bool medicine})>{};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    const maxDays = 14;

    // =============================================================
    // JADWAL OBAT - DIPERTAHANKAN DARI KODE SEBELUMNYA
    // =============================================================
    for (final doc in results[0].docs) {
      final med = doc.data();
      if (med['startDate'] is! Timestamp || med['endDate'] is! Timestamp) {
        continue;
      }

      final start = (med['startDate'] as Timestamp).toDate();
      final end = (med['endDate'] as Timestamp).toDate();
      final first = DateTime(start.year, start.month, start.day);
      final last = DateTime(end.year, end.month, end.day);
      final name = (med['name'] ?? 'Obat').toString();
      final dosage = (med['dosage'] ?? '').toString();
      final times = List<String>.from(med['times'] ?? const <String>[]);

      for (var offset = 0; offset < maxDays; offset++) {
        final day = DateTime(today.year, today.month, today.day + offset);
        if (day.isBefore(first) || day.isAfter(last)) continue;

        for (final time in times) {
          final parts = time.split(':');
          if (parts.length != 2) continue;

          final hour = int.tryParse(parts[0]);
          final minute = int.tryParse(parts[1]);
          if (hour == null ||
              minute == null ||
              hour < 0 ||
              hour > 23 ||
              minute < 0 ||
              minute > 59) {
            continue;
          }

          final when = DateTime(day.year, day.month, day.day, hour, minute);
          if (!when.isAfter(now)) continue;

          final key =
              '$_medicinePrefix${user.uid}:${doc.id}:'
              '${day.year}-${day.month}-${day.day}:$time$modeSuffix';
          desired[key] = (
            title: 'Waktunya Minum Obat',
            body: '$name - $dosage ($time)',
            date: when,
            medicine: true,
          );
        }
      }
    }

    // =============================================================
    // JADWAL KONTROL - H-1, H-1 JAM, H-10 MENIT
    // =============================================================
    for (final doc in results[1].docs) {
      final data = doc.data();
      if (data['dateTime'] is! Timestamp) continue;

      final appointment = (data['dateTime'] as Timestamp).toDate();
      if (!appointment.isAfter(now)) continue;
      if (appointment.isAfter(now.add(const Duration(days: maxDays)))) {
        continue;
      }

      final clinic = (data['clinic'] ?? 'Poli').toString();
      final doctor = (data['doctor'] ?? '').toString();
      final doctorText = doctor.isEmpty ? '' : ' bersama $doctor';
      final hour = appointment.hour.toString().padLeft(2, '0');
      final minute = appointment.minute.toString().padLeft(2, '0');
      final controlBody =
          'Jadwal kontrol di $clinic$doctorText pukul $hour:$minute';

      final reminders = [
        (
          label: 'h1',
          title: 'Pengingat Kontrol Besok',
          date: appointment.subtract(const Duration(days: 1)),
        ),
        (
          label: 'h1jam',
          title: 'Kontrol 1 Jam Lagi',
          date: appointment.subtract(const Duration(hours: 1)),
        ),
        (
          label: 'h10menit',
          title: 'Kontrol 10 Menit Lagi',
          date: appointment.subtract(const Duration(minutes: 10)),
        ),
      ];

      var hasFutureReminder = false;
      for (final reminder in reminders) {
        if (!reminder.date.isAfter(now)) continue;

        final key =
            '$_controlPrefix${user.uid}:${doc.id}:'
            '${appointment.millisecondsSinceEpoch}:${reminder.label}$modeSuffix';
        desired[key] = (
          title: reminder.title,
          body: controlBody,
          date: reminder.date,
          medicine: false,
        );
        hasFutureReminder = true;
      }

      // Jika jadwal dibuat kurang dari 10 menit sebelum pemeriksaan,
      // tetap buat pengingat tepat pada jam pemeriksaan.
      if (!hasFutureReminder) {
        final key =
            '$_controlPrefix${user.uid}:${doc.id}:'
            '${appointment.millisecondsSinceEpoch}:waktu_kontrol$modeSuffix';
        desired[key] = (
          title: 'Waktunya Kontrol Kesehatan',
          body: controlBody,
          date: appointment,
          medicine: false,
        );
      }
    }

    // =============================================================
    // SINKRONISASI - MEMPERTAHANKAN ALARM YANG BELUM BERUBAH
    // =============================================================
    final pending = await _plugin.pendingNotificationRequests();
    final ours = pending.where((item) => _isOurReminder(item.payload));
    final pendingKeys = <String>{};

    for (final item in ours) {
      final key = item.payload!;
      final target = desired[key];
      if (target != null &&
          item.title == target.title &&
          item.body == target.body) {
        pendingKeys.add(key);
      } else {
        await _plugin.cancel(item.id);
      }
    }

    var newlyScheduled = 0;
    for (final entry in desired.entries) {
      if (pendingKeys.contains(entry.key)) continue;
      if (pendingKeys.length + newlyScheduled >= 200) break;

      final reminder = entry.value;
      await _plugin.zonedSchedule(
        _notificationId(entry.key),
        reminder.title,
        reminder.body,
        tz.TZDateTime.from(reminder.date, tz.local),
        reminder.medicine ? _medicineDetails : _controlDetails,
        androidScheduleMode: scheduleMode,
        payload: entry.key,
      );
      newlyScheduled++;
    }

    debugPrint(
      'NOTIF: jadwal baru=$newlyScheduled, '
      'sebelumnya=${pendingKeys.length}, '
      'total pending=${await pendingCount()}',
    );
  }

  static Future<int> pendingCount() async {
    await init();
    final pending = await _plugin.pendingNotificationRequests();
    return pending.where((item) => _isOurReminder(item.payload)).length;
  }

  static Future<void> cancelAllReminders() async {
    await init();
    final pending = await _plugin.pendingNotificationRequests();
    for (final item in pending) {
      if (_isOurReminder(item.payload)) {
        await _plugin.cancel(item.id);
      }
    }
  }
}
