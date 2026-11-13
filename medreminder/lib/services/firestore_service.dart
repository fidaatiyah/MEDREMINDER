import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static String get _uid {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Pengguna belum login.');
    return user.uid;
  }

  static CollectionReference<Map<String, dynamic>> get medications =>
      _db.collection('users').doc(_uid).collection('medications');

  static CollectionReference<Map<String, dynamic>> get appointments =>
      _db.collection('users').doc(_uid).collection('appointments');

  static CollectionReference<Map<String, dynamic>> get logs =>
      _db.collection('users').doc(_uid).collection('medication_logs');

  static String dayKey(DateTime d) =>
      '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

  static String formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  static String formatTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  static bool activeOn(Map<String, dynamic> m, DateTime day) {
    final s = (m['startDate'] as Timestamp).toDate();
    final e = (m['endDate'] as Timestamp).toDate();
    final date = DateTime(day.year, day.month, day.day);
    return !date.isBefore(DateTime(s.year, s.month, s.day)) &&
        !date.isAfter(DateTime(e.year, e.month, e.day));
  }

  static String logId(String medId, DateTime date, String time) =>
      '${medId}_${dayKey(date)}_${time.replaceAll(':', '')}';

  static Future<void> markTaken(String medId, Map<String, dynamic> med, String time) async {
    final now = DateTime.now();
    final parts = time.split(':');
    await logs.doc(logId(medId, now, time)).set({
      'medicationId': medId,
      'medicationName': med['name'],
      'dosage': med['dosage'],
      'scheduleTime': time,
      'dateKey': dayKey(now),
      'scheduledAt': Timestamp.fromDate(DateTime(now.year, now.month, now.day,
        int.parse(parts[0]), int.parse(parts[1]))),
      'takenAt': FieldValue.serverTimestamp(),
      'status': 'taken',
    });
  }
}
