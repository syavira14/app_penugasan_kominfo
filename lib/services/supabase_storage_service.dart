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

    final token = await user.getIdTokenResult(false);

    final role = token.claims?['role'];

    if (role != 'authenticated') {
      // Jangan memblokir di sini: biarkan Supabase yang memutuskan lewat
      // policy bucket, lalu tampilkan pesan yang jelas bila ditolak.
      debugPrint(
        'PERINGATAN: Firebase token tidak memiliki claim role=authenticated.',
      );
    }

    return user;
  }

  /// Ringkasan isi token Firebase (tanpa data rahasia) untuk diagnosis izin.
  Future<String> _ringkasToken() async {
    try {
      final r = await _auth.currentUser?.getIdTokenResult();
      final c = r?.claims ?? const <String, dynamic>{};
      return 'role=${c['role']}, aud=${c['aud']}, iss=${c['iss']}, '
          'sub=${c['sub'] ?? c['user_id']}';
    } catch (e) {
      return 'token tidak terbaca: $e';
    }
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
        throw FormatException(
          'Format file .$ext belum didukung. Gunakan PDF, JPG, PNG, atau DOCX.',
        );
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
    String? filePathUpload;
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
      filePathUpload = filePath;

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
            fileOptions: FileOptions(
              contentType: mimeTypeDariNama(namaFile),
              upsert: false,
            ),
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

      // Simpan di cache memori agar langsung bisa dilihat tanpa unduh ulang.
      StaffAdminApi.cacheMemoryBytes(cleanUploadedPath, bytes);

      // 8. Kembalikan informasi file.
      return HasilUploadTugas(path: cleanUploadedPath, namaFile: namaFile);
    } on StorageException catch (e) {
      debugPrint('Supabase Storage error: $e');

      final denied =
          e.statusCode == '401' ||
          e.statusCode == '403' ||
          e.message.toLowerCase().contains('row-level security');
      if (denied && filePathUpload != null) {
        // Cadangan: unggah lewat sesi Admin latar belakang (sudah tersedia di
        // StaffAdminApi) bila policy Supabase menolak token staf.
        final viaAdmin = await StaffAdminApi.uploadSupabaseViaAdmin(
          filePath: filePathUpload,
          bytes: bytes,
          contentType: mimeTypeDariNama(namaFile),
        );
        if (viaAdmin != null && viaAdmin.isNotEmpty) {
          StaffAdminApi.cacheMemoryBytes(viaAdmin, bytes);
          return HasilUploadTugas(path: viaAdmin, namaFile: namaFile);
        }
      }
      if (denied) {
        final info = await _ringkasToken();
        throw Exception(
          'Izin unggah ditolak Supabase (${e.statusCode}).\n'
          'Detail server: ${e.message}\n'
          'Path: $filePathUpload\n'
          'Token Firebase: $info\n'
          'Syarat: role harus "authenticated", dan policy bucket file-tugas '
          'harus mengizinkan folder uid staf.',
        );
      }

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

  /// Akses file laporan melalui Edge Function setelah verifikasi Firebase token.
  Future<String> ambilLinkSolusi(String laporanId) async =>
      _ambilLinkFileAman(kind: 'solusi', laporanId: laporanId);

  Future<String> ambilLinkRiwayat(
    String penugasanId,
    String submissionId,
  ) async => _ambilLinkFileAman(
    kind: 'riwayat',
    assignmentId: penugasanId,
    submissionId: submissionId,
  );

  Future<String> ambilLinkPenghentian(String penugasanId) async =>
      _ambilLinkFileAman(kind: 'penghentian', assignmentId: penugasanId);

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

  /// Mengambil signed URL bukti laporan kendala
  /// melalui Supabase Edge Function.
  ///
  /// Admin dapat melihat semua laporan.
  /// Staff hanya dapat melihat laporan miliknya.
  Future<String> ambilLinkBuktiKendala(String laporanId) async {
    try {
      final id = laporanId.trim();

      if (id.isEmpty) {
        throw Exception('ID laporan kendala tidak boleh kosong.');
      }

      // 1. Pastikan pengguna login ke Firebase.
      final user = _auth.currentUser;

      if (user == null) {
        throw Exception('Sesi login tidak ditemukan. Silakan login kembali.');
      }

      // 2. Ambil Firebase ID Token terbaru.
      final firebaseToken = await user.getIdToken();

      if (firebaseToken == null || firebaseToken.isEmpty) {
        throw Exception('Gagal mendapatkan token Firebase.');
      }

      // 3. Endpoint Supabase Edge Function.
      final endpoint = Uri.parse(
        'https://uxdloenucntsmcviskfo.supabase.co'
        '/functions/v1/get-assignment-file-url',
      );

      // 4. Kirim permintaan untuk bukti kendala.
      final response = await http
          .post(
            endpoint,
            headers: {
              'Authorization': 'Bearer $firebaseToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'kind': 'kendala', 'laporanId': id}),
          )
          .timeout(const Duration(seconds: 30));

      // 5. Baca respons Edge Function.
      final dynamic decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw Exception('Format respons server tidak valid.');
      }

      if (response.statusCode != 200) {
        final pesan =
            decoded['error']?.toString() ?? 'Gagal mengakses bukti laporan.';

        throw Exception('$pesan (HTTP ${response.statusCode})');
      }

      // 6. Ambil signed URL.
      final signedUrl = decoded['url']?.toString() ?? '';

      if (signedUrl.isEmpty) {
        throw Exception('Link bukti laporan tidak ditemukan.');
      }

      final uri = Uri.tryParse(signedUrl);

      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host != 'uxdloenucntsmcviskfo.supabase.co' ||
          !uri.path.startsWith('/storage/v1/object/sign/file-tugas/')) {
        throw Exception('Link file dari server tidak valid.');
      }

      debugPrint('Signed URL bukti kendala berhasil diperoleh.');

      return signedUrl;
    } on TimeoutException {
      throw Exception('Permintaan terlalu lama. Periksa koneksi internet.');
    } on FormatException {
      throw Exception('Respons Edge Function bukan JSON yang valid.');
    } catch (e) {
      debugPrint('Gagal membuka bukti kendala: $e');
      rethrow;
    }
  }
}
