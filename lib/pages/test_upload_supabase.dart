
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/supabase_storage_service.dart';

class TestUploadSupabase extends StatefulWidget {
  const TestUploadSupabase({super.key});

  @override
  State<TestUploadSupabase> createState() =>
      _TestUploadSupabaseState();
}

class _TestUploadSupabaseState
    extends State<TestUploadSupabase> {
  final SupabaseStorageService _storage =
      SupabaseStorageService();

  bool _loading = false;
  String _message = 'Belum ada file yang diunggah.';
  String _fileName = '';
  String _uploadedPath = '';

  // Menentukan MIME type berdasarkan ekstensi file
  String _mimeType(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';

      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';

      case 'png':
        return 'image/png';

      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

      default:
        throw Exception(
          'Jenis file tidak didukung. '
          'Gunakan PDF, JPG, PNG, atau DOCX.',
        );
    }
  }

  // Fungsi untuk memilih dan mengunggah file
  Future<void> _uploadFile() async {
    if (_loading) return;

    try {
      // Pastikan pengguna sudah login ke Firebase
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception(
          'Pengguna belum login. Silakan login terlebih dahulu.',
        );
      }

      // Pilih file menggunakan file_picker 13.1.0
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'jpg',
          'jpeg',
          'png',
          'docx',
        ],
      );

      // Jika pengguna membatalkan pemilihan
      if (file == null) return;

      setState(() {
        _loading = true;
        _fileName = file.name;
        _uploadedPath = '';
        _message = 'Membaca file...';
      });

      // Baca file menjadi bytes
      final bytes = await file.readAsBytes();

      if (bytes.isEmpty) {
        throw Exception('File kosong atau gagal dibaca.');
      }

      // Validasi ukuran maksimal 10 MB
      const maxSize = 10 * 1024 * 1024;

      if (bytes.length > maxSize) {
        throw Exception(
          'Ukuran file terlalu besar. Maksimal 10 MB.',
        );
      }

      if (!mounted) return;

      setState(() {
        _message = 'Mengunggah file ke Supabase...';
      });

      // Upload file ke Supabase Storage
      final uploaded = await _storage.uploadHasilTugas(
        tugasId: 'uji-upload',
        namaFile: file.name,
        bytes: bytes,
        contentType: _mimeType(file.extension ?? ''),
      );

      if (!mounted) return;

      setState(() {
        _uploadedPath = uploaded.path;
        _message = 'Upload berhasil!';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'File berhasil diunggah ke Supabase Storage.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _message = 'Upload gagal:\n$e';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload gagal: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),

      appBar: AppBar(
        title: const Text('Test Upload Supabase'),
        backgroundColor: const Color(0xFF0011CC),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),

      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 500,
            ),
            child: Card(
              elevation: 3,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.cloud_upload_rounded,
                      size: 70,
                      color: Color(0xFF0011CC),
                    ),

                    const SizedBox(height: 16),

                    const Text(
                      'Pengujian Upload File',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      'Upload file PDF, Word, atau gambar '
                      'ke Supabase Storage.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Informasi akun Firebase
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F3FF),
                        borderRadius:
                            BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Akun Firebase',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            user?.email ?? 'Belum login',
                          ),
                          const SizedBox(height: 4),
                          SelectableText(
                            'UID: ${user?.uid ?? '-'}',
                            style: const TextStyle(
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Tombol upload
                    ElevatedButton.icon(
                      onPressed:
                          _loading ? null : _uploadFile,
                      icon: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.upload_file,
                            ),
                      label: Text(
                        _loading
                            ? 'Mengunggah...'
                            : 'Pilih & Upload File',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color(0xFF0011CC),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Status upload
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _uploadedPath.isNotEmpty
                            ? const Color(0xFFE8F5E9)
                            : const Color(0xFFF5F5F5),
                        borderRadius:
                            BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Status Upload',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 8),

                          Text(_message),

                          if (_fileName.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              'Nama file: $_fileName',
                            ),
                          ],

                          if (_uploadedPath.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            const Text(
                              'Path Supabase:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            SelectableText(
                              _uploadedPath,
                              style: const TextStyle(
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
