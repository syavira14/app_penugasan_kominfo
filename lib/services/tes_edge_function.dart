
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class TesEdgeFunction {
  static Future<void> jalankan(String assignmentId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        print('ERROR: Pengguna belum login.');
        return;
      }

      // Ambil Firebase ID Token terbaru.
      final token = await user.getIdToken(true);

      final uri = Uri.parse(
        'https://uxdloenucntsmcviskfo.supabase.co'
        '/functions/v1/get-assignment-file-url',
      );

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'assignmentId': assignmentId,
          'kind': 'hasil',
        }),
      );

      print('STATUS: ${response.statusCode}');
      print('RESPONSE: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        print('BERHASIL mendapatkan signed URL.');
        print('URL tersedia: ${data['url'] != null}');
      } else {
        print('GAGAL mengakses file.');
      }
    } catch (e) {
      print('ERROR: $e');
    }
  }
}
