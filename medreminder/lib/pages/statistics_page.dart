import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';

/// Statistik konsumsi obat dari jadwal obat dan catatan minum (Firestore).
/// Tidak mengubah data pengguna; halaman hanya membaca data.
class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  static const _blue = Color(0xFF2563EB);
  bool _monthly = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreService.medications.snapshots(),
      builder: (context, medicinesSnapshot) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirestoreService.logs.snapshots(),
          builder: (context, logsSnapshot) {
            if (medicinesSnapshot.hasError || logsSnapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'Gagal membaca statistik: '
                    '${medicinesSnapshot.error ?? logsSnapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            if (!medicinesSnapshot.hasData || !logsSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final now = DateTime.now();
            final days = _monthly ? 30 : 7;
            final today = DateTime(now.year, now.month, now.day);
            final firstDay = today.subtract(Duration(days: days - 1));
            final meds = medicinesSnapshot.data!.docs;
            final logs = logsSnapshot.data!.docs;
            final takenIds = <String>{};
            final recordedDaily = <String, int>{};

            for (final doc in logs) {
              final item = doc.data();
              if (item['status'] != 'taken') continue;
              final key = item['dateKey']?.toString();
              if (key == null) continue;
              takenIds.add(doc.id);
              recordedDaily[key] = (recordedDaily[key] ?? 0) + 1;
            }

            int planned = 0;
            int confirmedOnCurrentSchedule = 0;
            final chartDays = <_DayStat>[];

            for (var offset = 0; offset < days; offset++) {
              final day = firstDay.add(Duration(days: offset));
              final key = FirestoreService.dayKey(day);
              var dayPlanned = 0;
              var dayConfirmed = 0;

              for (final medDoc in meds) {
                final med = medDoc.data();
                if (med['startDate'] is! Timestamp ||
                    med['endDate'] is! Timestamp ||
                    med['times'] is! List) {
                  continue;
                }
                if (!FirestoreService.activeOn(med, day)) continue;
                for (final time in List<String>.from(med['times'])) {
                  final parts = time.split(':');
                  if (parts.length != 2) continue;
                  final hour = int.tryParse(parts[0]);
                  final minute = int.tryParse(parts[1]);
                  if (hour == null || minute == null ||
                      hour < 0 || hour > 23 || minute < 0 || minute > 59) {
                    continue;
                  }
                  final scheduled = DateTime(
                    day.year, day.month, day.day, hour, minute,
                  );
                  // Tidak menghitung dosis masa depan sebagai belum diminum.
                  if (scheduled.isAfter(now)) continue;
                  dayPlanned++;
                  if (takenIds.contains(
                    FirestoreService.logId(medDoc.id, day, time),
                  )) {
                    dayConfirmed++;
                  }
                }
              }

              planned += dayPlanned;
              confirmedOnCurrentSchedule += dayConfirmed;
              chartDays.add(_DayStat(day, recordedDaily[key] ?? 0));
            }

            // Jumlah seluruh konfirmasi, termasuk obat yang sudah dihapus.
            final allRecorded = chartDays.fold<int>(
              0, (total, day) => total + day.confirmed,
            );
            final unconfirmed = planned - confirmedOnCurrentSchedule;
            final adherence = planned == 0
                ? 0
                : (confirmedOnCurrentSchedule * 100 / planned).round();
            final groups = <_ChartGroup>[];
            if (_monthly) {
              for (var i = 0; i < 5; i++) {
                final group = chartDays.skip(i * 6).take(6).toList();
                groups.add(_ChartGroup('P${i + 1}',
                    group.fold(0, (sum, day) => sum + day.confirmed)));
              }
            } else {
              for (final day in chartDays) {
                const labels = [
                  'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'
                ];
                groups.add(_ChartGroup(
                  labels[day.day.weekday - 1], day.confirmed,
                ));
              }
            }
            final maxBar = groups.fold<int>(
              1, (value, group) => group.count > value ? group.count : value,
            );

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
              children: [
                const Text('Statistik Konsumsi Obat',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text('Pantau catatan minum obatmu dari waktu ke waktu.',
                    style: TextStyle(color: Colors.black54)),
                const SizedBox(height: 16),
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: false, label: Text('7 hari')),
                    ButtonSegment(value: true, label: Text('30 hari')),
                  ],
                  selected: {_monthly},
                  onSelectionChanged: (values) =>
                      setState(() => _monthly = values.first),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: _statCard('Tercatat diminum', '$allRecorded',
                      Icons.check_circle_outline, const Color(0xFF059669))),
                  const SizedBox(width: 10),
                  Expanded(child: _statCard('Dosis terjadwal', '$planned',
                      Icons.medication_outlined, _blue)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _statCard('Belum dikonfirmasi', '$unconfirmed',
                      Icons.schedule, const Color(0xFFD97706))),
                  const SizedBox(width: 10),
                  Expanded(child: _statCard('Kepatuhan', '$adherence%',
                      Icons.insights_outlined, _blue)),
                ]),
                const SizedBox(height: 16),
                _panel(Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Grafik konfirmasi minum obat',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(_monthly
                        ? 'Jumlah catatan per 6 hari selama 30 hari terakhir'
                        : 'Jumlah catatan per hari selama 7 hari terakhir',
                        style: const TextStyle(color: Colors.black54, fontSize: 12)),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 150,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (final group in groups)
                            Expanded(child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text('${group.count}',
                                    style: const TextStyle(fontSize: 11)),
                                const SizedBox(height: 5),
                                Container(
                                  height: 104 * group.count / maxBar + 4,
                                  width: _monthly ? 30 : 24,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF60A5FA),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(group.label,
                                    style: const TextStyle(fontSize: 11)),
                              ],
                            )),
                        ],
                      ),
                    ),
                  ],
                )),
                const SizedBox(height: 16),
                _panel(Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Konfirmasi sesuai jadwal saat ini: '
                        '$confirmedOnCurrentSchedule dari $planned dosis',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: planned == 0
                          ? 0
                          : confirmedOnCurrentSchedule / planned,
                      minHeight: 9,
                      borderRadius: BorderRadius.circular(12),
                      color: _blue,
                      backgroundColor: const Color(0xFFE2E8F0),
                    ),
                  ],
                )),
                const SizedBox(height: 14),
                const Text(
                  'Catatan: "Tercatat diminum" dihitung dari tombol '
                  '"Sudah diminum" (bukan bukti obat benar-benar dikonsumsi). '
                  '"Belum dikonfirmasi" bukan berarti obat pasti terlewat. '
                  'Perhitungan dosis terjadwal memakai jadwal obat yang masih '
                  'tersimpan saat ini; mengubah atau menghapus jadwal lama '
                  'dapat memengaruhi persentase periode sebelumnya.',
                  style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.5),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return _panel(Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 23),
        const SizedBox(height: 12),
        Text(value, style: const TextStyle(
          fontSize: 25, fontWeight: FontWeight.bold,
        )),
        const SizedBox(height: 4),
        Text(label, maxLines: 2,
            style: const TextStyle(fontSize: 12, color: Colors.black54)),
      ],
    ));
  }

  Widget _panel(Widget child) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: child,
    );
  }
}

class _DayStat {
  const _DayStat(this.day, this.confirmed);
  final DateTime day;
  final int confirmed;
}

class _ChartGroup {
  const _ChartGroup(this.label, this.count);
  final String label;
  final int count;
}
