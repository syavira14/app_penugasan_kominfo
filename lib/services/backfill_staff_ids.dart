import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Melengkapi field `staff_ids` pada dokumen `tugas` lama.
///
/// Rules Firestore hanya mengizinkan staff membaca dokumen `tugas` bila
/// uid-nya ada di `staff_ids`. Tugas yang dibuat sebelum aturan itu ada
/// belum punya field tersebut, sehingga staff mendapat permission-denied.
/// Fungsi ini hanya boleh dijalankan oleh admin dan aman dipanggil berulang
/// (hanya menyentuh tugas yang `staff_ids`-nya kosong/tidak ada).
Future<void> backfillStaffIds() async {
  final db = FirebaseFirestore.instance;
  try {
    final tugas = await db.collection('tugas').get();
    final missing = tugas.docs.where((d) {
      final v = d.data()['staff_ids'];
      return v is! List || v.isEmpty;
    }).toList();
    if (missing.isEmpty) return;

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
  } catch (e) {
    debugPrint('[backfill] gagal: $e');
  }
}
