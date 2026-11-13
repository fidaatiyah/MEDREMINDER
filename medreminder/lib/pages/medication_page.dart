import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

const _blue = Color(0xFF2563EB);
const _pale = Color(0xFFF5F9FF);

class MedicationPage extends StatelessWidget {
  const MedicationPage({super.key});

  Future<void> _edit(BuildContext context, [QueryDocumentSnapshot<Map<String, dynamic>>? doc]) async {
    final data = await Navigator.push<Map<String, dynamic>>(
      context, MaterialPageRoute(builder: (_) => _MedicationForm(existing: doc?.data())));
    if (data == null) return;
    try {
      if (doc == null) {
        await FirestoreService.medications.add(data);
      } else {
        await doc.reference.update(data);
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan obat: $e')));
    }
  }

  Future<void> _delete(BuildContext context, QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final yes = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Hapus obat?'),
      content: const Text('Jadwal dihapus, tetapi catatan riwayat yang sudah dibuat tetap ada.'),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Hapus'))],
    ));
    if (yes != true) return;
    try { await doc.reference.delete(); }
    catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Gagal menghapus: $e'))); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _pale,
    body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreService.medications.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Gagal membaca obat: ${snapshot.error}'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Belum ada jadwal obat. Tekan tombol Tambah Obat.', textAlign: TextAlign.center)));
        return ListView(padding: const EdgeInsets.all(16), children: [
          const Padding(padding: EdgeInsets.only(bottom: 12), child: Text('Jadwal Obat',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22))),
          for (final doc in docs)
            Card(color: Colors.white, margin: const EdgeInsets.only(bottom: 12),
              child: Padding(padding: const EdgeInsets.all(10), child: Row(children: [
                const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.medication, color: _blue)),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${doc.data()['name']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('Dosis: ${doc.data()['dosage']}'),
                  Text('Jam: ${(doc.data()['times'] as List).join(', ')}'),
                  Text('${FirestoreService.formatDate((doc.data()['startDate'] as Timestamp).toDate())} – '
                    '${FirestoreService.formatDate((doc.data()['endDate'] as Timestamp).toDate())}',
                    style: const TextStyle(color: Colors.black54, fontSize: 12)),
                  if (FirestoreService.activeOn(doc.data(), DateTime.now()))
                    _DoseActions(medId: doc.id, medication: doc.data()),
                ])),
                IconButton(tooltip: 'Ubah', onPressed: () => _edit(context, doc),
                  icon: const Icon(Icons.edit_outlined, color: _blue)),
                IconButton(tooltip: 'Hapus', onPressed: () => _delete(context, doc),
                  icon: const Icon(Icons.delete_outline, color: Colors.red)),
              ]))),
        ]);
      },
    ),
    floatingActionButton: FloatingActionButton.extended(
      heroTag: 'tambah_obat',
      onPressed: () => _edit(context),
      icon: const Icon(Icons.add),
      label: const Text('Tambah Obat'),
      backgroundColor: _blue,
      foregroundColor: Colors.white,
    ),
  );
}

class _MedicationForm extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const _MedicationForm({this.existing});
  @override State<_MedicationForm> createState() => _MedicationFormState();
}

class _MedicationFormState extends State<_MedicationForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _dose = TextEditingController();
  final _notes = TextEditingController();
  late DateTime _start, _end;
  List<TimeOfDay> _times = [const TimeOfDay(hour: 8, minute: 0)];
  String _fmt(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override void initState() {
    super.initState();
    final data = widget.existing;
    _start = data == null ? DateTime.now() : (data['startDate'] as Timestamp).toDate();
    _end = data == null ? DateTime.now().add(const Duration(days: 7)) : (data['endDate'] as Timestamp).toDate();
    if (data != null) {
      _name.text = data['name'] ?? '';
      _dose.text = data['dosage'] ?? '';
      _notes.text = data['notes'] ?? '';
      _times = (data['times'] as List).map((v) { final p = (v as String).split(':');
        return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1])); }).toList();
    }
  }
  @override void dispose() { _name.dispose(); _dose.dispose(); _notes.dispose(); super.dispose(); }

  Future<void> _date(bool start) async {
    final picked = await showDatePicker(context: context,
      initialDate: start ? _start : _end, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (picked != null) setState(() { if (start) { _start = picked; } else { _end = picked; } });
  }
  Future<void> _time() async {
    final picked = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 8, minute: 0));
    if (picked == null) return;
    if (_times.any((t) => _fmt(t) == _fmt(picked))) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Jam tersebut sudah dipilih')));
      return;
    }
    setState(() => _times.add(picked));
  }
  void _save() {
    if (!_form.currentState!.validate()) return;
    final start = DateTime(_start.year, _start.month, _start.day);
    final end = DateTime(_end.year, _end.month, _end.day);
    if (end.isBefore(start) || _times.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Tanggal selesai harus sesuai dan minimal satu jam harus dipilih.')));
      return;
    }
    final times = _times.map(_fmt).toList()..sort();
    Navigator.pop(context, {
      'name': _name.text.trim(), 'dosage': _dose.text.trim(), 'notes': _notes.text.trim(),
      'times': times, 'startDate': Timestamp.fromDate(start), 'endDate': Timestamp.fromDate(end),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: _pale,
    appBar: AppBar(title: Text(widget.existing == null ? 'Tambah Obat' : 'Ubah Obat'), backgroundColor: _pale),
    body: Form(key: _form, child: ListView(padding: const EdgeInsets.all(20), children: [
      TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Nama obat'),
        validator: (v) => v == null || v.trim().isEmpty ? 'Nama obat wajib diisi' : null),
      const SizedBox(height: 14),
      TextFormField(controller: _dose, decoration: const InputDecoration(labelText: 'Dosis (misalnya 500 mg)'),
        validator: (v) => v == null || v.trim().isEmpty ? 'Dosis wajib diisi' : null),
      const SizedBox(height: 14),
      Card(child: Column(children: [
        ListTile(title: const Text('Tanggal mulai'), subtitle: Text(FirestoreService.formatDate(_start)),
          trailing: const Icon(Icons.calendar_today), onTap: () => _date(true)),
        ListTile(title: const Text('Tanggal selesai'), subtitle: Text(FirestoreService.formatDate(_end)),
          trailing: const Icon(Icons.calendar_today), onTap: () => _date(false)),
      ])),
      const SizedBox(height: 14),
      const Text('Jam minum obat', style: TextStyle(fontWeight: FontWeight.bold)),
      Wrap(spacing: 8, children: [
        for (final t in _times) InputChip(label: Text(_fmt(t)),
          onDeleted: () => setState(() => _times.remove(t))),
        ActionChip(label: const Text('+ Tambah jam'), onPressed: _time),
      ]),
      const SizedBox(height: 14),
      TextFormField(controller: _notes, maxLines: 2,
        decoration: const InputDecoration(labelText: 'Catatan (opsional)')),
      const SizedBox(height: 24),
      FilledButton(onPressed: _save, child: const Text('Simpan Obat')),
    ])),
  );
}


// Tombol konfirmasi minum obat hari ini, per jam.
class _DoseActions extends StatelessWidget {
  final String medId;
  final Map<String, dynamic> medication;
  const _DoseActions({required this.medId, required this.medication});

  @override
  Widget build(BuildContext context) {
    final times = List<String>.from(medication['times'] ?? []);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreService.logs.snapshots(),
      builder: (context, snapshot) {
        final ids = snapshot.data?.docs.map((doc) => doc.id).toSet() ?? <String>{};
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(spacing: 6, runSpacing: 4, children: [
            for (final time in times)
              Builder(builder: (context) {
                final done = ids.contains(FirestoreService.logId(medId, DateTime.now(), time));
                return ActionChip(
                  avatar: Icon(done ? Icons.check_circle : Icons.check_circle_outline,
                    color: done ? Colors.green : _blue, size: 18),
                  label: Text(done ? '$time · Selesai' : '$time · Sudah diminum'),
                  onPressed: done || !snapshot.hasData ? null : () async {
                    try {
                      await FirestoreService.markTaken(medId, medication, time);
                    } catch (e) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Gagal mencatat konsumsi: $e')));
                    }
                  },
                );
              }),
          ]),
        );
      },
    );
  }
}
