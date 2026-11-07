import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'supabase_storage_service.dart';

/// Meminta URL sementara (signed URL) untuk file hasil pekerjaan.
/// Cara yang sama dengan halaman detail tugas admin (Edge Function Supabase);
/// jika gagal, dicoba lewat SupabaseStorageService.buatLinkSementara(path).
Future<String> ambilUrlFileHasil(
  String assignmentId, {
  String path = '',
}) async {
  Object? edgeError;
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Silakan login kembali.');
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError('Token Firebase tidak tersedia.');
    }
    final response = await http.post(
      Uri.parse(
        'https://uxdloenucntsmcviskfo.supabase.co/functions/v1/get-assignment-file-url',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'assignmentId': assignmentId, 'kind': 'hasil'}),
    );
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) throw StateError('Respons backend tidak valid.');
    final result = Map<String, dynamic>.from(decoded);
    if (response.statusCode != 200) {
      throw StateError(
        (result['error'] ?? result['message'] ?? 'HTTP ${response.statusCode}')
            .toString(),
      );
    }
    final url = (result['url'] ?? '').toString();
    if (url.isEmpty) throw StateError('Backend tidak mengirim URL file.');
    return url;
  } catch (e) {
    edgeError = e;
  }

  if (path.isNotEmpty) {
    try {
      return await SupabaseStorageService().buatLinkSementara(path);
    } catch (_) {}
  }
  throw StateError('$edgeError');
}
