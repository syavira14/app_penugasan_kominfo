import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'pdf_iframe_stub.dart' if (dart.library.js_interop) 'pdf_iframe_web.dart';

/// Halaman tambahan; tidak mengubah widget desain Detail Tugas.
class SimtasFilePreviewPage extends StatefulWidget {
  final String namaFile;
  final Uint8List bytes;
  final String? externalUrl;

  const SimtasFilePreviewPage({
    required this.namaFile,
    required this.bytes,
    this.externalUrl,
  });

  @override
  State<SimtasFilePreviewPage> createState() =>
      _SimtasFilePreviewPageStateShared();
}

class _SimtasFilePreviewPageStateShared extends State<SimtasFilePreviewPage> {
  String? _pdfError;
  bool _pdfLoaded = false;

  bool get _pdfHeaderValid {
    final bytes = widget.bytes;
    if (bytes.length < 5) return false;
    // Toleransi BOM/whitespace sebelum header PDF.
    final prefix = String.fromCharCodes(bytes.take(32));
    return prefix.contains('%PDF-');
  }

  Future<void> _openExternal() async {
    final url = widget.externalUrl;
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link file tidak tersedia.')),
      );
      return;
    }
    try {
      final success = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!success) throw StateError('File tidak dapat dibuka.');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuka file: $e')),
      );
    }
  }

  Widget _errorView(String message) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.picture_as_pdf_outlined,
                size: 64, color: const Color(0xFF1D5FA0)),
            const SizedBox(height: 16),
            const Text('Preview PDF belum dapat ditampilkan',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            if (widget.externalUrl != null)
              ElevatedButton.icon(
                onPressed: _openExternal,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Buka di browser'),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lower = widget.namaFile.toLowerCase();
    final isPdf = lower.endsWith('.pdf');
    final isImage = lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') || lower.endsWith('.png');

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1464),
        foregroundColor: Colors.white,
        title: Text(widget.namaFile,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (widget.externalUrl != null)
            IconButton(
              tooltip: 'Buka dengan aplikasi lain',
              icon: const Icon(Icons.open_in_new),
              onPressed: _openExternal,
            ),
        ],
      ),
      body: isPdf && kIsWeb && widget.externalUrl != null
          ? SimtasPdfWebView(url: widget.externalUrl!)
          : isPdf
          ? !_pdfHeaderValid
              ? _errorView('Data yang diterima bukan PDF valid. '
                  'Periksa file asli di Supabase Storage.')
              : _pdfError != null
                  ? _errorView(_pdfError!)
                  : Stack(
                      children: [
                        SfPdfViewer.memory(
                          widget.bytes,
                          onDocumentLoaded: (_) {
                            if (mounted) setState(() => _pdfLoaded = true);
                          },
                          onDocumentLoadFailed: (details) {
                            if (mounted) {
                              setState(() {
                                _pdfError = '${details.error}: '
                                    '${details.description}';
                              });
                            }
                          },
                        ),
                        if (!_pdfLoaded)
                          const Center(child: CircularProgressIndicator()),
                      ],
                    )
          : isImage
              ? Center(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 5,
                    child: Image.memory(
                      widget.bytes,
                      fit: BoxFit.contain,
                      errorBuilder: (_, error, __) =>
                          _errorView('Gambar tidak dapat ditampilkan: $error'),
                    ),
                  ),
                )
              : _errorView('Format ini belum mendukung preview internal.'),
    );
  }
}
