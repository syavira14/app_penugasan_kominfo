import 'dart:async';
import 'tugas_detail_page.dart';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:file_saver/file_saver.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../services/file_preview_service.dart';
import '../../services/riwayat_file_service.dart';
import '../../services/riwayat_penugasan_service.dart';
import '../../services/supabase_storage_service.dart';
import '../../widgets/app_layout.dart';
import '../../widgets/simtas_file_preview_page.dart';

// ───────────────────────── Warna (disamakan dengan staff_kalender) ─────────────────────────
const Color kBiruTua = Color(0xFF1A1464);
const Color kBiruSedang = Color(0xFF1D5FA0);
const Color kBiruMuda = Color(0xFF4FA6DE);
const Color kBgLight = Color(0xFFF7F9FB);

// ───────────────────────────────── Model ─────────────────────────────────
class TugasModel {
  final String id;
  final String judulTugas;
  final String deskripsiTugas;
  final String namaAtasan;
  final String prioritasTugas; // "Rendah", "Sedang", "Tinggi"
  final DateTime? tanggalMulai;
  final DateTime? batasWaktu;
  final String keteranganHasil;
  final String fileHasil;
  final String fileHasilUrl;
  final String fileHasilPath;

  const TugasModel({
    required this.id,
    required this.judulTugas,
    required this.deskripsiTugas,
    required this.namaAtasan,
    required this.prioritasTugas,
    required this.tanggalMulai,
    required this.batasWaktu,
    this.keteranganHasil = '',
    this.fileHasil = '',
    this.fileHasilUrl = '',
    this.fileHasilPath = '',
  });
}

class RiwayatTugasPage extends StatefulWidget {
  const RiwayatTugasPage({super.key});

  @override
  State<RiwayatTugasPage> createState() => _RiwayatTugasPageState();
}

class _RiwayatTugasPageState extends State<RiwayatTugasPage> {
  static const int _perPage = 10;
  static const List<String> _monthNames = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  List<TugasModel> _daftarRiwayat = [];
  StreamSubscription<List<Map<String, dynamic>>>? _subscription;
  bool _loading = true;
  String? _error;

  String _pencarian = '';
  int _page = 0;
  int _selectedMonth = 0; // 0 = semua bulan
  int _selectedYear = 0; // 0 = semua tahun

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _loading = false;
      _error = 'Sesi login tidak ditemukan.';
      return;
    }
    _subscription = streamRiwayatPenugasan(staffId: uid).listen(
      (rows) {
        if (!mounted) return;
        final list = rows
            .map(
              (row) => TugasModel(
                id: row['id'].toString(),
                judulTugas: (row['judul'] ?? '-').toString(),
                deskripsiTugas: (row['deskripsi'] ?? '-').toString(),
                namaAtasan: (row['nama_atasan'] ?? '-').toString(),
                prioritasTugas: _title(
                  (row['prioritas'] ?? 'sedang').toString(),
                ),
                tanggalMulai: _date(
                  row['tanggal_mulai_tugas'] ??
                      row['tanggal_tugas_diberikan'] ??
                      row['created_at'],
                ),
                batasWaktu: _date(
                  row['tanggal_selesai_tugas'] ??
                      row['batas_waktu'] ??
                      row['deadline'],
                ),
                keteranganHasil: (row['catatan_staff'] ?? '').toString(),
                fileHasil: (row['file_hasil_nama'] ?? '').toString(),
                fileHasilUrl: (row['file_hasil_url'] ?? '').toString(),
                fileHasilPath: (row['file_hasil_path'] ?? '').toString(),
              ),
            )
            .toList();
        // Terbaru di atas; tanggal kosong di paling bawah.
        list.sort((a, b) {
          if (a.batasWaktu == null && b.batasWaktu == null) return 0;
          if (a.batasWaktu == null) return 1;
          if (b.batasWaktu == null) return -1;
          return b.batasWaktu!.compareTo(a.batasWaktu!);
        });
        setState(() {
          _loading = false;
          _error = null;
          _daftarRiwayat = list;
        });
      },
      onError: (Object error) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = 'Gagal memuat riwayat: $error';
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  // Terima Timestamp, DateTime, maupun String tanggal (sama seperti halaman atasan).
  DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    return null;
  }

  String _title(String value) =>
      value.isEmpty ? '-' : value[0].toUpperCase() + value.substring(1);

  // ───────────────────────────── Helper tampilan ─────────────────────────────

  BoxDecoration _cardDeco([double r = 16]) => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(r),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(.05),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ],
  );

  Color _prioColor(String p) {
    final s = p.toLowerCase();
    if (s.contains('tinggi')) return Colors.red.shade600;
    if (s.contains('rendah')) return Colors.green.shade600;
    return Colors.amber.shade700;
  }

  Widget _pill(String text, Color color, IconData icon, double scale) =>
      Container(
        padding: EdgeInsets.symmetric(
          horizontal: 10 * scale,
          vertical: 5 * scale,
        ),
        decoration: BoxDecoration(
          color: color.withOpacity(.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12 * scale, color: color),
            SizedBox(width: 4 * scale),
            Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 11 * scale,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );

  Widget _prioPill(String p, double scale) =>
      _pill(p, _prioColor(p), Icons.flag_rounded, scale);

  Widget _donePill(double scale) =>
      _pill('Selesai', Colors.green.shade700, Icons.check_circle, scale);

  String _fmt(DateTime? d, {bool jam = false}) {
    if (d == null) return '-';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    final base =
        '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
    if (!jam) return base;
    return '$base, ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} WIB';
  }

  bool get _periodActive => _selectedMonth != 0 || _selectedYear != 0;

  String get _periodLabel {
    if (!_periodActive) return 'Semua Periode';
    final bulan = _selectedMonth == 0
        ? 'Semua Bulan'
        : _monthNames[_selectedMonth - 1];
    final tahun = _selectedYear == 0 ? 'Semua Tahun' : '$_selectedYear';
    return '$bulan $tahun';
  }

  String _extOf(String name) {
    final i = name.lastIndexOf('.');
    return i < 0 ? '' : name.substring(i + 1).toLowerCase();
  }

  bool _isImage(String name) =>
      const ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(_extOf(name));

  Future<String> _urlFile(TugasModel t) async {
    if (t.fileHasilPath.isNotEmpty) {
      // Jalur utama: klien Supabase (RLS folder milik staff sendiri).
      try {
        return await SupabaseStorageService().buatLinkSementara(
          t.fileHasilPath,
        );
      } catch (_) {
        // Cadangan: Edge Function.
        return ambilUrlFileHasil(t.id, path: t.fileHasilPath);
      }
    }
    if (t.fileHasilUrl.isNotEmpty) return t.fileHasilUrl;
    throw StateError('File hasil pekerjaan belum tersedia.');
  }

  void _pesan(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? Colors.red.shade700 : kBiruTua,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _lihatFile(BuildContext ctx, TugasModel t, String name) async {
    try {
      final url = await _urlFile(t);
      if (_isImage(name)) {
        if (!ctx.mounted) return;
        _previewGambar(ctx, name, url);
        return;
      }
      Uint8List bytes = Uint8List(0);
      if (!name.toLowerCase().endsWith('.pdf')) {
        final r = await http.get(Uri.parse(url));
        if (r.statusCode != 200) throw StateError('HTTP ${r.statusCode}');
        bytes = r.bodyBytes;
      }
      if (!ctx.mounted) return;
      await Navigator.push(
        ctx,
        MaterialPageRoute<void>(
          builder: (_) => SimtasFilePreviewPage(
            namaFile: name,
            bytes: bytes,
            externalUrl: url,
          ),
        ),
      );
    } catch (e) {
      _pesan('Gagal membuka file: $e', error: true);
    }
  }

  Future<void> _unduhFile(TugasModel t, String name) async {
    _pesan('Mengunduh $name...');
    try {
      Uint8List data;
      if (t.fileHasilPath.isNotEmpty) {
        try {
          // Unduh langsung dari bucket (hanya file milik staff sendiri).
          data = await FilePreviewService().downloadFileStaff(t.fileHasilPath);
        } catch (_) {
          final r = await http.get(Uri.parse(await _urlFile(t)));
          if (r.statusCode != 200) throw StateError('HTTP ${r.statusCode}');
          data = r.bodyBytes;
        }
      } else {
        final r = await http.get(Uri.parse(await _urlFile(t)));
        if (r.statusCode != 200) throw StateError('HTTP ${r.statusCode}');
        data = r.bodyBytes;
      }
      final ext = _extOf(name);
      final base = ext.isEmpty
          ? name
          : name.substring(0, name.length - ext.length - 1);
      await FileSaver.instance.saveFile(
        name: base,
        bytes: data,
        ext: ext,
        mimeType: MimeType.other,
      );
      _pesan('File "$name" berhasil diunduh');
    } catch (e) {
      // Cadangan: buka tautan agar bisa disimpan manual.
      try {
        await _bukaFile(await _urlFile(t));
      } catch (_) {
        _pesan('Gagal mengunduh file: $e', error: true);
      }
    }
  }

  Future<void> _bukaFile(String url) async {
    if (url.isEmpty) return;
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Gagal membuka file')));
    }
  }

  // ─────────────────────────────────── Build ───────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double scale = (screenWidth / 375).clamp(0.85, 1.25);
    final bool isWide = screenWidth >= 700;

    return Scaffold(
      backgroundColor: kBgLight,
      body: Column(
        children: [
          // HEADER GRADIENT FLAT (sama dengan Kalender Penugasan)
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [kBiruMuda, kBiruSedang, kBiruTua],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16 * scale),
                child: ResponsiveContent(
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.maybePop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 24 * scale,
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            'Riwayat Tugas',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18 * scale,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 24 * scale),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // KONTEN
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(child: Text(_error!))
                : _buildBody(scale, isWide),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(double scale, bool isWide) {
    final q = _pencarian.toLowerCase().trim();

    // Daftar tahun dari data.
    final years = <int>{DateTime.now().year};
    for (final t in _daftarRiwayat) {
      if (t.batasWaktu != null) years.add(t.batasWaktu!.year);
    }
    if (_selectedYear != 0) years.add(_selectedYear);
    final yearList = years.toList()..sort((a, b) => b.compareTo(a));

    // 1) Filter periode
    final byPeriod = _daftarRiwayat.where((t) {
      if (!_periodActive) return true;
      final d = t.batasWaktu;
      if (d == null) return false;
      if (_selectedMonth != 0 && d.month != _selectedMonth) return false;
      if (_selectedYear != 0 && d.year != _selectedYear) return false;
      return true;
    }).toList();

    // 2) Filter pencarian
    final filtered = byPeriod.where((t) {
      return q.isEmpty ||
          t.judulTugas.toLowerCase().contains(q) ||
          t.namaAtasan.toLowerCase().contains(q);
    }).toList();

    final pages = math.max(1, (filtered.length / _perPage).ceil());
    final pg = _page.clamp(0, pages - 1);
    final shown = filtered.skip(pg * _perPage).take(_perPage).toList();

    return ResponsiveContent(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(0, 16 * scale, 0, 20 * scale),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _summary(byPeriod, scale, isWide),
            SizedBox(height: 16 * scale),
            _filterBar(scale, isWide, yearList),
            SizedBox(height: 16 * scale),
            if (shown.isEmpty)
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 40 * scale),
                decoration: _cardDeco(),
                child: Center(
                  child: Text(
                    'Tidak ada riwayat tugas pada periode ini',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 13 * scale,
                    ),
                  ),
                ),
              )
            else if (isWide)
              _tableCard(shown, pg, scale)
            else
              Column(children: [for (final t in shown) _mobileCard(t, scale)]),
            SizedBox(height: 8 * scale),
            Center(child: _pager(pg, pages)),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────── Ringkasan ─────────────────────────────────

  Widget _summary(List<TugasModel> base, double scale, bool wide) {
    int n(String p) => base
        .where((t) => t.prioritasTugas.toLowerCase() == p.toLowerCase())
        .length;

    Widget total() => Container(
      padding: EdgeInsets.all(16 * scale),
      decoration: _cardDeco(),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24 * scale,
            backgroundColor: const Color(0xFFE2EFFB),
            child: Icon(
              Icons.description_rounded,
              color: kBiruSedang,
              size: 24 * scale,
            ),
          ),
          SizedBox(width: 14 * scale),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Tugas Selesai',
                  style: TextStyle(
                    fontSize: 12.5 * scale,
                    fontWeight: FontWeight.w600,
                    color: kBiruTua,
                  ),
                ),
                Text(
                  '${base.length}',
                  style: TextStyle(
                    fontSize: 28 * scale,
                    fontWeight: FontWeight.bold,
                    color: kBiruTua,
                  ),
                ),
                Text(
                  _periodLabel,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11 * scale,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    Widget prio(String p, IconData icon, {required bool compact}) {
      final color = _prioColor(p);
      return Container(
        padding: EdgeInsets.all((compact ? 12 : 16) * scale),
        decoration: BoxDecoration(
          color: color.withOpacity(.07),
          borderRadius: BorderRadius.circular(16 * scale),
          border: Border.all(color: color.withOpacity(.2)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18 * scale,
              backgroundColor: color.withOpacity(.15),
              child: Icon(icon, color: color, size: 18 * scale),
            ),
            SizedBox(width: 8 * scale),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    compact ? p : 'Prioritas $p',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11 * scale,
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${n(p)}',
                    style: TextStyle(
                      fontSize: 22 * scale,
                      fontWeight: FontWeight.bold,
                      color: kBiruTua,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (wide) {
      return Row(
        children: [
          Expanded(flex: 4, child: total()),
          SizedBox(width: 12 * scale),
          Expanded(
            flex: 3,
            child: prio('Tinggi', Icons.local_fire_department, compact: false),
          ),
          SizedBox(width: 12 * scale),
          Expanded(
            flex: 3,
            child: prio('Sedang', Icons.event_note, compact: false),
          ),
          SizedBox(width: 12 * scale),
          Expanded(
            flex: 3,
            child: prio('Rendah', Icons.check_circle, compact: false),
          ),
        ],
      );
    }

    return Column(
      children: [
        total(),
        SizedBox(height: 10 * scale),
        Row(
          children: [
            Expanded(
              child: prio('Tinggi', Icons.local_fire_department, compact: true),
            ),
            SizedBox(width: 8 * scale),
            Expanded(child: prio('Sedang', Icons.event_note, compact: true)),
            SizedBox(width: 8 * scale),
            Expanded(child: prio('Rendah', Icons.check_circle, compact: true)),
          ],
        ),
      ],
    );
  }

  // ─────────────────────────── Pencarian + Filter Periode ───────────────────────────

  Widget _searchBar(double scale) => TextField(
    onChanged: (v) => setState(() {
      _pencarian = v;
      _page = 0;
    }),
    decoration: InputDecoration(
      hintText: 'Cari judul tugas atau atasan...',
      hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13 * scale),
      prefixIcon: const Icon(Icons.search, color: kBiruSedang),
      filled: true,
      fillColor: Colors.white,
      contentPadding: EdgeInsets.symmetric(vertical: 14 * scale),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide.none,
      ),
    ),
  );

  Widget _periodDropdown({
    required int value,
    required List<DropdownMenuItem<int>> items,
    required ValueChanged<int> onChanged,
    required double scale,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, color: kBiruSedang),
          style: TextStyle(
            fontSize: 13 * scale,
            fontWeight: FontWeight.w600,
            color: kBiruTua,
          ),
          items: items,
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }

  Widget _filterBar(double scale, bool wide, List<int> yearList) {
    final monthDropdown = _periodDropdown(
      scale: scale,
      value: _selectedMonth,
      items: [
        const DropdownMenuItem(value: 0, child: Text('Semua Bulan')),
        for (var i = 0; i < 12; i++)
          DropdownMenuItem(value: i + 1, child: Text(_monthNames[i])),
      ],
      onChanged: (v) => setState(() {
        _selectedMonth = v;
        _page = 0;
      }),
    );

    final yearDropdown = _periodDropdown(
      scale: scale,
      value: _selectedYear,
      items: [
        const DropdownMenuItem(value: 0, child: Text('Semua Tahun')),
        for (final y in yearList) DropdownMenuItem(value: y, child: Text('$y')),
      ],
      onChanged: (v) => setState(() {
        _selectedYear = v;
        _page = 0;
      }),
    );

    final resetButton = TextButton.icon(
      onPressed: _periodActive
          ? () => setState(() {
              _selectedMonth = 0;
              _selectedYear = 0;
              _page = 0;
            })
          : null,
      icon: const Icon(Icons.restart_alt_rounded, size: 18),
      label: const Text('Reset'),
    );

    if (wide) {
      return Row(
        children: [
          Expanded(child: _searchBar(scale)),
          const SizedBox(width: 12),
          const Icon(Icons.filter_alt_rounded, color: kBiruSedang),
          const SizedBox(width: 8),
          SizedBox(width: 160, child: monthDropdown),
          const SizedBox(width: 8),
          SizedBox(width: 140, child: yearDropdown),
          const SizedBox(width: 4),
          resetButton,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _searchBar(scale),
        SizedBox(height: 10 * scale),
        Row(
          children: [
            Expanded(child: monthDropdown),
            SizedBox(width: 8 * scale),
            Expanded(child: yearDropdown),
          ],
        ),
        Align(alignment: Alignment.centerRight, child: resetButton),
      ],
    );
  }

  // ─────────────────────────────── Daftar (tabel / kartu) ───────────────────────────────

  Widget _tableCard(List<TugasModel> shown, int pg, double scale) {
    Widget head(String t, int flex) => Expanded(
      flex: flex,
      child: Text(
        t,
        style: TextStyle(
          fontSize: 11.5 * scale,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade700,
        ),
      ),
    );

    return Container(
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Riwayat Tugas',
                    style: TextStyle(
                      fontSize: 17 * scale,
                      fontWeight: FontWeight.bold,
                      color: kBiruTua,
                    ),
                  ),
                ),
                _pill(
                  _periodLabel,
                  kBiruSedang,
                  Icons.calendar_month_rounded,
                  scale,
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                head('No', 5),
                head('Judul Tugas', 28),
                head('Atasan', 18),
                head('Prioritas', 13),
                head('Tgl Mulai', 13),
                head('Tgl Selesai', 13),
                head('Status', 11),
              ],
            ),
          ),
          for (var i = 0; i < shown.length; i++)
            _tableRow(shown[i], pg * _perPage + i + 1, scale),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _tableRow(TugasModel t, int no, double scale) {
    return InkWell(
      onTap: () => _tampilkanPopUpDetail(t),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: Text('$no', style: TextStyle(fontSize: 12.5 * scale)),
            ),
            Expanded(
              flex: 28,
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Text(
                  t.judulTugas,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5 * scale,
                    fontWeight: FontWeight.w700,
                    color: kBiruTua,
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 18,
              child: Text(
                t.namaAtasan,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5 * scale),
              ),
            ),
            Expanded(
              flex: 13,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _prioPill(t.prioritasTugas, scale),
              ),
            ),
            Expanded(
              flex: 13,
              child: Text(
                _fmt(t.tanggalMulai),
                style: TextStyle(fontSize: 12 * scale),
              ),
            ),
            Expanded(
              flex: 13,
              child: Text(
                _fmt(t.batasWaktu),
                style: TextStyle(fontSize: 12 * scale),
              ),
            ),
            Expanded(
              flex: 11,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _donePill(scale),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mobileCard(TugasModel t, double scale) {
    return Container(
      margin: EdgeInsets.only(bottom: 12 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20 * scale),
        border: Border(
          left: BorderSide(color: Colors.green.shade600, width: 4 * scale),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20 * scale),
        onTap: () => _tampilkanPopUpDetail(t),
        child: Padding(
          padding: EdgeInsets.all(16 * scale),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _prioPill(t.prioritasTugas, scale),
                  _donePill(scale),
                ],
              ),
              SizedBox(height: 10 * scale),
              Text(
                t.judulTugas,
                style: TextStyle(
                  fontSize: 14 * scale,
                  fontWeight: FontWeight.bold,
                  color: kBiruTua,
                ),
              ),
              SizedBox(height: 4 * scale),
              Text(
                t.deskripsiTugas,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12 * scale,
                  color: Colors.grey.shade600,
                  height: 1.35,
                ),
              ),
              Divider(height: 20 * scale),
              _infoRow(
                Icons.assignment_ind_rounded,
                'Diberikan oleh: ${t.namaAtasan}',
                scale,
              ),
              SizedBox(height: 4 * scale),
              _infoRow(
                Icons.play_circle_outline_rounded,
                'Diberikan: ${_fmt(t.tanggalMulai, jam: true)}',
                scale,
              ),
              SizedBox(height: 4 * scale),
              _infoRow(
                Icons.event_rounded,
                'Batas waktu: ${_fmt(t.batasWaktu, jam: true)}',
                scale,
              ),
              SizedBox(height: 8 * scale),
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Lihat Detail',
                      style: TextStyle(
                        fontSize: 12 * scale,
                        color: kBiruSedang,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 16 * scale,
                      color: kBiruSedang,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, double scale) => Row(
    children: [
      Icon(icon, size: 15 * scale, color: kBiruSedang),
      SizedBox(width: 8 * scale),
      Expanded(
        child: Text(
          text,
          style: TextStyle(fontSize: 12 * scale, color: Colors.grey.shade700),
        ),
      ),
    ],
  );

  Widget _pager(int pg, int pages) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        onPressed: pg > 0 ? () => setState(() => _page = pg - 1) : null,
        icon: const Icon(Icons.chevron_left),
      ),
      Text(
        '${pg + 1}/$pages',
        style: const TextStyle(fontWeight: FontWeight.bold, color: kBiruTua),
      ),
      IconButton(
        onPressed: pg < pages - 1 ? () => setState(() => _page = pg + 1) : null,
        icon: const Icon(Icons.chevron_right),
      ),
    ],
  );

  // ─────────────────────────── Pop-up Dialog Detail ───────────────────────────

  Widget _sectionTitle(String s) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      s,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: kBiruTua,
      ),
    ),
  );

  void _tampilkanPopUpDetail(TugasModel t) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 560,
            maxHeight: MediaQuery.of(ctx).size.height * 0.9,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Detail Riwayat Tugas',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: kBiruTua,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: _detailContent(ctx, t),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailContent(BuildContext ctx, TugasModel t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.judulTugas,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: kBiruTua,
          ),
        ),
        const SizedBox(height: 14),
        _infoRow(
          Icons.assignment_ind_rounded,
          'Diberikan oleh: ${t.namaAtasan}',
          1,
        ),
        const SizedBox(height: 6),
        _infoRow(
          Icons.play_circle_outline_rounded,
          'Diberikan: ${_fmt(t.tanggalMulai, jam: true)}',
          1,
        ),
        const SizedBox(height: 6),
        _infoRow(
          Icons.flag_outlined,
          'Batas Waktu: ${_fmt(t.batasWaktu, jam: true)}',
          1,
        ),
        const Divider(height: 28),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle('Prioritas'),
                  _prioPill(t.prioritasTugas, 1),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [_sectionTitle('Status'), _donePill(1)],
              ),
            ),
          ],
        ),
        const Divider(height: 28),
        _sectionTitle('Deskripsi Tugas'),
        Text(
          t.deskripsiTugas,
          style: TextStyle(
            fontSize: 12.5,
            height: 1.4,
            color: Colors.grey.shade700,
          ),
        ),
        const Divider(height: 28),
        _sectionTitle('Catatan Hasil Pengerjaan'),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F6FC),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            t.keteranganHasil.isNotEmpty
                ? t.keteranganHasil
                : 'Tidak ada catatan.',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Colors.grey.shade800,
            ),
          ),
        ),
        const Divider(height: 28),
        _sectionTitle('Lampiran Hasil Pekerjaan'),
        if (t.fileHasil.isEmpty &&
            t.fileHasilUrl.isEmpty &&
            t.fileHasilPath.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F6FC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Tidak ada lampiran hasil pekerjaan.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          )
        else
          _fileCard(ctx, t),
      ],
    );
  }

  Widget _fileCard(BuildContext ctx, TugasModel t) {
    final name = t.fileHasil.isNotEmpty
        ? t.fileHasil
        : (t.fileHasilPath.isNotEmpty
              ? t.fileHasilPath.split('/').last
              : 'File Hasil');
    final ext = _extOf(name);
    final hasUrl = t.fileHasilUrl.isNotEmpty || t.fileHasilPath.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F6FC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: kBiruMuda.withOpacity(.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _isImage(name) ? Icons.image_rounded : Icons.description_rounded,
              color: kBiruSedang,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: kBiruTua,
                  ),
                ),
                if (ext.isNotEmpty)
                  Text(
                    ext.toUpperCase(),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
              ],
            ),
          ),
          if (hasUrl) ...[
            IconButton(
              tooltip: 'Lihat',
              onPressed: () => _lihatFile(ctx, t, name),
              icon: const Icon(Icons.visibility_rounded, color: kBiruSedang),
            ),
            IconButton(
              tooltip: 'Unduh',
              onPressed: () => _unduhFile(t, name),
              icon: const Icon(Icons.download_rounded, color: kBiruSedang),
            ),
          ],
        ],
      ),
    );
  }

  void _previewGambar(BuildContext ctx, String name, String url) {
    showDialog(
      context: ctx,
      builder: (dctx) => Dialog(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 800,
            maxHeight: MediaQuery.of(dctx).size.height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: kBiruTua,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(dctx),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: InteractiveViewer(
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Padding(
                      padding: EdgeInsets.all(30),
                      child: Text('Gambar tidak dapat ditampilkan.'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
