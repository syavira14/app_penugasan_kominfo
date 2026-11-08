import 'dart:async';
import 'package:file_picker/file_picker.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../services/supabase_storage_service.dart';
import '../../services/laporan_kendala_service.dart';

/// Halaman admin SIMTAS.
/// Laporan dibuat staff dari halaman Detail Tugas.
class LaporanKendalaAdminPage extends StatefulWidget {
  const LaporanKendalaAdminPage({super.key});

  @override
  State<LaporanKendalaAdminPage> createState() =>
      _LaporanKendalaAdminPageState();
}

class _LaporanKendalaAdminPageState extends State<LaporanKendalaAdminPage> {
  static const Color biruTua = Color(0xFF0011CC);
  static const Color biru = Color(0xFF0066FF);
  static const Color latar = Color(0xFFF5F7FC);

  static const Duration masaTampilSelesai = Duration(days: 3);

  final _service = LaporanKendalaService();
  final _db = FirebaseFirestore.instance;
  final _search = TextEditingController();

  final Map<String, Future<Map<String, String>>> _detailsCache = {};

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _assignmentStream;

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _reportStream;

  Timer? _refreshTimer;

  String _status = 'semua';
  String _jenis = 'semua';
  String _prioritas = 'semua';
  String _urut = 'terbaru';
  String _query = '';

  @override
  void initState() {
    super.initState();

    _assignmentStream = _db.collection('penugasan').snapshots();

    _reportStream = _service.streamSemuaLaporan();

    // Memperbarui masa tampil laporan secara berkala,
    // tanpa menunggu perubahan dari Firebase.
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _search.dispose();
    super.dispose();
  }

  String _value(
    Map<String, dynamic> data,
    String key, [
    String fallback = '-',
  ]) {
    final value = (data[key] ?? '').toString().trim();
    return value.isEmpty ? fallback : value;
  }

  DateTime _date(Map<String, dynamic> data) {
    final value = data['tanggal_laporan'] ?? data['created_at'];

    if (value is Timestamp) return value.toDate();

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  DateTime? _processedDate(Map<String, dynamic> data) {
    final status = _value(data, 'status', '');

    // Gunakan waktu perubahan status terminal.
    // Jangan gunakan tanggal pembuatan laporan.
    final dynamic value;

    if (status == StatusLaporanKendala.selesai) {
      value = data['resolved_at'] ?? data['updated_at'];
    } else if (status == StatusLaporanKendala.ditolak) {
      value = data['rejected_at'] ?? data['updated_at'];
    } else {
      return null;
    }

    if (value is Timestamp) return value.toDate();

    return null;
  }

  String _tanggal(DateTime date) {
    if (date.millisecondsSinceEpoch == 0) {
      return '-';
    }

    String two(int n) => n.toString().padLeft(2, '0');

    return '${two(date.day)}/${two(date.month)}/'
        '${date.year} ${two(date.hour)}:'
        '${two(date.minute)}';
  }

  bool _isActiveStatus(String status) {
    return status == StatusLaporanKendala.menungguReview ||
        status == StatusLaporanKendala.dalamPenanganan ||
        status == StatusLaporanKendala.menungguKonfirmasi;
  }

  bool _isTerminalStatus(String status) {
    return status == StatusLaporanKendala.selesai ||
        status == StatusLaporanKendala.ditolak;
  }

  /// Aturan utama tampilan laporan:
  ///
  /// 1. Laporan aktif hanya tampil jika penugasan
  ///    masih berstatus terkendala.
  ///
  /// 2. Laporan selesai/ditolak tampil 3 hari
  ///    sejak diproses, meskipun status penugasan
  ///    sudah kembali berlangsung.
  ///
  /// 3. Laporan historis tetap tersimpan di Firebase.
  bool _laporanDitampilkan(
    QueryDocumentSnapshot<Map<String, dynamic>> report,
    Map<String, Map<String, dynamic>> assignments,
  ) {
    final data = report.data();

    final statusLaporan = _value(data, 'status', '');

    final assignmentId = _value(data, 'penugasan_id', '');

    final assignment = assignments[assignmentId];

    if (assignment == null) {
      return false;
    }

    final statusPenugasan = _value(assignment, 'status', '');

    if (_isActiveStatus(statusLaporan)) {
      if (statusPenugasan != 'terkendala') {
        return false;
      }

      // Jika sudah ada ID kendala aktif,
      // hanya laporan tersebut yang ditampilkan.
      // Dokumen lama tanpa ID masih diperbolehkan
      // agar tidak langsung menghilangkan laporan
      // yang memang sedang terkendala.
      final activeId = _value(assignment, 'kendala_aktif_id', '');

      if (activeId.isNotEmpty && activeId != report.id) {
        return false;
      }

      return true;
    }

    if (_isTerminalStatus(statusLaporan)) {
      final processedAt = _processedDate(data);

      // Data lama tanpa waktu pemrosesan
      // tidak dimasukkan ke daftar sementara.
      if (processedAt == null) {
        return false;
      }

      final now = DateTime.now();
      final batasTampil = processedAt.add(masaTampilSelesai);

      return !processedAt.isAfter(now) && now.isBefore(batasTampil);
    }

    return false;
  }

  Color _statusColor(String status) {
    switch (status) {
      case StatusLaporanKendala.menungguReview:
        return const Color(0xFFB96B00);

      case StatusLaporanKendala.dalamPenanganan:
        return biru;

      case StatusLaporanKendala.menungguKonfirmasi:
        return const Color(0xFF7C3AED);

      case StatusLaporanKendala.selesai:
        return const Color(0xFF15803D);

      case StatusLaporanKendala.ditolak:
        return const Color(0xFFB42318);

      default:
        return Colors.blueGrey;
    }
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Future<Map<String, String>> _getDetails(Map<String, dynamic> data) async {
    final staffId = _value(data, 'pelapor_id', '');

    final tugasId = _value(data, 'tugas_id', '');

    final results = await Future.wait([
      if (staffId.isNotEmpty) _db.collection('users').doc(staffId).get(),
      if (tugasId.isNotEmpty) _db.collection('tugas').doc(tugasId).get(),
    ]);

    String nama = 'Staff';
    String tugas = 'Tugas tidak ditemukan';

    for (final snap in results) {
      final item = snap.data() ?? {};

      if (snap.reference.parent.id == 'users') {
        nama = _value(item, 'nama', 'Staff');
      }

      if (snap.reference.parent.id == 'tugas') {
        tugas = _value(item, 'judul', 'Tugas tanpa judul');
      }
    }

    return {'nama': nama, 'tugas': tugas};
  }

  Future<Map<String, String>> _details(String id, Map<String, dynamic> data) {
    return _detailsCache.putIfAbsent(id, () => _getDetails(data));
  }

  bool _matches(Map<String, dynamic> data, String id) {
    if (_status != 'semua' && _value(data, 'status', '') != _status) {
      return false;
    }

    if (_jenis != 'semua' &&
        _value(data, 'jenis_kendala', '').toLowerCase() != _jenis) {
      return false;
    }

    if (_prioritas != 'semua' &&
        _value(data, 'prioritas', '').toLowerCase() != _prioritas) {
      return false;
    }

    if (_query.isEmpty) return true;

    final terms = [
      id,
      ...data.values.map((value) => value is Timestamp ? '' : value.toString()),
    ].join(' ').toLowerCase();

    return terms.contains(_query);
  }

  void _reset() {
    setState(() {
      _search.clear();
      _query = '';
      _status = 'semua';
      _jenis = 'semua';
      _prioritas = 'semua';
      _urut = 'terbaru';
    });
  }

  Widget _dropdown(
    String label,
    String value,
    List<DropdownMenuItem<String>> options,
    ValueChanged<String?> onChanged,
  ) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blueGrey.shade100),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          isDense: true,
          items: options,
          onChanged: onChanged,
          style: const TextStyle(color: Color(0xFF26334D), fontSize: 12),
        ),
      ),
    );
  }

  List<DropdownMenuItem<String>> _items(Map<String, String> values) {
    return values.entries
        .map(
          (entry) => DropdownMenuItem<String>(
            value: entry.key,
            child: Text(entry.value, overflow: TextOverflow.ellipsis),
          ),
        )
        .toList();
  }

  Widget _filters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: biruTua.withValues(alpha: .045),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _search,
            onChanged: (value) {
              setState(() {
                _query = value.trim().toLowerCase();
              });
            },
            decoration: InputDecoration(
              hintText: 'Cari deskripsi, ID, jenis, dampak, atau solusi...',
              prefixIcon: const Icon(Icons.search, color: biru),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _search.clear();
                        setState(() {
                          _query = '';
                        });
                      },
                    ),
              filled: true,
              fillColor: latar,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth;

              final width = maxWidth >= 700
                  ? (maxWidth - 36) / 4
                  : maxWidth >= 430
                  ? (maxWidth - 12) / 2
                  : maxWidth;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: width,
                    child: _dropdown(
                      'Status',
                      _status,
                      _items({
                        'semua': 'Semua Status',
                        'menunggu_review': 'Menunggu Review',
                        'dalam_penanganan': 'Dalam Penanganan',
                        'menunggu_konfirmasi': 'Menunggu Konfirmasi',
                        'selesai': 'Selesai',
                        'ditolak': 'Ditolak',
                      }),
                      (value) {
                        setState(() {
                          _status = value ?? 'semua';
                        });
                      },
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _dropdown(
                      'Jenis Kendala',
                      _jenis,
                      _items({
                        'semua': 'Semua Jenis',
                        'internal': 'Internal',
                        'eksternal': 'Eksternal',
                      }),
                      (value) {
                        setState(() {
                          _jenis = value ?? 'semua';
                        });
                      },
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _dropdown(
                      'Prioritas',
                      _prioritas,
                      _items({
                        'semua': 'Semua Prioritas',
                        'tinggi': 'Tinggi',
                        'sedang': 'Sedang',
                        'rendah': 'Rendah',
                      }),
                      (value) {
                        setState(() {
                          _prioritas = value ?? 'semua';
                        });
                      },
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _dropdown(
                      'Urutkan',
                      _urut,
                      _items({
                        'terbaru': 'Tanggal Terbaru',
                        'terlama': 'Tanggal Terlama',
                        'prioritas': 'Prioritas Tertinggi',
                        'status': 'Status A–Z',
                      }),
                      (value) {
                        setState(() {
                          _urut = value ?? 'terbaru';
                        });
                      },
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.restart_alt, size: 18),
              label: const Text('Reset Filter'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String title, int count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: .12)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .09),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                Text(
                  title,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _reportCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

    final status = _value(data, 'status', StatusLaporanKendala.menungguReview);

    final statusColor = _statusColor(status);

    final isTerminal = _isTerminalStatus(status);

    return FutureBuilder<Map<String, String>>(
      future: _details(doc.id, data),
      builder: (context, snapshot) {
        final info = snapshot.data;

        final title = info?['tugas'] ?? 'Memuat nama tugas...';

        final staff = info?['nama'] ?? 'Memuat nama staff...';

        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(17),
          child: InkWell(
            borderRadius: BorderRadius.circular(17),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      DetailLaporanKendalaAdminPage(laporanId: doc.id),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: const Color(0xFFE5EAF4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: biruTua,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _pill(StatusLaporanKendala.label(status), statusColor),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.person_outline,
                        size: 16,
                        color: Colors.blueGrey,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          staff,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.access_time,
                        size: 15,
                        color: Colors.blueGrey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _tanggal(_date(data)),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _value(data, 'deskripsi'),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF39465E),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 13),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _pill('Jenis: ${_value(data, 'jenis_kendala')}', biru),
                      _pill(
                        'Prioritas: ${_value(data, 'prioritas')}',
                        const Color(0xFFCA6D00),
                      ),
                      if (_value(data, 'bukti_path', '').isNotEmpty ||
                          _value(data, 'bukti_url', '').isNotEmpty)
                        _pill('Ada lampiran', const Color(0xFF0C7C82)),
                      if (isTerminal)
                        _pill('Riwayat 3 hari', const Color(0xFF64748B)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        isTerminal ? 'Lihat Detail' : 'Lihat & Tangani',
                        style: const TextStyle(
                          color: biru,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: biru, size: 20),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  int _priority(String value) {
    switch (value.toLowerCase()) {
      case 'tinggi':
        return 3;
      case 'sedang':
        return 2;
      default:
        return 1;
    }
  }

  void _sortReports(List<QueryDocumentSnapshot<Map<String, dynamic>>> reports) {
    reports.sort((a, b) {
      final x = a.data();
      final y = b.data();

      if (_urut == 'prioritas') {
        final result = _priority(
          _value(y, 'prioritas'),
        ).compareTo(_priority(_value(x, 'prioritas')));

        if (result != 0) return result;
      }

      if (_urut == 'status') {
        final result = _value(x, 'status').compareTo(_value(y, 'status'));

        if (result != 0) return result;
      }

      final result = _date(y).compareTo(_date(x));

      return _urut == 'terlama' ? -result : result;
    });
  }

  Widget _empty(String message, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(35),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: biru, size: 45),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.blueGrey),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> semuaLaporan,
    Map<String, Map<String, dynamic>> assignments,
  ) {
    // Hanya data yang memenuhi aturan masa tampil.
    final all = semuaLaporan.where((report) {
      return _laporanDitampilkan(report, assignments);
    }).toList();

    final pending = all.where((doc) {
      return doc.data()['status'] == StatusLaporanKendala.menungguReview;
    }).length;

    final handling = all.where((doc) {
      return doc.data()['status'] == StatusLaporanKendala.dalamPenanganan;
    }).length;

    final confirm = all.where((doc) {
      return doc.data()['status'] == StatusLaporanKendala.menungguKonfirmasi;
    }).length;

    // PENTING:
    // Statistik selesai dihitung dari SEMUA
    // laporan yang statusnya selesai.
    // Tidak dibatasi masa tampil 3 hari.
    final done = semuaLaporan.where((doc) {
      return doc.data()['status'] == StatusLaporanKendala.selesai;
    }).length;

    final filtered = all.where((doc) {
      return _matches(doc.data(), doc.id);
    }).toList();

    _sortReports(filtered);

    return RefreshIndicator(
      onRefresh: () async {
        _detailsCache.clear();

        if (mounted) {
          setState(() {});
        }

        await Future<void>.delayed(const Duration(milliseconds: 300));
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Monitoring & Penanganan',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: biruTua,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Pantau laporan kendala yang dikirim staff dan berikan solusi.',
                    style: TextStyle(color: Colors.blueGrey, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.info_outline, color: biru, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Laporan selesai dan ditolak '
                          'ditampilkan selama '
                          '${masaTampilSelesai.inDays} hari. '
                          'Riwayat tetap tersimpan.',
                          style: const TextStyle(
                            color: Colors.blueGrey,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 700 ? 4 : 2;

                      final width =
                          (constraints.maxWidth - (columns - 1) * 10) / columns;

                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          SizedBox(
                            width: width,
                            child: _statCard(
                              'Menunggu Review',
                              pending,
                              Icons.pending_actions,
                              const Color(0xFFB96B00),
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: _statCard(
                              'Dalam Penanganan',
                              handling,
                              Icons.build_circle_outlined,
                              biru,
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: _statCard(
                              'Menunggu Konfirmasi',
                              confirm,
                              Icons.fact_check_outlined,
                              const Color(0xFF7C3AED),
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: _statCard(
                              'Selesai',
                              done,
                              Icons.check_circle_outline,
                              const Color(0xFF15803D),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  _filters(),
                  const SizedBox(height: 19),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Daftar Laporan (${filtered.length})',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: biruTua,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (filtered.isEmpty)
                    _empty(
                      'Tidak ada laporan yang sesuai filter.',
                      Icons.inbox_outlined,
                    )
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final two = constraints.maxWidth >= 800;

                        final width = two
                            ? (constraints.maxWidth - 14) / 2
                            : constraints.maxWidth;

                        return Wrap(
                          spacing: 14,
                          runSpacing: 14,
                          children: [
                            for (final doc in filtered)
                              SizedBox(width: width, child: _reportCard(doc)),
                          ],
                        );
                      },
                    ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: latar,
      appBar: AppBar(
        title: const Text(
          'Laporan Kendala',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        foregroundColor: Colors.white,
        backgroundColor: biruTua,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _assignmentStream,
        builder: (context, assignmentsSnapshot) {
          if (assignmentsSnapshot.hasError) {
            return Center(
              child: Text(
                'Gagal memuat penugasan: '
                '${assignmentsSnapshot.error}',
              ),
            );
          }

          if (!assignmentsSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final assignments = <String, Map<String, dynamic>>{
            for (final doc in assignmentsSnapshot.data!.docs)
              doc.id: doc.data(),
          };

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _reportStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Gagal memuat laporan: '
                    '${snapshot.error}',
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              return _buildContent(snapshot.data!.docs, assignments);
            },
          );
        },
      ),
    );
  }
}

/// Halaman detail laporan kendala admin.
class DetailLaporanKendalaAdminPage extends StatefulWidget {
  final String laporanId;

  const DetailLaporanKendalaAdminPage({super.key, required this.laporanId});

  @override
  State<DetailLaporanKendalaAdminPage> createState() =>
      _DetailLaporanKendalaAdminPageState();
}

class _DetailLaporanKendalaAdminPageState
    extends State<DetailLaporanKendalaAdminPage> {
  static const Color biruTua = Color(0xFF0011CC);
  static const Color biru = Color(0xFF0066FF);
  static const Color latar = Color(0xFFF5F7FC);

  final _service = LaporanKendalaService();
  final _db = FirebaseFirestore.instance;
  final _storageService = SupabaseStorageService();

  bool _loadingBukti = false;
  bool _saving = false;

  Future<Map<String, String>>? _identity;

  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _detailStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _assignmentStream;

  @override
  void initState() {
    super.initState();

    _detailStream = _service.streamDetail(widget.laporanId);

    _assignmentStream = _db.collection('penugasan').snapshots();
  }

  Future<Map<String, String>> _loadIdentity(Map<String, dynamic> data) async {
    final staffId = (data['pelapor_id'] ?? '').toString();

    final taskId = (data['tugas_id'] ?? '').toString();

    final staff = staffId.isEmpty
        ? null
        : await _db.collection('users').doc(staffId).get();

    final task = taskId.isEmpty
        ? null
        : await _db.collection('tugas').doc(taskId).get();

    return {
      'staff': (staff?.data()?['nama'] ?? 'Staff').toString(),
      'tugas': (task?.data()?['judul'] ?? 'Tugas tidak ditemukan').toString(),
    };
  }

  String _v(Map<String, dynamic> data, String key) {
    final value = (data[key] ?? '').toString().trim();

    return value.isEmpty ? '-' : value;
  }

  String _date(dynamic value) {
    if (value is! Timestamp) return '-';

    final date = value.toDate();

    String two(int n) => n.toString().padLeft(2, '0');

    return '${two(date.day)}/${two(date.month)}/'
        '${date.year} ${two(date.hour)}:'
        '${two(date.minute)}';
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.blueGrey,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF23304A),
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFE8EDF6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: biruTua,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Divider(height: 24),
          ...children,
        ],
      ),
    );
  }

  Future<String?> _askText({
    required String title,
    required String hint,
  }) async {
    final controller = TextEditingController();

    try {
      return await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLines: 5,
              minLines: 3,
              decoration: InputDecoration(
                hintText: hint,
                border: const OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () {
                  final text = controller.text.trim();

                  if (text.isEmpty) return;

                  Navigator.pop(dialogContext, text);
                },
                child: const Text('Kirim'),
              ),
            ],
          );
        },
      );
    } finally {
      // Ditunda sampai animasi dialog selesai.
      Future<void>.delayed(
        const Duration(milliseconds: 300),
        controller.dispose,
      );
    }
  }

  Future<void> _action(Future<void> Function() work) async {
    if (_saving) return;

    setState(() {
      _saving = true;
    });

    try {
      await work();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Status laporan berhasil diperbarui.')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memproses laporan: $error'),
          duration: const Duration(seconds: 7),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Widget _button(
    String text,
    IconData icon,
    VoidCallback? onTap, {
    bool outlined = false,
    Color? color,
  }) {
    final buttonColor = color ?? biru;

    if (outlined) {
      return OutlinedButton.icon(
        onPressed: _saving ? null : onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: buttonColor,
          side: BorderSide(color: buttonColor),
          padding: const EdgeInsets.all(14),
        ),
        icon: Icon(icon),
        label: Text(text),
      );
    }

    return FilledButton.icon(
      onPressed: _saving ? null : onTap,
      style: FilledButton.styleFrom(
        backgroundColor: buttonColor,
        padding: const EdgeInsets.all(14),
      ),
      icon: Icon(icon),
      label: Text(text),
    );
  }

  Widget _riwayatLaporan() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db.collection('laporan_kendala').doc(widget.laporanId)
          .collection('riwayat').orderBy('created_at', descending: false).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return _section('Riwayat Kendala', [Text('Gagal memuat riwayat: ${snapshot.error}')]);
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return _section('Riwayat Kendala', [
          const Text('Belum ada laporan lanjutan. Laporan awal dan solusi terkini tersedia di bagian atas.'),
        ]);
        return _section('Riwayat Kendala Sebelumnya', [
          ...docs.asMap().entries.map((entry) {
            final d = entry.value.data();
            final stamp = d['created_at'];
            final tanggal = stamp is Timestamp ? stamp.toDate().toLocal().toString().substring(0, 16) : '-';
            final file = (d['solusi_file_path'] ?? '').toString();
            return Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Putaran ${entry.key + 1} • $tanggal', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('Kendala: ${d['deskripsi_sebelumnya'] ?? '-'}'),
                Text('Dampak: ${d['dampak_sebelumnya'] ?? '-'}'),
                Text('Solusi Atasan: ${d['solusi_sebelumnya'] ?? '-'}'),
                Text('Tanggapan Staff: ${d['feedback'] ?? '-'}'),
                if (file.isNotEmpty) const Text('Lampiran solusi sebelumnya tercatat di riwayat.'),
              ],
            )));
          }),
        ]);
      },
    );
  }

  Future<void> _formSolusi({required bool edit}) async {
    final current = await _db.collection('laporan_kendala').doc(widget.laporanId).get();
    final data = current.data() ?? {};
    final controller = TextEditingController(text: edit ? (data['solusi'] ?? '').toString() : '');
    PlatformFile? file;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (ctx, update) => AlertDialog(
        title: Text(edit ? 'Edit Solusi' : 'Kirim Solusi'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: controller, maxLines: 4, decoration: const InputDecoration(labelText: 'Keterangan solusi (wajib)')),
          const SizedBox(height: 10),
          OutlinedButton.icon(onPressed: () async {
            final picked = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: const ['pdf','jpg','jpeg','png','docx']);
            if (picked != null) update(() => file = picked);
          }, icon: const Icon(Icons.attach_file), label: Text(file?.name ?? 'Lampiran solusi (opsional)')),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(onPressed: () {
            if (controller.text.trim().isEmpty) return;
            Navigator.pop(ctx, {'solusi': controller.text.trim(), 'file': file});
          }, child: const Text('Simpan'))],
      )),
    );
    controller.dispose();
    if (result == null) return;
    await _action(() async {
      String? path;
      String? name;
      final picked = result['file'] as PlatformFile?;
      if (picked != null) {
        final uploaded = await _storageService.uploadHasilTugas(
          tugasId: 'solusi_${widget.laporanId}', namaFile: picked.name,
          bytes: await picked.readAsBytes(), contentType: SupabaseStorageService.mimeTypeDariNama(picked.name));
        path = uploaded.path;
        name = picked.name;
      }
      if (edit) {
        await _service.editSolusi(laporanId: widget.laporanId, solusi: result['solusi'] as String, filePath: path, fileNama: name);
      } else {
        await _service.kirimSolusi(laporanId: widget.laporanId, solusi: result['solusi'] as String, filePath: path ?? '', fileNama: name ?? '');
      }
    });
  }

  Widget _actions(String status, {required bool isActiveAssignment}) {
    final id = widget.laporanId;

    final canHandle =
        isActiveAssignment &&
        (status == StatusLaporanKendala.menungguReview ||
            status == StatusLaporanKendala.dalamPenanganan);

    if (!canHandle) {
      if (status == StatusLaporanKendala.selesai) {
        return const Text(
          'Laporan telah diselesaikan '
          'dan dikonfirmasi staff.',
          style: TextStyle(
            color: Color(0xFF15803D),
            fontWeight: FontWeight.w600,
          ),
        );
      }

      if (status == StatusLaporanKendala.ditolak) {
        return const Text(
          'Laporan telah ditolak. '
          'Data tetap tersimpan sebagai riwayat.',
          style: TextStyle(
            color: Color(0xFFB42318),
            fontWeight: FontWeight.w600,
          ),
        );
      }

      if (status == StatusLaporanKendala.menungguKonfirmasi &&
          isActiveAssignment) {
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Solusi telah dikirim. Menunggu konfirmasi Staff.'),
          const SizedBox(height: 8),
          _button('Edit Solusi', Icons.edit_outlined, () => _formSolusi(edit: true)),
        ]);
      }

      return const Text(
        'Laporan tidak dapat diproses '
        'karena penugasan sudah tidak '
        'berstatus terkendala atau '
        'laporan ini bukan kendala aktif.',
        style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.w600),
      );
    }

    if (status == StatusLaporanKendala.menungguReview) {
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _button('Terima & Tangani', Icons.handyman_outlined, () {
            _action(() => _service.mulaiPenanganan(id));
          }),
          _button(
            'Tolak Laporan',
            Icons.block_outlined,
            () async {
              final reason = await _askText(
                title: 'Alasan Penolakan',
                hint: 'Jelaskan mengapa laporan ditolak...',
              );

              if (reason != null) {
                await _action(
                  () => _service.tolakLaporan(laporanId: id, alasan: reason),
                );
              }
            },
            outlined: true,
            color: const Color(0xFFB42318),
          ),
        ],
      );
    }

    if (status == StatusLaporanKendala.dalamPenanganan) {
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _button('Kirim Solusi', Icons.send_outlined, () => _formSolusi(edit: false)),
          _button(
            'Tolak Laporan',
            Icons.block_outlined,
            () async {
              final reason = await _askText(
                title: 'Alasan Penolakan',
                hint: 'Jelaskan mengapa laporan ditolak...',
              );

              if (reason != null) {
                await _action(
                  () => _service.tolakLaporan(laporanId: id, alasan: reason),
                );
              }
            },
            outlined: true,
            color: const Color(0xFFB42318),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Future<void> _lihatBukti(Map<String, dynamic> data) async {
    if (_loadingBukti) return;

    final path = (data['bukti_path'] ?? '').toString().trim();

    if (path.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lampiran bukti tidak ditemukan.')),
      );
      return;
    }

    setState(() {
      _loadingBukti = true;
    });

    try {
      // Mengambil signed URL melalui Edge Function.
      final signedUrl = await _storageService.ambilLinkBuktiKendala(
        widget.laporanId,
      );

      if (!mounted) return;

      // Identifikasi jenis file dari path asli,
      // bukan dari signed URL yang memiliki query token.
      final namaFile = Uri.decodeComponent(path.split('/').last);

      final extension = namaFile.split('.').last.toLowerCase();

      final isPdf = extension == 'pdf';

      final isImage = ['png', 'jpg', 'jpeg'].contains(extension);

      if (!isPdf && !isImage) {
        throw Exception('Format file tidak didukung untuk preview.');
      }

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          final screenSize = MediaQuery.sizeOf(dialogContext);

          return Dialog(
            insetPadding: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: SizedBox(
              width: screenSize.width > 900 ? 850 : screenSize.width * 0.95,
              height: screenSize.height * 0.85,
              child: Column(
                children: [
                  // Header preview
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xFF0011CC),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isPdf
                              ? Icons.picture_as_pdf_outlined
                              : Icons.image_outlined,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            namaFile,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                          },
                          icon: const Icon(Icons.close, color: Colors.white),
                          tooltip: 'Tutup',
                        ),
                      ],
                    ),
                  ),

                  // Konten preview
                  Expanded(
                    child: isPdf
                        ? SfPdfViewer.network(
                            signedUrl,
                            canShowScrollHead: true,
                            canShowPaginationDialog: true,
                          )
                        : InteractiveViewer(
                            minScale: 0.5,
                            maxScale: 5,
                            child: Center(
                              child: Image.network(
                                signedUrl,
                                fit: BoxFit.contain,
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                      if (loadingProgress == null) {
                                        return child;
                                      }

                                      return const Center(
                                        child: CircularProgressIndicator(),
                                      );
                                    },
                                errorBuilder: (context, error, stackTrace) {
                                  return const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(20),
                                      child: Text(
                                        'Gagal menampilkan gambar. '
                                        'Periksa akses file atau '
                                        'koneksi internet.',
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membuka bukti: $e'),
          duration: const Duration(seconds: 7),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingBukti = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: latar,
      appBar: AppBar(
        title: const Text('Detail Laporan Kendala'),
        backgroundColor: biruTua,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _detailStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Gagal memuat laporan: '
                '${snapshot.error}',
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.data!.exists) {
            return const Center(child: Text('Laporan tidak ditemukan.'));
          }

          final data = snapshot.data!.data()!;

          _identity ??= _loadIdentity(data);

          final status = _v(data, 'status');

          final assignmentId = (data['penugasan_id'] ?? '').toString();

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _assignmentStream,
            builder: (context, assignmentSnapshot) {
              if (assignmentSnapshot.hasError) {
                return Center(
                  child: Text(
                    'Gagal memuat status penugasan: '
                    '${assignmentSnapshot.error}',
                  ),
                );
              }

              if (!assignmentSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              Map<String, dynamic>? assignment;

              for (final doc in assignmentSnapshot.data!.docs) {
                if (doc.id == assignmentId) {
                  assignment = doc.data();
                  break;
                }
              }

              final assignmentStatus = (assignment?['status'] ?? '').toString();

              final activeId = (assignment?['kendala_aktif_id'] ?? '')
                  .toString();

              final isActiveAssignment =
                  assignmentStatus == 'terkendala' &&
                  (activeId.isEmpty || activeId == widget.laporanId);

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _section('Informasi Laporan', [
                            _line('Status', StatusLaporanKendala.label(status)),
                            _line(
                              'Status Penugasan',
                              assignmentStatus.isEmpty ? '-' : assignmentStatus,
                            ),
                            _line(
                              'Tanggal Laporan',
                              _date(
                                data['tanggal_laporan'] ?? data['created_at'],
                              ),
                            ),
                            FutureBuilder<Map<String, String>>(
                              future: _identity,
                              builder: (context, identitySnapshot) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _line(
                                      'Staff Pelapor',
                                      identitySnapshot.data?['staff'] ??
                                          'Memuat...',
                                    ),
                                    _line(
                                      'Tugas',
                                      identitySnapshot.data?['tugas'] ??
                                          'Memuat...',
                                    ),
                                  ],
                                );
                              },
                            ),
                            _line('Jenis Kendala', _v(data, 'jenis_kendala')),
                            _line('Prioritas', _v(data, 'prioritas')),
                            _line('Deskripsi Kendala', _v(data, 'deskripsi')),
                            _line('Dampak terhadap Tugas', _v(data, 'dampak')),
                          ]),
                          _section('Penanganan', [
                            _line('Solusi dari Atasan', _v(data, 'solusi')),
                            if (_v(data, 'alasan_penolakan') != '-')
                              _line(
                                'Alasan Penolakan',
                                _v(data, 'alasan_penolakan'),
                              ),
                            FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                              future: _db.collection('users').doc((data['ditangani_oleh'] ?? '').toString()).get(),
                              builder: (context, snapshot) {
                                final profile = snapshot.data?.data();
                                final nama = (profile?['nama'] ?? '').toString().trim();
                                final jabatan = (profile?['jabatan'] ?? '').toString().trim();
                                return _line('Atasan Penanganan', nama.isEmpty
                                    ? 'Belum ada Atasan yang menangani'
                                    : '$nama${jabatan.isEmpty ? '' : ' — $jabatan'}');
                              },
                            ),
                            _line(
                              'Pembaruan Terakhir',
                              _date(data['updated_at']),
                            ),
                            if (data['resolved_at'] != null)
                              _line(
                                'Tanggal Selesai',
                                _date(data['resolved_at']),
                              ),
                            if (data['rejected_at'] != null)
                              _line(
                                'Tanggal Ditolak',
                                _date(data['rejected_at']),
                              ),
                          ]),

                          _riwayatLaporan(),

                          if (_v(data, 'bukti_path') != '-' ||
                              _v(data, 'bukti_url') != '-')
                            _section('Lampiran Bukti', [
                              const Text(
                                'Lampiran bukti yang dikirim oleh staff '
                                'dapat dilihat melalui tombol berikut.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.blueGrey,
                                ),
                              ),

                              const SizedBox(height: 14),

                              _line('Provider', _v(data, 'bukti_provider')),

                              _line(
                                'Nama File',
                                _v(data, 'bukti_path') == '-'
                                    ? '-'
                                    : _v(data, 'bukti_path').split('/').last,
                              ),

                              const SizedBox(height: 4),

                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed:
                                      _loadingBukti ||
                                          _v(data, 'bukti_path') == '-'
                                      ? null
                                      : () => _lihatBukti(data),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: biru,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 15,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon: _loadingBukti
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.visibility_outlined),
                                  label: Text(
                                    _loadingBukti
                                        ? 'Memuat Bukti...'
                                        : 'Lihat Bukti',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ]),

                          _section('Tindakan Admin', [
                            if (_saving) const LinearProgressIndicator(),
                            const SizedBox(height: 8),
                            _actions(
                              status,
                              isActiveAssignment: isActiveAssignment,
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
