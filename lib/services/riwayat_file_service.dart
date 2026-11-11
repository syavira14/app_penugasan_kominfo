import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_storage_service.dart';

final Map<String, Uint8List> _riwayatBytesCache = {};
final Map<String, String> _riwayatUrlCache = {};

/// Membersihkan dan menormalisasi path file di Supabase bucket 'file-tugas'
String _cleanPath(String path) {
  var clean = path.trim().replaceAll('\\', '/');
  while (clean.startsWith('/')) {
    clean = clean.substring(1);
  }
  if (clean.startsWith('file-tugas/')) {
    clean = clean.substring('file-tugas/'.length);
  }
  while (clean.startsWith('/')) {
    clean = clean.substring(1);
  }
  return clean;
}

/// Meminta URL bertanda tangan (signed URL) untuk file hasil pekerjaan.
/// Mendukung fallback bertingkat: Edge Function 'hasil', 'riwayat',
/// Supabase Client SDK, Firestore URL, dan Public bucket.
Future<String> ambilUrlFileHasil(
  String assignmentId, {
  String path = '',
  String? fallbackUrl,
}) async {
  final clean = _cleanPath(path);
  final cacheKey = '$assignmentId|$clean';
  if (_riwayatUrlCache.containsKey(cacheKey)) {
    return _riwayatUrlCache[cacheKey]!;
  }

  final rawFallback = (fallbackUrl ?? '').trim();
  if (rawFallback.startsWith('http') || rawFallback.startsWith('data:')) {
    _riwayatUrlCache[cacheKey] = rawFallback;
    return rawFallback;
  }

  final user = FirebaseAuth.instance.currentUser;
  final token = user != null ? await user.getIdToken() : null;

  // 1. Coba panggil Edge Function get-assignment-file-url dengan kind: 'hasil'
  if (token != null && token.isNotEmpty && assignmentId.trim().isNotEmpty) {
    try {
      final res = await http
          .post(
            Uri.parse(
              'https://uxdloenucntsmcviskfo.supabase.co/functions/v1/get-assignment-file-url',
            ),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'assignmentId': assignmentId.trim(),
              'kind': 'hasil',
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map && decoded['url'] != null) {
          final u = decoded['url'].toString();
          if (u.isNotEmpty) {
            _riwayatUrlCache[cacheKey] = u;
            return u;
          }
        }
      }
    } catch (_) {}
  }

  // 2. Coba via subkoleksi riwayat_pengumpulan dengan kind: 'riwayat'
  // (Edge Function memberikan izin bagi staff pemilik penugasan untuk kind: 'riwayat')
  if (token != null && token.isNotEmpty && assignmentId.trim().isNotEmpty) {
    try {
      final subSnap = await FirebaseFirestore.instance
          .collection('penugasan')
          .doc(assignmentId.trim())
          .collection('riwayat_pengumpulan')
          .get();

      if (subSnap.docs.isNotEmpty) {
        final docs = subSnap.docs.toList()
          ..sort((a, b) {
            final ta = a.data()['created_at'];
            final tb = b.data()['created_at'];
            final msA = ta is Timestamp ? ta.millisecondsSinceEpoch : 0;
            final msB = tb is Timestamp ? tb.millisecondsSinceEpoch : 0;
            return msB.compareTo(msA);
          });

        for (final doc in docs) {
          final directUrl = (doc.data()['file_url'] ?? '').toString().trim();
          if (directUrl.startsWith('http') || directUrl.startsWith('data:')) {
            _riwayatUrlCache[cacheKey] = directUrl;
            return directUrl;
          }

          final res = await http
              .post(
                Uri.parse(
                  'https://uxdloenucntsmcviskfo.supabase.co/functions/v1/get-assignment-file-url',
                ),
                headers: {
                  'Authorization': 'Bearer $token',
                  'Content-Type': 'application/json',
                },
                body: jsonEncode({
                  'assignmentId': assignmentId.trim(),
                  'submissionId': doc.id,
                  'kind': 'riwayat',
                }),
              )
              .timeout(const Duration(seconds: 10));

          if (res.statusCode == 200) {
            final decoded = jsonDecode(res.body);
            if (decoded is Map && decoded['url'] != null) {
              final u = decoded['url'].toString();
              if (u.isNotEmpty) {
                _riwayatUrlCache[cacheKey] = u;
                return u;
              }
            }
          }
        }
      }
    } catch (_) {}
  }

  // 3. Coba buat signed URL langsung lewat SDK Supabase client
  if (clean.isNotEmpty) {
    try {
      final signed = await Supabase.instance.client.storage
          .from(SupabaseStorageService.bucket)
          .createSignedUrl(clean, 3600);
      if (signed.isNotEmpty) {
        _riwayatUrlCache[cacheKey] = signed;
        return signed;
      }
    } catch (_) {}
  }

  // 4. Coba ambil dari dokumen penugasan langsung di Firestore
  if (assignmentId.trim().isNotEmpty) {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('penugasan')
          .doc(assignmentId.trim())
          .get();
      final data = doc.data();
      if (data != null) {
        final u = (data['file_hasil_url'] ?? '').toString().trim();
        if (u.startsWith('http') || u.startsWith('data:')) {
          _riwayatUrlCache[cacheKey] = u;
          return u;
        }
        final p = _cleanPath((data['file_hasil_path'] ?? '').toString());
        if (p.isNotEmpty && p != clean) {
          return ambilUrlFileHasil(assignmentId, path: p);
        }
      }
    } catch (_) {}
  }

  // 5. Coba link publik Supabase
  if (clean.isNotEmpty) {
    final publicUrl =
        'https://uxdloenucntsmcviskfo.supabase.co/storage/v1/object/public/${SupabaseStorageService.bucket}/$clean';
    try {
      final testRes = await http.head(Uri.parse(publicUrl));
      if (testRes.statusCode == 200) {
        _riwayatUrlCache[cacheKey] = publicUrl;
        return publicUrl;
      }
    } catch (_) {}
  }

  throw StateError('File lampiran tidak ditemukan atau belum tersedia.');
}

/// Mengambil isi bytes file penugasan untuk preview in-app atau download langsung.
Future<Uint8List> ambilBytesFileHasil(
  String assignmentId, {
  String path = '',
  String? url,
}) async {
  final clean = _cleanPath(path);
  final cacheKey = '$assignmentId|$clean';
  if (_riwayatBytesCache.containsKey(cacheKey)) {
    return _riwayatBytesCache[cacheKey]!;
  }

  // 1. Jika URL bertipe data: (Base64)
  final rawUrl = (url ?? '').trim();
  if (rawUrl.startsWith('data:')) {
    final comma = rawUrl.indexOf(',');
    if (comma > 0) {
      final b64 = rawUrl.substring(comma + 1).replaceAll(RegExp(r'\s'), '');
      final bytes = base64Decode(b64);
      _riwayatBytesCache[cacheKey] = bytes;
      return bytes;
    }
  }

  // 2. Coba unduh via SDK Supabase client langsung
  if (clean.isNotEmpty) {
    try {
      final data = await Supabase.instance.client.storage
          .from(SupabaseStorageService.bucket)
          .download(clean)
          .timeout(const Duration(seconds: 15));
      if (data.isNotEmpty) {
        _riwayatBytesCache[cacheKey] = data;
        return data;
      }
    } catch (_) {}
  }

  // 3. Dapatkan signed URL dan unduh via http
  String resolvedUrl = rawUrl;
  if (!resolvedUrl.startsWith('http')) {
    resolvedUrl = await ambilUrlFileHasil(
      assignmentId,
      path: clean,
      fallbackUrl: rawUrl,
    );
  }

  if (resolvedUrl.startsWith('http')) {
    final res = await http
        .get(Uri.parse(resolvedUrl))
        .timeout(const Duration(seconds: 30));
    if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
      _riwayatBytesCache[cacheKey] = res.bodyBytes;
      return res.bodyBytes;
    }
  }

  throw StateError('Gagal mengunduh isi file lampiran.');
}
