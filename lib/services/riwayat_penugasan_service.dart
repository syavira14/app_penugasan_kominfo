import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Kemungkinan nama field pemberi tugas (uid atau nama) di dokumen tugas / penugasan.
const _atasanKeys = [
  'dibuat_oleh',
  'dibuat_oleh_uid',
  'atasan_uid',
  'atasan_id',
  'pemberi_tugas_uid',
  'pemberi_tugas_id',
  'created_by',
  'assigned_by',
  'pemberi_tugas',
  'diberikan_oleh',
  'atasan_nama',
  'atasan',
];

Stream<List<Map<String, dynamic>>> streamRiwayatPenugasan({String? staffId}) {
  final firestore = FirebaseFirestore.instance;
  Query<Map<String, dynamic>> query = firestore.collection('penugasan');
  if (staffId != null) query = query.where('staff_id', isEqualTo: staffId);
  return query.snapshots().asyncMap((snapshot) async {
    final tasks = <String, Map<String, dynamic>>{};
    final users = <String, Map<String, dynamic>>{};

    // Baca dokumen user; bila ditolak rules / gagal, kembalikan map kosong
    // supaya seluruh riwayat tidak ikut gagal.
    Future<Map<String, dynamic>> user(String id) async {
      if (id.isEmpty) return {};
      final cached = users[id];
      if (cached != null) return cached;
      try {
        final doc = await firestore.collection('users').doc(id).get();
        return users[id] = doc.data() ?? {};
      } catch (e) {
        debugPrint('[riwayat] gagal baca users/$id: $e');
        return users[id] = {};
      }
    }

    Future<Map<String, dynamic>> tugas(String id) async {
      final cached = tasks[id];
      if (cached != null) return cached;
      try {
        final doc = await firestore.collection('tugas').doc(id).get();
        return tasks[id] = doc.data() ?? {};
      } catch (e) {
        debugPrint('[riwayat] gagal baca tugas/$id: $e');
        return tasks[id] = {};
      }
    }

    // Cari nama pemberi tugas: coba semua kemungkinan field, cocokkan ke users.
    Future<String> namaAtasan(
      Map<String, dynamic> task,
      Map<String, dynamic> assignment,
    ) async {
      for (final src in [task, assignment]) {
        for (final k in _atasanKeys) {
          final raw = (src[k] ?? '').toString().trim();
          if (raw.isEmpty) continue;
          final u = await user(raw);
          final nama = (u['nama'] ?? '').toString().trim();
          if (nama.isNotEmpty) return nama;
          // Kalau nilainya sudah berupa nama (ada spasi), pakai apa adanya.
          if (raw.contains(' ')) return raw;
        }
      }
      return 'Atasan';
    }

    final result = <Map<String, dynamic>>[];
    for (final doc in snapshot.docs) {
      final assignment = doc.data();
      if (assignment['status'] != 'disetujui') continue;
      final taskId = (assignment['tugas_id'] ?? '').toString();
      if (taskId.isEmpty) continue;
      final task = await tugas(taskId);

      result.add({
        ...task,
        ...assignment,
        'id': doc.id,
        'nama_staff': assignment['staff_nama'] ?? 'Staf tidak ditemukan',
        'nama_atasan': await namaAtasan(task, assignment),
        // Pastikan tanggal dari dokumen tugas tidak tertimpa field penugasan.
        'tanggal_mulai_tugas':
            task['tanggal_mulai_tugas'] ??
            task['tanggal_tugas_diberikan'] ??
            assignment['tanggal_mulai_tugas'] ??
            assignment['tanggal_tugas_diberikan'],
        'tanggal_selesai_tugas':
            task['tanggal_selesai_tugas'] ??
            assignment['tanggal_selesai_tugas'],
      });
    }
    result.sort((a, b) {
      final left = a['tanggal_disetujui'] ?? a['updated_at'];
      final right = b['tanggal_disetujui'] ?? b['updated_at'];
      return (right is Timestamp ? right.millisecondsSinceEpoch : 0).compareTo(
        left is Timestamp ? left.millisecondsSinceEpoch : 0,
      );
    });
    return result;
  });
}
