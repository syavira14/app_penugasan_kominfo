import 'package:cloud_firestore/cloud_firestore.dart';

class TugasService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final String _collection = 'tugas';

  /// ============================================================
  /// MENGAMBIL SEMUA TUGAS
  /// ============================================================
  Future<List<Map<String, dynamic>>> getAllTugas() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .orderBy('tanggal_mulai_tugas')
          .get();

      return snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();
    } catch (e) {
      throw Exception('Gagal mengambil data tugas: $e');
    }
  }

  /// ============================================================
  /// MENGAMBIL TUGAS BERDASARKAN ID
  /// ============================================================
  Future<Map<String, dynamic>?> getTugasById(
    String tugasId,
  ) async {
    try {
      final doc = await _firestore
          .collection(_collection)
          .doc(tugasId)
          .get();

      if (!doc.exists) {
        return null;
      }

      return {
        'id': doc.id,
        ...doc.data()!,
      };
    } catch (e) {
      throw Exception('Gagal mengambil detail tugas: $e');
    }
  }

  /// ============================================================
  /// MENAMBAHKAN TUGAS BARU
  /// ============================================================
  Future<String> tambahTugas({
    required String judul,
    required String deskripsi,
    required String dibuatOleh,
    required Timestamp tanggalMulaiTugas,
    required Timestamp tanggalSelesaiTugas,
    required String tempatTugas,
    required double latitude,
    required double longitude,
    required String prioritas,
  }) async {
    try {
      final docRef = await _firestore
          .collection(_collection)
          .add({
        'judul': judul,
        'deskripsi': deskripsi,

        // UID admin yang membuat tugas
        'dibuat_oleh': dibuatOleh,

        // Waktu tugas
        'tanggal_tugas_diberikan':
            FieldValue.serverTimestamp(),

        'tanggal_mulai_tugas': tanggalMulaiTugas,
        'tanggal_selesai_tugas': tanggalSelesaiTugas,

        // Lokasi
        'tempat_tugas': tempatTugas,
        'latitude': latitude,
        'longitude': longitude,

        // Prioritas
        'prioritas': prioritas,

        // Waktu database
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      return docRef.id;
    } catch (e) {
      throw Exception('Gagal menambahkan tugas: $e');
    }
  }

  /// ============================================================
  /// MENGUBAH TUGAS
  /// ============================================================
  Future<void> updateTugas({
    required String tugasId,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(tugasId)
          .update({
        ...data,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Gagal mengubah tugas: $e');
    }
  }

  /// ============================================================
  /// MENGHAPUS TUGAS
  /// ============================================================
  Future<void> deleteTugas(String tugasId) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(tugasId)
          .delete();
    } catch (e) {
      throw Exception('Gagal menghapus tugas: $e');
    }
  }
}