
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  final _menuTitles = const [
    'Beranda',
    'Obat',
    'Kontrol',
    'Riwayat',
  ];

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

  Widget _dashboard() {
    final email = _auth.currentUser?.email ?? 'Pengguna';
    final username = email.split('@').first;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Halo, $username!',
          style: const TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.bold,
            color: dark,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 5),
        Text(
          _today(),
          style: const TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 22),

        Container(
          padding: const EdgeInsets.all(23),
          decoration: BoxDecoration(
           gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
                Color(0xFF2563EB),
                Color(0xFF60A5FA),
            ],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Jaga kesehatanmu!',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Atur jadwal obat dan kontrol '
                      'agar lebih mudah diingat.',
                      style: TextStyle(
                        color: Colors.white,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 10),
              Icon(
                Icons.favorite_rounded,
                color: Colors.white,
                size: 48,
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),

        const Text(
          'Ringkasan Hari Ini',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
            color: dark,
          ),
        ),
        const SizedBox(height: 14),

        Row(
          children: [
            _summaryCard(
              icon: Icons.medication_outlined,
              value: '—',
              label: 'Jadwal obat',
              color: teal,
            ),
            const SizedBox(width: 12),
            _summaryCard(
              icon: Icons.check_circle_outline,
              value: '—',
              label: 'Sudah diminum',
              color: const Color(0xFF34A76D),
            ),
          ],
        ),
        const SizedBox(height: 24),

        const Text(
          'Jadwal Obat',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
            color: dark,
          ),
        ),
        const SizedBox(height: 12),

        _emptyInfo(
          icon: Icons.medication_liquid_outlined,
          title: 'Belum ada jadwal obat',
          description:
              'Fitur tambah dan pengelolaan obat '
              'akan tersedia pada tahap berikutnya.',
        ),
        const SizedBox(height: 24),

        const Text(
          'Jadwal Kontrol',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
            color: dark,
          ),
        ),
        const SizedBox(height: 12),

        _emptyInfo(
          icon: Icons.calendar_month_outlined,
          title: 'Belum ada jadwal kontrol',
          description:
              'Nantinya jadwal kunjungan dokter '
              'akan ditampilkan di sini.',
        ),
      ],
    );
  }

  Widget _comingSoon() {
    final title = _menuTitles[_selectedIndex];

    IconData icon;
    String description;

    switch (_selectedIndex) {
      case 1:
        icon = Icons.medication_outlined;
        description =
            'Di sini kamu akan bisa menambah, '
            'mengubah, dan menghapus jadwal obat.';
        break;
      case 2:
        icon = Icons.calendar_month_outlined;
        description =
            'Di sini kamu akan mengatur tanggal, '
            'jam, poli, dan dokter untuk kontrol.';
        break;
      default:
        icon = Icons.history_rounded;
        description =
            'Di sini kamu akan melihat catatan '
            'obat yang sudah diminum.';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _emptyInfo(
          icon: icon,
          title: 'Menu $title',
          description:
              '$description\n\n'
              'Fitur ini akan kita buat selanjutnya.',
        ),
      ),
    );
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
