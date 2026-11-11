// lib/widgets/simtas_file_preview_page.dart
//
// Pengganti SimtasFilePreviewPage. Konstruktor SAMA dengan yang lama
// (namaFile, bytes, externalUrl), jadi halaman Admin yang memakainya tetap jalan.
//
// Dependensi pubspec.yaml:
//   pdfrx: ^2.1.24      # PDF dirender di dalam aplikasi (web + mobile)
//   archive: ^3.6.1     # membaca isi .docx
//   file_saver, http    # sudah ada di proyek Anda
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdfrx/pdfrx.dart';

enum _Jenis { pdf, gambar, docx, lain }

class SimtasFilePreviewPage extends StatefulWidget {
  const SimtasFilePreviewPage({
    super.key,
    required this.namaFile,
    required this.bytes,
    this.externalUrl,
  });

  final String namaFile;
  final Uint8List bytes;
  final String? externalUrl;

  @override
  State<SimtasFilePreviewPage> createState() => _SimtasFilePreviewPageState();
}

class _SimtasFilePreviewPageState extends State<SimtasFilePreviewPage> {
  Uint8List? _bytes;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var data = widget.bytes;
      final url = (widget.externalUrl ?? '').trim();
      if (data.isEmpty && url.isNotEmpty) {
        if (url.startsWith('data:')) {
          final i = url.indexOf(',');
          data = base64Decode(
            url.substring(i + 1).replaceAll(RegExp(r'\s'), ''),
          );
        } else if (url.startsWith('http')) {
          final res = await http
              .get(Uri.parse(url))
              .timeout(const Duration(seconds: 30));
          if (res.statusCode != 200) {
            throw StateError('Server membalas HTTP ${res.statusCode}.');
          }
          data = res.bodyBytes;
        }
      }
      if (data.isEmpty)
        throw StateError('Isi file kosong / tidak berhasil dimuat.');
      if (!mounted) return;
      setState(() {
        _bytes = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  // Deteksi dari isi file (magic bytes) dulu, baru dari ekstensi.
  _Jenis get _jenis {
    final b = _bytes;
    if (b != null && b.length > 4) {
      if (b[0] == 0x25 && b[1] == 0x50 && b[2] == 0x44 && b[3] == 0x46) {
        return _Jenis.pdf; // %PDF
      }
      if (b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E) return _Jenis.gambar;
      if (b[0] == 0xFF && b[1] == 0xD8) return _Jenis.gambar;
      if (b[0] == 0x50 &&
          b[1] == 0x4B &&
          widget.namaFile.toLowerCase().endsWith('.docx')) {
        return _Jenis.docx;
      }
    }
    final n = widget.namaFile.toLowerCase();
    if (n.endsWith('.pdf')) return _Jenis.pdf;
    if (n.endsWith('.docx')) return _Jenis.docx;
    if (RegExp(r'\.(jpe?g|png|gif|webp|bmp)$').hasMatch(n))
      return _Jenis.gambar;
    return _Jenis.lain;
  }

  Future<void> _unduh() async {
    final b = _bytes;
    if (b == null) return;
    final nama = widget.namaFile;
    final dot = nama.lastIndexOf('.');
    final ext = dot < 0 ? '' : nama.substring(dot + 1).toLowerCase();
    final base = dot <= 0 ? nama : nama.substring(0, dot);
    try {
      await FileSaver.instance.saveFile(
        name: base.isEmpty ? 'Lampiran' : base,
        bytes: b,
        ext: ext,
        mimeType: MimeType.other,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('"$nama" berhasil diunduh')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengunduh: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF202124),
      appBar: AppBar(
        backgroundColor: const Color(0xFF202124),
        foregroundColor: Colors.white,
        title: Text(
          widget.namaFile,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          IconButton(
            tooltip: 'Unduh',
            onPressed: _bytes == null ? null : _unduh,
            icon: const Icon(Icons.download_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _pesanError(_error!)
          : _isi(),
    );
  }

  Widget _pesanError(String msg) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.white70, size: 48),
          const SizedBox(height: 12),
          Text(
            'File tidak dapat ditampilkan\n$msg',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _muat, child: const Text('Coba lagi')),
        ],
      ),
    ),
  );

  Widget _isi() {
    final b = _bytes!;
    switch (_jenis) {
      case _Jenis.pdf:
        return PdfViewer.data(b, sourceName: widget.namaFile);
      case _Jenis.gambar:
        return InteractiveViewer(
          minScale: .5,
          maxScale: 8,
          child: Center(
            child: Image.memory(
              b,
              fit: BoxFit.contain,
              errorBuilder: (_, e, __) => _pesanError('Gambar rusak: $e'),
            ),
          ),
        );
      case _Jenis.docx:
        return _DocxView(bytes: b);
      case _Jenis.lain:
        return _pesanError(
          'Format ini belum bisa ditampilkan di dalam aplikasi.\nGunakan tombol Unduh.',
        );
    }
  }
}

/// Menampilkan teks isi .docx (paragraf & tabel sederhana). Tata letak/gambar
/// asli Word tidak dirender; untuk itu gunakan PDF.
class _DocxView extends StatelessWidget {
  const _DocxView({required this.bytes});
  final Uint8List bytes;

  List<String> _paragraf() {
    final zip = ZipDecoder().decodeBytes(bytes);
    final f = zip.files.firstWhere((x) => x.name == 'word/document.xml');
    final xml = utf8.decode(f.content as List<int>);
    final out = <String>[];
    for (final p in RegExp(
      r'<w:p[ >].*?</w:p>',
      dotAll: true,
    ).allMatches(xml)) {
      final sb = StringBuffer();
      for (final m in RegExp(
        r'<w:t[^>]*>(.*?)</w:t>|<w:tab/>|<w:br/>',
        dotAll: true,
      ).allMatches(p.group(0)!)) {
        final g = m.group(0)!;
        if (g.startsWith('<w:tab')) {
          sb.write('\t');
        } else if (g.startsWith('<w:br')) {
          sb.write('\n');
        } else {
          sb.write(m.group(1));
        }
      }
      final t = sb
          .toString()
          .replaceAll('&amp;', '&')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&quot;', '"')
          .replaceAll('&apos;', "'");
      out.add(t);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    List<String> paras;
    try {
      paras = _paragraf();
    } catch (e) {
      return Center(
        child: Text(
          'Gagal membaca dokumen: $e',
          style: const TextStyle(color: Colors.white70),
        ),
      );
    }
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 820),
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(24),
        color: Colors.white,
        child: SingleChildScrollView(
          child: SelectableText(
            paras.join('\n\n'),
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}
