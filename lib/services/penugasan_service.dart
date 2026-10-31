import 'package:cloud_firestore/cloud_firestore.dart';
import 'penugasan_workflow.dart';

class PenugasanService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final String _collection = 'penugasan';

  /// ============================================================
  /// MENGAMBIL SEMUA PENUGASAN BERDASARKAN ID TUGAS
  /// ============================================================
  Stream<List<Map<String, dynamic>>> streamPenugasanByTugas(String tugasId) {
    return _firestore
        .collection(_collection)
        .where('tugas_id', isEqualTo: tugasId)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return {'id': doc.id, ...doc.data()};
          }).toList();
        });
  }

  /// ============================================================
  /// MENGAMBIL SATU PENUGASAN
  /// ============================================================
  Future<Map<String, dynamic>?> getPenugasanById(String penugasanId) async {
    try {
      final doc = await _firestore
          .collection(_collection)
          .doc(penugasanId)
          .get();

      if (!doc.exists) {
        return null;
      }

      return {'id': doc.id, ...doc.data()!};
    } catch (e) {
      throw Exception('Gagal mengambil data penugasan: $e');
    }
  }

  /// ============================================================
  /// MENGUBAH STATUS PENUGASAN
  ///
  /// Catatan:
  /// Admin TIDAK mengubah status pengerjaan secara bebas.
  /// Fungsi ini digunakan hanya untuk proses yang memang
  /// dilakukan oleh sistem/admin, seperti revisi dan persetujuan.
  /// ============================================================
  Future<void> updateStatus({
    required String penugasanId,
    required String status,
    String? catatanRevisi,
  }) async {
    try {
      final Map<String, dynamic> data = {
        'status': status,
        'updated_at': FieldValue.serverTimestamp(),
      };

      if (catatanRevisi != null) {
        data['catatan_revisi'] = catatanRevisi;
      }

      if (status == 'disetujui') {
        data['tanggal_disetujui'] = FieldValue.serverTimestamp();
      }

      await transitionAssignment(_firestore, penugasanId, status, data: data);
    } catch (e) {
      throw Exception('Gagal memperbarui status penugasan: $e');
    }
  }

  /// ============================================================
  /// ADMIN MEMINTA REVISI
  /// ============================================================
  Future<void> mintaRevisi({
    required String penugasanId,
    required String catatanRevisi,
  }) async {
    if (catatanRevisi.trim().isEmpty) {
      throw Exception('Catatan revisi tidak boleh kosong.');
    }

    await updateStatus(
      penugasanId: penugasanId,
      status: 'revisi',
      catatanRevisi: catatanRevisi.trim(),
    );
  }

  /// ============================================================
  /// ADMIN MENYETUJUI HASIL TUGAS
  /// ============================================================
  Future<void> setujuiTugas({required String penugasanId}) async {
    await updateStatus(penugasanId: penugasanId, status: 'disetujui');
  }
}
