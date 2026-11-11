import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'staff_admin_api.dart';

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
  String _normalisasiPath(String path) {
    String cleanPath = path.trim();

    while (cleanPath.startsWith('/')) {
      cleanPath = cleanPath.substring(1);
    }

    if (cleanPath.startsWith('$bucket/')) {
      cleanPath = cleanPath.substring(bucket.length + 1);
    }

    while (cleanPath.startsWith('/')) {
      cleanPath = cleanPath.substring(1);
    }

    return cleanPath;
  }

  /// Memeriksa apakah pengguna sudah login.
  Future<firebase_auth.User> _periksaPengguna() async {
    final firebase_auth.User? user = _auth.currentUser;

    if (user == null) {
      throw Exception('Sesi login tidak ditemukan. Silakan login kembali.');
    }

    final token = await user.getIdTokenResult(false);
    final role = token.claims?['role'];

    if (role != 'authenticated') {
      debugPrint(
        'PERINGATAN: Firebase token tidak memiliki claim role=authenticated.',
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

  /// MIME ditentukan dari nama file, bukan dari MIME generik browser.
  static String mimeTypeDariNama(String namaFile) {
    final ext = namaFile.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'doc':
        return 'application/msword';
      default:
        return 'application/octet-stream';
    }
  }

  /// Mengunggah file hasil pekerjaan, revisi, bukti penghentian, atau lampiran
  /// kendala/solusi ke bucket Supabase Storage dengan cadangan otomatis di Firestore.
  ///
  /// Struktur penyimpanan:
  /// UID_USER/ID_TUGAS/TIMESTAMP_NAMA_FILE
  Future<HasilUploadTugas> uploadHasilTugas({
    required String tugasId,
    required String namaFile,
    required Uint8List bytes,
    required String contentType,
  }) async {
    String? filePathUpload;
    final mime = mimeTypeDariNama(namaFile);
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

      // 3. Bersihkan nama file & ID tugas.
      final safeName = namaFile.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final safeTugasId = tugasId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

      // 4. Buat path file.
      final timestamp = DateTime.now().microsecondsSinceEpoch;
      final filePath = '${user.uid}/$safeTugasId/${timestamp}_$safeName';
      filePathUpload = _normalisasiPath(filePath);

      // Simpan langsung di cache memori dan cadangan Firestore agar selalu tersedia.
      StaffAdminApi.cacheMemoryBytes(filePathUpload, bytes);
      await StaffAdminApi.saveBackupFileToFirestore(
        filePath: filePathUpload,
        namaFile: namaFile,
        mime: mime,
        bytes: bytes,
        rawTugasOrTag: tugasId,
      );

      // 5. Upload file ke Supabase Storage.
      final uploadedPath = await _supabase.storage
          .from(bucket)
          .uploadBinary(
            filePath,
            bytes,
            fileOptions: FileOptions(contentType: mime, upsert: true),
          );

      final cleanUploadedPath = _normalisasiPath(uploadedPath);
      StaffAdminApi.cacheMemoryBytes(cleanUploadedPath, bytes);

      return HasilUploadTugas(path: cleanUploadedPath, namaFile: namaFile);
    } on StorageException catch (e) {
      debugPrint('Supabase Storage error: $e');

      if (filePathUpload != null && filePathUpload.isNotEmpty) {
        final viaAdmin = await StaffAdminApi.uploadSupabaseViaAdmin(
          filePath: filePathUpload,
          bytes: bytes,
          contentType: mime,
        );
        if (viaAdmin != null && viaAdmin.isNotEmpty) {
          StaffAdminApi.cacheMemoryBytes(viaAdmin, bytes);
          return HasilUploadTugas(path: viaAdmin, namaFile: namaFile);
        }

        // Jika policy bucket Supabase menolak token (401/403/RLS), tetap kembalikan
        // path bersih karena isi file sudah diamankan di cache memori & Firestore stored_files.
        await StaffAdminApi.saveBackupFileToFirestore(
          filePath: filePathUpload,
          namaFile: namaFile,
          mime: mime,
          bytes: bytes,
          rawTugasOrTag: tugasId,
        );
        return HasilUploadTugas(path: filePathUpload, namaFile: namaFile);
      }

      throw Exception('Gagal mengunggah file ke Supabase: ${e.message}');
    } catch (e) {
      debugPrint('Upload error: $e');
      if (filePathUpload != null && filePathUpload.isNotEmpty) {
        await StaffAdminApi.saveBackupFileToFirestore(
          filePath: filePathUpload,
          namaFile: namaFile,
          mime: mime,
          bytes: bytes,
          rawTugasOrTag: tugasId,
        );
        return HasilUploadTugas(path: filePathUpload, namaFile: namaFile);
      }
      rethrow;
    }
  }

  /// Membuat signed URL untuk membuka file yang disimpan di bucket private,
  /// dengan fallback otomatis ke cadangan Firestore / memori jika tidak ditemukan di bucket.
  Future<String> buatLinkSementara(String path) async {
    final cleanPath = _normalisasiPath(path);
    if (cleanPath.isEmpty) {
      throw Exception('Path file Supabase tidak ditemukan.');
    }

    try {
      await _periksaPengguna();
      final signedUrl = await _supabase.storage
          .from(bucket)
          .createSignedUrl(cleanPath, 3600);
      if (signedUrl.isNotEmpty) return signedUrl;
    } catch (e) {
      debugPrint(
        'Gagal membuat signed URL langsung, mencoba jalur cadangan: $e',
      );
    }

    return await StaffAdminApi.resolveSupabaseFileUrl(path: cleanPath);
  }

  /// Akses file laporan melalui Edge Function setelah verifikasi Firebase token,
  /// dengan fallback otomatis ke cadangan Firestore.
  Future<String> ambilLinkSolusi(String laporanId) async {
    try {
      return await _ambilLinkFileAman(kind: 'solusi', laporanId: laporanId);
    } catch (_) {
      return await StaffAdminApi.resolveSupabaseFileUrl(
        laporanId: laporanId,
        kind: 'solusi',
      );
    }
  }

  Future<String> ambilLinkRiwayat(
    String penugasanId,
    String submissionId,
  ) async {
    try {
      return await _ambilLinkFileAman(
        kind: 'riwayat',
        assignmentId: penugasanId,
        submissionId: submissionId,
      );
    } catch (_) {
      return await StaffAdminApi.resolveSupabaseFileUrl(
        assignmentId: penugasanId,
        submissionId: submissionId,
        kind: 'riwayat',
      );
    }
  }

  Future<String> ambilLinkPenghentian(String penugasanId) async {
    try {
      return await _ambilLinkFileAman(
        kind: 'penghentian',
        assignmentId: penugasanId,
      );
    } catch (_) {
      return await StaffAdminApi.resolveSupabaseFileUrl(
        assignmentId: penugasanId,
        kind: 'penghentian',
      );
    }
  }

  Future<String> _ambilLinkFileAman({
    required String kind,
    String? laporanId,
    String? assignmentId,
    String? submissionId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Sesi login tidak tersedia.');
    final token = await user.getIdToken();
    final response = await http.post(
      Uri.parse(
        'https://uxdloenucntsmcviskfo.supabase.co/functions/v1/get-assignment-file-url',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'kind': kind,
        if (laporanId != null) 'laporanId': laporanId,
        if (assignmentId != null) 'assignmentId': assignmentId,
        if (submissionId != null) 'submissionId': submissionId,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200 || data is! Map || data['url'] == null) {
      throw StateError(
        'Gagal mengakses file ($kind): ${data is Map ? data['error'] : response.statusCode}',
      );
    }
    return data['url'].toString();
  }

  /// Mengambil signed URL bukti laporan kendala melalui Supabase Edge Function,
  /// dengan fallback otomatis ke cadangan Firestore.
  Future<String> ambilLinkBuktiKendala(String laporanId) async {
    final id = laporanId.trim();
    if (id.isEmpty) {
      throw Exception('ID laporan kendala tidak boleh kosong.');
    }

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('Sesi login tidak ditemukan. Silakan login kembali.');
      }

      final firebaseToken = await user.getIdToken();
      if (firebaseToken == null || firebaseToken.isEmpty) {
        throw Exception('Gagal mendapatkan token Firebase.');
      }

      final endpoint = Uri.parse(
        'https://uxdloenucntsmcviskfo.supabase.co'
        '/functions/v1/get-assignment-file-url',
      );

      final response = await http
          .post(
            endpoint,
            headers: {
              'Authorization': 'Bearer $firebaseToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'kind': 'kendala', 'laporanId': id}),
          )
          .timeout(const Duration(seconds: 20));

      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic> && response.statusCode == 200) {
        final signedUrl = decoded['url']?.toString() ?? '';
        if (signedUrl.isNotEmpty) {
          return signedUrl;
        }
      }
    } catch (e) {
      debugPrint('Edge Function bukti kendala gagal, mencoba cadangan: $e');
    }

    return await StaffAdminApi.resolveSupabaseFileUrl(
      laporanId: id,
      kind: 'kendala',
    );
  }
}
