import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});
  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF5F9FF),
    body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreService.logs.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Gagal membaca riwayat: ${snapshot.error}'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = [...snapshot.data!.docs]..sort((a, b) =>
          (b.data()['scheduledAt'] as Timestamp).compareTo(a.data()['scheduledAt'] as Timestamp));
        return ListView(padding: const EdgeInsets.all(16), children: [
          const Text('Riwayat Konsumsi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
          const SizedBox(height: 6),
          const Text('Riwayat berdasarkan konfirmasi pengguna, bukan verifikasi medis.',
            style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 18),
          if (docs.isEmpty) const Card(child: Padding(
            padding: EdgeInsets.all(24), child: Center(child: Text('Belum ada obat yang ditandai sudah diminum.')))),
          for (final doc in docs)
            Card(color: Colors.white, margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: const Icon(Icons.check_circle, color: Color(0xFF2563EB)),
                title: Text('${doc.data()['medicationName']} · ${doc.data()['dosage']}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Builder(builder: (_) {
                  final date = (doc.data()['scheduledAt'] as Timestamp).toDate();
                  return Text('${FirestoreService.formatDate(date)} · Jadwal ${doc.data()['scheduleTime']}\nSudah diminum');
                }),
              )),
        ]);
      },
    ),
  );
}
