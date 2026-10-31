
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart'
    as firebase_auth;
import 'package:supabase_flutter/supabase_flutter.dart';

class FilePreviewService {
  final SupabaseClient _supabase =
      Supabase.instance.client;

  static const String bucket = 'file-tugas';

  String normalisasiPath(String path) {
    var hasil = path.trim();

    while (hasil.startsWith('/')) {
      hasil = hasil.substring(1);
    }

    if (hasil.startsWith('$bucket/')) {
      hasil = hasil.substring(bucket.length + 1);
    }

    return hasil;
  }

  Future<Uint8List> downloadFileStaff(
    String path,
  ) async {
    final user =
        firebase_auth.FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('Silakan login terlebih dahulu.');
    }

    final cleanPath = normalisasiPath(path);

    if (cleanPath.isEmpty) {
      throw Exception('Path file kosong.');
    }

    // Hanya file di folder milik staff sendiri.
    if (!cleanPath.startsWith('${user.uid}/')) {
      throw Exception(
        'Anda tidak memiliki akses ke file ini.',
      );
    }

    // RLS Supabase tetap menjadi pengaman utama.
    return await _supabase.storage
        .from(bucket)
        .download(cleanPath);
  }
}
