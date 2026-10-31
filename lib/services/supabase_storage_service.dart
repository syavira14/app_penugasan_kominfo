import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Model hasil upload file ke Supabase Storage.
class HasilUploadTugas {
  final String path;
  final String namaFile;

  const HasilUploadTugas({required this.path, required this.namaFile});
}

/// Service untuk mengelola file menggunakan Supabase Storage.
///
/// Firebase tetap digunakan untuk autentikasi pengguna,
/// sedangkan Supabase digunakan untuk menyimpan file.
class SupabaseStorageService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;

  /// Nama bucket Supabase Storage.
  static const String bucket = 'file-tugas';

  /// Maksimal ukuran file: 10 MB.
  static const int maxFileSize = 10 * 1024 * 1024;

  /// Membersihkan path agar relatif terhadap bucket.
  ///
  /// Contoh:
  /// file-tugas/UID/tugas/laporan.pdf
  ///
  /// Menjadi:
  /// UID/tugas/laporan.pdf
  String _normalisasiPath(String path) {
    String cleanPath = path.trim();

    // Hapus slash di awal.
    while (cleanPath.startsWith('/')) {
      cleanPath = cleanPath.substring(1);
    }

    // Hapus nama bucket jika ada.
    if (cleanPath.startsWith('$bucket/')) {
      cleanPath = cleanPath.substring(bucket.length + 1);
    }

    // Pastikan tidak ada slash di awal.
    while (cleanPath.startsWith('/')) {
      cleanPath = cleanPath.substring(1);
    }

    return cleanPath;
  }

  /// Memeriksa apakah pengguna sudah login dan
  /// memiliki Firebase JWT yang sesuai untuk Supabase.
  Future<firebase_auth.User> _periksaPengguna() async {
    final firebase_auth.User? user = _auth.currentUser;

    if (user == null) {
      throw Exception('Sesi login tidak ditemukan. Silakan login kembali.');
    }

    final token = await user.getIdTokenResult(true);

    final role = token.claims?['role'];

    if (role != 'authenticated') {
      throw Exception(
        'Akun belum memiliki izin untuk mengakses '
        'Supabase Storage. Hubungi administrator.',
      );
    }

    return user;
  }

  /// Memeriksa ukuran dan isi file.
  void _validasiFile(Uint8List bytes) {
    if (bytes.isEmpty) {
      throw Exception('File kosong. Silakan pilih file yang valid.');
    }

    if (bytes.length > maxFileSize) {
      throw Exception('Ukuran file maksimal 10 MB.');
    }
  }

  /// Mengunggah file hasil pekerjaan atau lampiran
  /// kendala ke bucket Supabase Storage.
  ///
  /// Struktur penyimpanan:
  /// UID_USER/ID_TUGAS/TIMESTAMP_NAMA_FILE
  Future<HasilUploadTugas> uploadHasilTugas({
    required String tugasId,
    required String namaFile,
    required Uint8List bytes,
    required String contentType,
  }) async {
    try {
      // 1. Periksa autentikasi.
      final user = await _periksaPengguna();

      // 2. Validasi file.
      _validasiFile(bytes);

      if (tugasId.trim().isEmpty) {
        throw Exception('ID tugas tidak boleh kosong.');
      }

      if (namaFile.trim().isEmpty) {
        throw Exception('Nama file tidak boleh kosong.');
      }

      // 3. Bersihkan nama file.
      final safeName = namaFile.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

      // 4. Bersihkan ID tugas agar aman digunakan
      // sebagai nama folder.
      final safeTugasId = tugasId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

      // 5. Buat path file.
      final timestamp = DateTime.now().microsecondsSinceEpoch;

      final filePath = '${user.uid}/$safeTugasId/${timestamp}_$safeName';

      debugPrint('========== UPLOAD SUPABASE ==========');
      debugPrint('Bucket: $bucket');
      debugPrint('UID: ${user.uid}');
      debugPrint('Nama file: $namaFile');
      debugPrint('Path upload: $filePath');
      debugPrint('Ukuran: ${bytes.length} bytes');
      debugPrint('Content-Type: $contentType');

      // 6. Upload file ke Supabase Storage.
      final uploadedPath = await _supabase.storage
          .from(bucket)
          .uploadBinary(
            filePath,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: false),
          );

      // 7. Normalisasi path hasil upload.
      //
      // Beberapa respons dapat menyertakan
      // nama bucket pada path yang dikembalikan.
      final cleanUploadedPath = _normalisasiPath(uploadedPath);

      debugPrint('Upload berhasil');
      debugPrint('Path hasil: $uploadedPath');
      debugPrint('Path bersih: $cleanUploadedPath');
      debugPrint('=====================================');

      // 8. Kembalikan informasi file.
      return HasilUploadTugas(path: cleanUploadedPath, namaFile: namaFile);
    } on StorageException catch (e) {
      debugPrint('Supabase Storage error: $e');

      throw Exception(
        'Gagal mengunggah file ke Supabase: '
        '${e.message}',
      );
    } catch (e) {
      debugPrint('Upload error: $e');
      rethrow;
    }
  }

  /// Membuat signed URL untuk membuka file
  /// yang disimpan di bucket private.
  ///
  /// Berlaku selama 1 jam.
  Future<String> buatLinkSementara(String path) async {
    try {
      // 1. Periksa apakah pengguna login.
      await _periksaPengguna();

      // 2. Bersihkan path dari nama bucket.
      final cleanPath = _normalisasiPath(path);

      if (cleanPath.isEmpty) {
        throw Exception('Path file Supabase tidak ditemukan.');
      }

      debugPrint('========== BUKA FILE SUPABASE ==========');
      debugPrint('Bucket: $bucket');
      debugPrint('Path asli: $path');
      debugPrint('Path bersih: $cleanPath');

      // 3. Buat signed URL untuk file private.
      final signedUrl = await _supabase.storage
          .from(bucket)
          .createSignedUrl(cleanPath, 3600);

      debugPrint('Signed URL berhasil dibuat');
      debugPrint('========================================');

      return signedUrl;
    } on StorageException catch (e) {
      debugPrint('Supabase Storage error: $e');

      if (e.statusCode == '404') {
        throw Exception(
          'File tidak ditemukan di Supabase Storage. '
          'Periksa path file pada Firestore.',
        );
      }

      throw Exception('Gagal mengambil akses file: ${e.message}');
    } catch (e) {
      debugPrint('Gagal membuat signed URL: $e');
      rethrow;
    }
  }
}
