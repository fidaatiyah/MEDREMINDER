
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import 'medication_page.dart';
import 'appointment_page.dart';
import 'history_page.dart';
import '../services/auth_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _auth = AuthService();
  int _selectedIndex = 0;

  static const teal = Color(0xFF008F83);
  static const dark = Color(0xFF173E39);

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Keluar dari akun?'),
        content: const Text(
          'Kamu bisa masuk kembali menggunakan '
          'email dan password.',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (shouldLogout != true || !mounted) return;

    try {
      await _auth.logout();
      // AuthGate otomatis kembali ke halaman Login.
    } on FirebaseAuthException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal logout. Silakan coba lagi.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Terjadi kesalahan saat logout.'),
        ),
      );
    }
  }

  String _today() {
    final now = DateTime.now();
    const days = [
      'Senin', 'Selasa', 'Rabu', 'Kamis',
      'Jumat', 'Sabtu', 'Minggu',
    ];
    const months = [
      'Januari', 'Februari', 'Maret', 'April',
      'Mei', 'Juni', 'Juli', 'Agustus',
      'September', 'Oktober', 'November', 'Desember',
    ];

    return '${days[now.weekday - 1]}, '
        '${now.day} ${months[now.month - 1]} ${now.year}';
  }

  Widget _panel({
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFE7EFED),
        ),
      ),
      child: child,
    );
  }

  Widget _emptyInfo({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return _panel(
      child: Column(
        children: [
          Container(
            height: 60,
            width: 60,
            decoration: BoxDecoration(
              color: const Color(0xFFE9F7F4),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: teal, size: 30),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: dark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black54,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFE7EFED),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 25),
            const SizedBox(height: 14),
            Text(
              value,
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
                color: dark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Jadwal di Firestore memakai tanggal mulai/akhir dan daftar jam.
  // Satu jam dihitung sebagai satu dosis (bukan satu jenis obat).
  Widget _dashboard() {
    final email = _auth.currentUser?.email ?? 'Pengguna';
    final username = email.split('@').first;
    final today = DateTime.now();
    final todayKey = FirestoreService.dayKey(today);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreService.medications.snapshots(),
      builder: (context, medicationSnapshot) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirestoreService.logs.snapshots(),
          builder: (context, logSnapshot) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirestoreService.appointments.snapshots(),
              builder: (context, appointmentSnapshot) {
                final error = medicationSnapshot.error ??
                    logSnapshot.error ?? appointmentSnapshot.error;
                final loading = !medicationSnapshot.hasData ||
                    !logSnapshot.hasData || !appointmentSnapshot.hasData;

                final meds = medicationSnapshot.data?.docs ?? [];
                final logIds = logSnapshot.data?.docs
                        .where((d) => d.data()['dateKey'] == todayKey &&
                            d.data()['status'] == 'taken')
                        .map((d) => d.id)
                        .toSet() ??
                    <String>{};

                final schedules = <({String id, String name, String dose, String time, bool taken})>[];
                for (final doc in meds) {
                  final data = doc.data();
                  if (!FirestoreService.activeOn(data, today)) continue;
                  final times = List<String>.from(data['times'] ?? []);
                  for (final time in times) {
                    schedules.add((
                      id: doc.id,
                      name: (data['name'] ?? 'Obat').toString(),
                      dose: (data['dosage'] ?? '').toString(),
                      time: time,
                      taken: logIds.contains(FirestoreService.logId(doc.id, today, time)),
                    ));
                  }
                }
                schedules.sort((a, b) => a.time.compareTo(b.time));
                final completed = schedules.where((s) => s.taken).length;
                final total = schedules.length;

                final appointments = <({DateTime date, String poli, String doctor, String time})>[];
                for (final doc in appointmentSnapshot.data?.docs ?? []) {
                  final data = doc.data();
                  final date = _appointmentDate(data);
                  if (date == null) continue;
                  final day = DateTime(date.year, date.month, date.day);
                  final nowDay = DateTime(today.year, today.month, today.day);
                  if (day.isBefore(nowDay)) continue;
                  appointments.add((
                    date: date,
                    poli: (data['poli'] ?? data['polyclinic'] ?? data['clinic'] ?? 'Poli').toString(),
                    doctor: (data['doctor'] ?? data['doctorName'] ?? data['dokter'] ?? '').toString(),
                    time: (data['time'] ?? data['appointmentTime'] ??
                            data['jam'] ?? FirestoreService.formatTime(date)).toString(),
                  ));
                }
                appointments.sort((a, b) => a.date.compareTo(b.date));

                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text('Halo, $username!',
                      style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold, color: dark),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 5),
                    Text(_today(), style: const TextStyle(color: Colors.black54)),
                    const SizedBox(height: 22),
                    Container(
                      padding: const EdgeInsets.all(23),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF2563EB), Color(0xFF60A5FA)],
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Row(children: [
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Jaga kesehatanmu!', style: TextStyle(
                              fontSize: 21, fontWeight: FontWeight.bold, color: Colors.white)),
                            SizedBox(height: 8),
                            Text('Atur jadwal obat dan kontrol agar lebih mudah diingat.',
                              style: TextStyle(color: Colors.white, height: 1.5)),
                          ],
                        )),
                        SizedBox(width: 10),
                        Icon(Icons.favorite_rounded, color: Colors.white, size: 48),
                      ]),
                    ),
                    const SizedBox(height: 26),
                    const Text('Ringkasan Hari Ini', style: TextStyle(
                      fontSize: 19, fontWeight: FontWeight.bold, color: dark)),
                    const SizedBox(height: 14),
                    if (error != null)
                      _panel(child: Text('Gagal membaca data Firebase: $error'))
                    else if (loading)
                      const Center(child: Padding(
                        padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
                    else ...[
                      Row(children: [
                        _summaryCard(icon: Icons.medication_outlined,
                          value: '$total', label: 'Jadwal obat', color: teal),
                        const SizedBox(width: 12),
                        _summaryCard(icon: Icons.check_circle_outline,
                          value: '$completed', label: 'Sudah diminum',
                          color: const Color(0xFF34A76D)),
                      ]),
                      const SizedBox(height: 16),
                      _panel(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Kepatuhan hari ini: ${total == 0 ? 0 : (completed * 100 / total).round()}%',
                            style: const TextStyle(fontWeight: FontWeight.w600, color: dark)),
                          const SizedBox(height: 10),
                          LinearProgressIndicator(
                            value: total == 0 ? 0 : completed / total,
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(20),
                            backgroundColor: const Color(0xFFE7EFED),
                            color: teal,
                          ),
                        ],
                      )),
                      const SizedBox(height: 24),
                      const Text('Jadwal Obat', style: TextStyle(
                        fontSize: 19, fontWeight: FontWeight.bold, color: dark)),
                      const SizedBox(height: 12),
                      if (schedules.isEmpty)
                        _emptyInfo(icon: Icons.medication_liquid_outlined,
                          title: 'Belum ada jadwal obat hari ini',
                          description: 'Tambahkan obat melalui menu Obat.')
                      else
                        _panel(child: Column(children: [
                          for (var i = 0; i < schedules.length; i++) ...[
                            if (i > 0) const Divider(height: 20),
                            Row(children: [
                              Icon(schedules[i].taken ? Icons.check_circle : Icons.medication_outlined,
                                color: schedules[i].taken ? Colors.green : teal),
                              const SizedBox(width: 12),
                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(schedules[i].name, style: const TextStyle(
                                    fontWeight: FontWeight.bold, color: dark)),
                                  Text('${schedules[i].dose} • ${schedules[i].time}',
                                    style: const TextStyle(color: Colors.black54)),
                                ],
                              )),
                              Text(schedules[i].taken ? 'Selesai' : 'Belum',
                                style: TextStyle(color: schedules[i].taken ? Colors.green : Colors.black54)),
                            ]),
                          ],
                        ])),
                      const SizedBox(height: 24),
                      const Text('Jadwal Kontrol', style: TextStyle(
                        fontSize: 19, fontWeight: FontWeight.bold, color: dark)),
                      const SizedBox(height: 12),
                      if (appointments.isEmpty)
                        _emptyInfo(icon: Icons.calendar_month_outlined,
                          title: 'Belum ada jadwal kontrol mendatang',
                          description: 'Periksa atau tambahkan jadwal melalui menu Kontrol.')
                      else
                        _panel(child: Column(children: [
                          for (var i = 0; i < appointments.length && i < 3; i++) ...[
                            if (i > 0) const Divider(height: 20),
                            Row(children: [
                              const Icon(Icons.calendar_month_outlined, color: teal),
                              const SizedBox(width: 12),
                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(appointments[i].poli, style: const TextStyle(
                                    fontWeight: FontWeight.bold, color: dark)),
                                  Text('${FirestoreService.formatDate(appointments[i].date)} • ${appointments[i].time}',
                                    style: const TextStyle(color: Colors.black54)),
                                  if (appointments[i].doctor.isNotEmpty)
                                    Text(appointments[i].doctor,
                                      style: const TextStyle(color: Colors.black54)),
                                ],
                              )),
                            ]),
                          ],
                        ])),
                    ],
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  // Menerima beberapa kemungkinan nama field tanggal kontrol.
  // Jika formatnya tidak dikenali, jangan tampilkan tanggal yang salah.
  DateTime? _appointmentDate(Map<String, dynamic> data) {
    final value = data['appointmentDate'] ?? data['date'] ??
        data['scheduledAt'] ?? data['dateTime'] ?? data['controlDate'];
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6FAF9),
        title: const Text(
          'MedReminder',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: dark,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Keluar',
            onPressed: _logout,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
            _dashboard(),
            const MedicationPage(),
            const AppointmentPage(),
            const HistoryPage(),
        ],
        ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFD8F2ED),
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.medication_outlined),
            selectedIcon: Icon(Icons.medication_rounded),
            label: 'Obat',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: 'Kontrol',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_rounded),
            label: 'Riwayat',
          ),
        ],
      ),
    );
  }
}
