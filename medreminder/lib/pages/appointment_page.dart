import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

const _blue = Color(0xFF2563EB);
const _pale = Color(0xFFF5F9FF);

class AppointmentPage extends StatelessWidget {
  const AppointmentPage({super.key});

  Future<void> _edit(BuildContext context, [QueryDocumentSnapshot<Map<String, dynamic>>? doc]) async {
    final data = await Navigator.push<Map<String, dynamic>>(context,
      MaterialPageRoute(builder: (_) => _AppointmentForm(existing: doc?.data())));
    if (data == null) return;
    try {
      if (doc == null) { await FirestoreService.appointments.add(data); }
      else { await doc.reference.update(data); }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan kontrol: $e')));
    }
  }
  Future<void> _delete(BuildContext context, QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final yes = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Hapus jadwal kontrol?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Hapus')),
      ],
    ));
    if (yes != true) return;
    try { await doc.reference.delete(); }
    catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Gagal menghapus kontrol: $e'))); }
  }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: _pale,
    body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreService.appointments.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Gagal membaca kontrol: ${snapshot.error}'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = [...snapshot.data!.docs]..sort((a, b) =>
          (a.data()['dateTime'] as Timestamp).compareTo(b.data()['dateTime'] as Timestamp));
        if (docs.isEmpty) return const Center(child: Padding(
          padding: EdgeInsets.all(24), child: Text('Belum ada jadwal kontrol. Tekan Tambah Kontrol.',
            textAlign: TextAlign.center)));
        return ListView(padding: const EdgeInsets.all(16), children: [
          const Padding(padding: EdgeInsets.only(bottom: 12), child: Text('Jadwal Kontrol',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22))),
          for (final doc in docs)
            Card(color: Colors.white, margin: const EdgeInsets.only(bottom: 12),
              child: Padding(padding: const EdgeInsets.all(10), child: Row(children: [
                const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.calendar_month, color: _blue)),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${doc.data()['clinic']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('${doc.data()['doctor']}'),
                  Builder(builder: (_) { final when = (doc.data()['dateTime'] as Timestamp).toDate();
                    return Text('${FirestoreService.formatDate(when)} · ${FirestoreService.formatTime(when)}',
                      style: const TextStyle(color: Colors.black54)); }),
                  if ('${doc.data()['notes'] ?? ''}'.isNotEmpty) Text('${doc.data()['notes']}'),
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
      heroTag: 'tambah_kontrol',
      onPressed: () => _edit(context),
      icon: const Icon(Icons.add),
      label: const Text('Tambah Kontrol'),
      backgroundColor: _blue,
      foregroundColor: Colors.white,
    ),
  );
}

class _AppointmentForm extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const _AppointmentForm({this.existing});
  @override State<_AppointmentForm> createState() => _AppointmentFormState();
}
class _AppointmentFormState extends State<_AppointmentForm> {
  final _form = GlobalKey<FormState>();
  final _clinic = TextEditingController();
  final _doctor = TextEditingController();
  final _notes = TextEditingController();
  late DateTime _date;
  late TimeOfDay _time;
  @override void initState() {
    super.initState();
    final data = widget.existing;
    _date = data == null ? DateTime.now() : (data['dateTime'] as Timestamp).toDate();
    _time = TimeOfDay.fromDateTime(_date);
    if (data != null) {
      _clinic.text = data['clinic'] ?? '';
      _doctor.text = data['doctor'] ?? '';
      _notes.text = data['notes'] ?? '';
    }
  }
  @override void dispose() { _clinic.dispose(); _doctor.dispose(); _notes.dispose(); super.dispose(); }

  Future<void> _pickDate() async {
    final date = await showDatePicker(context: context, initialDate: _date,
      firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (date != null) setState(() => _date = date);
  }
  Future<void> _pickTime() async {
    final time = await showTimePicker(context: context, initialTime: _time);
    if (time != null) setState(() => _time = time);
  }
  void _save() {
    if (!_form.currentState!.validate()) return;
    final when = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
    if (when.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Jadwal kontrol harus di masa mendatang.')));
      return;
    }
    Navigator.pop(context, {
      'clinic': _clinic.text.trim(), 'doctor': _doctor.text.trim(),
      'notes': _notes.text.trim(), 'dateTime': Timestamp.fromDate(when),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: _pale,
    appBar: AppBar(title: Text(widget.existing == null ? 'Tambah Kontrol' : 'Ubah Kontrol'), backgroundColor: _pale),
    body: Form(key: _form, child: ListView(padding: const EdgeInsets.all(20), children: [
      TextFormField(controller: _clinic, decoration: const InputDecoration(labelText: 'Poli (misalnya Poli Umum)'),
        validator: (v) => v == null || v.trim().isEmpty ? 'Nama poli wajib diisi' : null),
      const SizedBox(height: 14),
      TextFormField(controller: _doctor, decoration: const InputDecoration(labelText: 'Nama dokter'),
        validator: (v) => v == null || v.trim().isEmpty ? 'Nama dokter wajib diisi' : null),
      const SizedBox(height: 14),
      Card(child: Column(children: [
        ListTile(title: const Text('Tanggal kontrol'), subtitle: Text(FirestoreService.formatDate(_date)),
          trailing: const Icon(Icons.calendar_today), onTap: _pickDate),
        ListTile(title: const Text('Jam kontrol'), subtitle: Text(_time.format(context)),
          trailing: const Icon(Icons.access_time), onTap: _pickTime),
      ])),
      const SizedBox(height: 14),
      TextFormField(controller: _notes, maxLines: 2,
        decoration: const InputDecoration(labelText: 'Catatan (opsional)')),
      const SizedBox(height: 24),
      FilledButton(onPressed: _save, child: const Text('Simpan Kontrol')),
    ])),
  );
}
