import 'package:flutter/material.dart';

import 'history_page.dart';
import 'statistics_page.dart';

/// Membungkus halaman Riwayat lama tanpa mengubah isinya.
class HistoryWithStatisticsPage extends StatefulWidget {
  const HistoryWithStatisticsPage({super.key});

  @override
  State<HistoryWithStatisticsPage> createState() =>
      _HistoryWithStatisticsPageState();
}

class _HistoryWithStatisticsPageState extends State<HistoryWithStatisticsPage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 0, label: Text('Statistik')),
                ButtonSegment(value: 1, label: Text('Riwayat Obat')),
              ],
              selected: {_tab},
              onSelectionChanged: (value) =>
                  setState(() => _tab = value.first),
            ),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _tab,
            children: const [
              StatisticsPage(),
              HistoryPage(),
            ],
          ),
        ),
      ],
    );
  }
}
