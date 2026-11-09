import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'staff_admin_api.dart';

/// Melengkapi field `staff_ids` dan `riwayat_kendala_cache` pada dokumen `tugas`.
///
/// Rules Firestore hanya mengizinkan staff membaca dokumen `tugas` bila
/// uid-nya ada di `staff_ids`, serta membatasi pembacaan `laporan_kendala`
/// pada `pelapor_id == request.auth.uid` (yang dapat berubah jika akun staf
/// pernah di-reset password-nya ke UID baru). Fungsi ini dijalankan oleh Admin
/// dan aman dipanggil berulang.
Future<void> backfillStaffIds() async {
  final db = FirebaseFirestore.instance;
  try {
    final tugas = await db.collection('tugas').get();
    final missing = tugas.docs.where((d) {
      final v = d.data()['staff_ids'];
      return v is! List || v.isEmpty;
    }).toList();

    if (missing.isNotEmpty) {
      final penugasan = await db.collection('penugasan').get();
      final byTask = <String, Set<String>>{};
      for (final p in penugasan.docs) {
        final data = p.data();
        final tid = (data['tugas_id'] ?? '').toString();
        final sid = (data['staff_id'] ?? '').toString();
        if (tid.isEmpty || sid.isEmpty) continue;
        (byTask[tid] ??= <String>{}).add(sid);
      }

      for (final d in missing) {
        final ids = byTask[d.id];
        if (ids == null || ids.isEmpty) continue;
        try {
          await d.reference.update({'staff_ids': ids.toList()..sort()});
        } catch (e) {
          debugPrint('[backfill] gagal update tugas/${d.id}: $e');
        }
      }
    }

    // Sinkronkan juga cache riwayat kendala ke dokumen tugas agar riwayat_tugas
    // milik Staff selalu menampilkan riwayat kendala yang sama persis dengan Admin.
    await StaffAdminApi.syncKendalaCacheForAllTasks(db);
  } catch (e) {
    debugPrint('[backfill] gagal: $e');
  }
}
