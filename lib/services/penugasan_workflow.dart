import 'package:cloud_firestore/cloud_firestore.dart';

bool canTransitionAssignment(String from, String to) {
  return switch (from) {
    'pending' => to == 'berlangsung',
    'berlangsung' => to == 'dikumpulkan'|| to == 'terkendala',
    'revisi' => to == 'dikumpulkan',
    'dikumpulkan' => to == 'revisi' || to == 'disetujui',
    'terkendala' => to == 'berlangsung',
    _ => false,
  };
}

String assignmentGroupStatus(Iterable<String> statuses) {
  final values = statuses.toList();
  if (values.isEmpty) return 'pending';
  if (values.every((status) => status == 'disetujui')) return 'disetujui';
  for (final status in ['revisi', 'dikumpulkan', 'berlangsung', 'terkendala']) {
    if (values.contains(status)) return status;
  }
  return 'pending';
}

/// Memeriksa status terbaru di transaksi agar hasil yang sudah dikirim atau
/// disetujui tidak tertimpa aksi dari halaman yang belum menerima pembaruan.
Future<void> transitionAssignment(
  FirebaseFirestore firestore,
  String id,
  String status, {
  Map<String, dynamic> data = const {},
}) async {
  final ref = firestore.collection('penugasan').doc(id);
  await firestore.runTransaction((transaction) async {
    final snapshot = await transaction.get(ref);
    if (!snapshot.exists) throw StateError('Penugasan tidak ditemukan.');
    final current = (snapshot.data()?['status'] ?? 'pending').toString();
    if (!canTransitionAssignment(current, status)) {
      throw StateError('Status tugas sudah berubah. Silakan periksa kembali.');
    }
    transaction.update(ref, {
      ...data,
      'status': status,
      'updated_at': FieldValue.serverTimestamp(),
      if (status == 'dikumpulkan')
        'tanggal_dikumpulkan': FieldValue.serverTimestamp(),
      if (status == 'disetujui')
        'tanggal_disetujui': FieldValue.serverTimestamp(),
    });
  });
}
