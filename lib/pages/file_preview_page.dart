import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';

class FilePreviewPage extends StatelessWidget {
  final String namaFile;
  final Uint8List bytes;
  final String? externalUrl;

  const FilePreviewPage({
    super.key,
    required this.namaFile,
    required this.bytes,
    this.externalUrl,
  });

  bool get _isPdf => namaFile.toLowerCase().endsWith('.pdf');

  bool get _isImage {
    final name = namaFile.toLowerCase();
    return name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.png');
  }

  Future<void> _bukaEksternal(BuildContext context) async {
    final url = externalUrl;

    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tautan eksternal tidak tersedia.')),
      );
      return;
    }

    try {
      final berhasil = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );

      if (!berhasil) {
        throw Exception('File tidak dapat dibuka.');
      }
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal membuka file: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    const biruTua = Color(0xFF1A1464);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      appBar: AppBar(
        backgroundColor: biruTua,
        foregroundColor: Colors.white,
        title: Text(
          namaFile,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          if (externalUrl != null)
            IconButton(
              tooltip: 'Buka di aplikasi lain',
              icon: const Icon(Icons.open_in_new),
              onPressed: () => _bukaEksternal(context),
            ),
        ],
      ),
      body: _buildPreview(context),
    );
  }

  Widget _buildPreview(BuildContext context) {
    if (_isPdf) {
      return SfPdfViewer.memory(
        bytes,
        canShowScrollHead: true,
        canShowPaginationDialog: true,
      );
    }

    if (_isImage) {
      return Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5,
          child: Image.memory(
            bytes,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Center(
                child: Text('Gambar tidak dapat ditampilkan.'),
              );
            },
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.description_outlined,
              size: 76,
              color: Color(0xFF1D5FA0),
            ),
            const SizedBox(height: 16),
            Text(
              namaFile,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Format ini belum mendukung preview internal. '
              'Silakan buka menggunakan aplikasi lain.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (externalUrl != null)
              ElevatedButton.icon(
                onPressed: () => _bukaEksternal(context),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Buka File'),
              ),
          ],
        ),
      ),
    );
  }
}
