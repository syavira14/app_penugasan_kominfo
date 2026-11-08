import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../services/laporan_kendala_service.dart';
import '../../services/supabase_storage_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_header.dart';
import 'admin_sidebar.dart';

// ============================================================
// HALAMAN DAFTAR LAPORAN KENDALA ADMIN
// ============================================================

class LaporanKendalaAdminPage extends StatefulWidget {
  const LaporanKendalaAdminPage({super.key});

  @override
  State<LaporanKendalaAdminPage> createState() =>
      _LaporanKendalaAdminPageState();
}

class _LaporanKendalaAdminPageState extends State<LaporanKendalaAdminPage> {
  static const Color _navy = AppPalette.navy;
  static const Color _blue = AppPalette.blue;
  static const Color _background = AppPalette.background;
  static const int _sidebarIndex = 6;
  static const Duration _masaTampil = Duration(days: 3);

  final _db = FirebaseFirestore.instance;
  final _service = LaporanKendalaService();
  final _searchController = TextEditingController();

  final Map<String, Future<Map<String, String>>> _detailCache = {};

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _assignmentStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _reportStream;

  Timer? _timer;

  String _query = '';
  String _status = 'semua';
  String _jenis = 'semua';
  String _prioritas = 'semua';
  String _urut = 'terbaru';

  @override
  void initState() {
    super.initState();

    _assignmentStream = _db.collection('penugasan').snapshots();

    _reportStream = _service.streamSemuaLaporan();

    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _searchController.dispose();
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

  DateTime? _dateOf(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String _tanggal(dynamic value) {
    final date = _dateOf(value);
    if (date == null) return '-';

    String two(int n) => n.toString().padLeft(2, '0');

    return '${two(date.day)}/${two(date.month)}/'
        '${date.year} ${two(date.hour)}:${two(date.minute)}';
  }

  bool _active(String status) {
    return status == StatusLaporanKendala.menungguReview ||
        status == StatusLaporanKendala.dalamPenanganan ||
        status == StatusLaporanKendala.menungguKonfirmasi;
  }

  bool _terminal(String status) {
    return status == StatusLaporanKendala.selesai ||
        status == StatusLaporanKendala.ditolak;
  }

  DateTime? _processedAt(Map<String, dynamic> data) {
    final status = _value(data, 'status', '');

    if (status == StatusLaporanKendala.selesai) {
      return _dateOf(data['resolved_at'] ?? data['updated_at']);
    }

    if (status == StatusLaporanKendala.ditolak) {
      return _dateOf(data['rejected_at'] ?? data['updated_at']);
    }

    return null;
  }

  bool _visible(
    QueryDocumentSnapshot<Map<String, dynamic>> report,
    Map<String, Map<String, dynamic>> assignments,
  ) {
    final data = report.data();
    final status = _value(data, 'status', '');
    final assignmentId = _value(data, 'penugasan_id', '');

    final assignment = assignments[assignmentId];
    if (assignment == null) return false;

    if (_active(status)) {
      if (_value(assignment, 'status', '') != 'terkendala') {
        return false;
      }

      final activeId = _value(assignment, 'kendala_aktif_id', '');

      return activeId.isEmpty || activeId == report.id;
    }

    if (_terminal(status)) {
      final processed = _processedAt(data);
      if (processed == null) return false;

      final now = DateTime.now();

      return !processed.isAfter(now) &&
          now.isBefore(processed.add(_masaTampil));
    }

    return false;
  }

  Color _statusColor(String status) {
    switch (status) {
      case StatusLaporanKendala.menungguReview:
        return const Color(0xFFB96B00);
      case StatusLaporanKendala.dalamPenanganan:
        return _blue;
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

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<Map<String, String>> _loadDetail(Map<String, dynamic> data) async {
    final staffId = _value(data, 'pelapor_id', '');
    final tugasId = _value(data, 'tugas_id', '');

    String nama = _value(data, 'nama_staf', 'Staff');
    String tugas = _value(data, 'judul_tugas', 'Tugas tidak ditemukan');

    if (staffId.isNotEmpty) {
      final staff = await _db.collection('users').doc(staffId).get();

      if (staff.exists) {
        nama = _value(staff.data()!, 'nama', nama);
      }
    }

    if (tugasId.isNotEmpty) {
      final task = await _db.collection('tugas').doc(tugasId).get();

      if (task.exists) {
        tugas = _value(task.data()!, 'judul', tugas);
      }
    }

    return {'nama': nama, 'tugas': tugas};
  }

  Future<Map<String, String>> _details(String id, Map<String, dynamic> data) {
    return _detailCache.putIfAbsent(id, () => _loadDetail(data));
  }

  void _reset() {
    _searchController.clear();

    setState(() {
      _query = '';
      _status = 'semua';
      _jenis = 'semua';
      _prioritas = 'semua';
      _urut = 'terbaru';
    });
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

    final searchable = [
      id,
      ...data.values.map((v) => v is Timestamp ? '' : v.toString()),
    ].join(' ').toLowerCase();

    return searchable.contains(_query);
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

  void _sort(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    docs.sort((a, b) {
      final x = a.data();
      final y = b.data();

      if (_urut == 'prioritas') {
        final comparison = _priority(
          _value(y, 'prioritas'),
        ).compareTo(_priority(_value(x, 'prioritas')));

        if (comparison != 0) return comparison;
      }

      if (_urut == 'status') {
        final comparison = _value(x, 'status').compareTo(_value(y, 'status'));

        if (comparison != 0) return comparison;
      }

      final xDate = _dateOf(x['tanggal_laporan'] ?? x['created_at']);

      final yDate = _dateOf(y['tanggal_laporan'] ?? y['created_at']);

      final comparison = (yDate ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(xDate ?? DateTime.fromMillisecondsSinceEpoch(0));

      return _urut == 'terlama' ? -comparison : comparison;
    });
  }

  Widget _statCard(String label, int count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  label,
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

  Widget _dropdown(
    String label,
    String value,
    Map<String, String> options,
    ValueChanged<String?> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: options.entries.map((entry) {
        return DropdownMenuItem(
          value: entry.key,
          child: Text(
            entry.value,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _filters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() {
                _query = value.trim().toLowerCase();
              });
            },
            decoration: InputDecoration(
              hintText: 'Cari laporan, tugas, jenis, atau kendala...',
              prefixIcon: const Icon(Icons.search_rounded, color: _blue),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    ),
              filled: true,
              fillColor: _background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth >= 700
                  ? (constraints.maxWidth - 36) / 4
                  : constraints.maxWidth >= 430
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: width,
                    child: _dropdown('Status', _status, {
                      'semua': 'Semua Status',
                      StatusLaporanKendala.menungguReview: 'Menunggu Review',
                      StatusLaporanKendala.dalamPenanganan: 'Dalam Penanganan',
                      StatusLaporanKendala.menungguKonfirmasi:
                          'Menunggu Konfirmasi',
                      StatusLaporanKendala.selesai: 'Selesai',
                      StatusLaporanKendala.ditolak: 'Ditolak',
                    }, (v) => setState(() => _status = v ?? 'semua')),
                  ),
                  SizedBox(
                    width: width,
                    child: _dropdown('Jenis Kendala', _jenis, {
                      'semua': 'Semua Jenis',
                      'internal': 'Internal',
                      'eksternal': 'Eksternal',
                    }, (v) => setState(() => _jenis = v ?? 'semua')),
                  ),
                  SizedBox(
                    width: width,
                    child: _dropdown('Prioritas', _prioritas, {
                      'semua': 'Semua Prioritas',
                      'tinggi': 'Tinggi',
                      'sedang': 'Sedang',
                      'rendah': 'Rendah',
                    }, (v) => setState(() => _prioritas = v ?? 'semua')),
                  ),
                  SizedBox(
                    width: width,
                    child: _dropdown('Urutkan', _urut, {
                      'terbaru': 'Tanggal Terbaru',
                      'terlama': 'Tanggal Terlama',
                      'prioritas': 'Prioritas Tertinggi',
                      'status': 'Status A–Z',
                    }, (v) => setState(() => _urut = v ?? 'terbaru')),
                  ),
                ],
              );
            },
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reset Filter'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reportCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final status = _value(data, 'status', StatusLaporanKendala.menungguReview);

    return FutureBuilder<Map<String, String>>(
      future: _details(doc.id, data),
      builder: (context, snapshot) {
        final info = snapshot.data;

        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
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
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE5EAF4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          info?['tugas'] ?? 'Memuat nama tugas...',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _navy,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _pill(
                        StatusLaporanKendala.label(status),
                        _statusColor(status),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
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
                          info?['nama'] ?? 'Memuat staff...',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      Text(
                        _tanggal(data['tanggal_laporan'] ?? data['created_at']),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.blueGrey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _value(
                      data,
                      'deskripsi',
                      _value(data, 'deskripsi_kendala'),
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      height: 1.4,
                      color: Color(0xFF39465E),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _pill('Jenis: ${_value(data, 'jenis_kendala')}', _blue),
                      _pill(
                        'Prioritas: ${_value(data, 'prioritas')}',
                        const Color(0xFFCA6D00),
                      ),
                      if (_value(data, 'bukti_path', '').isNotEmpty ||
                          _value(data, 'bukti_url', '').isNotEmpty)
                        _pill('Ada Lampiran', const Color(0xFF0C7C82)),
                      if (_terminal(status))
                        _pill('Riwayat 3 Hari', Colors.blueGrey),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'Lihat Detail',
                        style: TextStyle(
                          color: _blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Icon(Icons.chevron_right, color: _blue),
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

  Widget _content(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> reports,
    Map<String, Map<String, dynamic>> assignments,
  ) {
    final visible = reports.where((doc) => _visible(doc, assignments)).toList();

    final pending = visible
        .where((d) => d.data()['status'] == StatusLaporanKendala.menungguReview)
        .length;

    final handling = visible
        .where(
          (d) => d.data()['status'] == StatusLaporanKendala.dalamPenanganan,
        )
        .length;

    final confirming = visible
        .where(
          (d) => d.data()['status'] == StatusLaporanKendala.menungguKonfirmasi,
        )
        .length;

    // Statistik selesai dihitung dari seluruh laporan.
    final completed = reports
        .where((d) => d.data()['status'] == StatusLaporanKendala.selesai)
        .length;

    final filtered = visible
        .where((doc) => _matches(doc.data(), doc.id))
        .toList();

    _sort(filtered);

    return RefreshIndicator(
      onRefresh: () async {
        _detailCache.clear();
        if (mounted) setState(() {});
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
                      fontWeight: FontWeight.bold,
                      color: _navy,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Pantau laporan kendala staff dan berikan solusi.',
                    style: TextStyle(color: Colors.blueGrey),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Laporan selesai atau ditolak tampil selama '
                    '3 hari. Riwayat tetap tersimpan di Firebase.',
                    style: TextStyle(fontSize: 12, color: Colors.blueGrey),
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
                              _blue,
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: _statCard(
                              'Menunggu Konfirmasi',
                              confirming,
                              Icons.fact_check_outlined,
                              const Color(0xFF7C3AED),
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: _statCard(
                              'Selesai',
                              completed,
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
                  const SizedBox(height: 20),
                  Text(
                    'Daftar Laporan (${filtered.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _navy,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (filtered.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(36),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Column(
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            size: 44,
                            color: Colors.blueGrey,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Tidak ada laporan yang sesuai filter.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _assignmentStream,
      builder: (context, assignmentSnapshot) {
        if (assignmentSnapshot.hasError) {
          return Center(
            child: Text(
              'Gagal memuat penugasan: '
              '${assignmentSnapshot.error}',
            ),
          );
        }

        if (!assignmentSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final assignments = <String, Map<String, dynamic>>{
          for (final doc in assignmentSnapshot.data!.docs) doc.id: doc.data(),
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

            return _content(snapshot.data!.docs, assignments);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;

        return Scaffold(
          backgroundColor: _background,
          drawer: wide
              ? null
              : const AdminSidebar(currentIndex: _sidebarIndex, isDrawer: true),
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (wide) const AdminSidebar(currentIndex: _sidebarIndex),
              Expanded(
                child: Column(
                  children: [
                    AdminHeader(title: 'Laporan Kendala', showSidebar: wide),
                    Expanded(child: _body()),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================
// HALAMAN DETAIL LAPORAN KENDALA ADMIN
// ============================================================

class DetailLaporanKendalaAdminPage extends StatefulWidget {
  final String laporanId;

  const DetailLaporanKendalaAdminPage({super.key, required this.laporanId});

  @override
  State<DetailLaporanKendalaAdminPage> createState() =>
      _DetailLaporanKendalaAdminPageState();
}

class _DetailLaporanKendalaAdminPageState
    extends State<DetailLaporanKendalaAdminPage> {
  static const Color _navy = AppPalette.navy;
  static const Color _blue = AppPalette.blue;
  static const Color _background = AppPalette.background;

  final _db = FirebaseFirestore.instance;
  final _service = LaporanKendalaService();
  final _storageService = SupabaseStorageService();

  bool _saving = false;
  bool _loadingBukti = false;

  Future<Map<String, String>>? _identity;

  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _detailStream;

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _assignmentStream;

  @override
  void initState() {
    super.initState();

    _detailStream = _service.streamDetail(widget.laporanId);

    _assignmentStream = _db.collection('penugasan').snapshots();
  }

  String _value(
    Map<String, dynamic> data,
    String key, [
    String fallback = '-',
  ]) {
    final value = (data[key] ?? '').toString().trim();
    return value.isEmpty ? fallback : value;
  }

  String _tanggal(dynamic value) {
    if (value is! Timestamp) return '-';

    final date = value.toDate();

    String two(int n) => n.toString().padLeft(2, '0');

    return '${two(date.day)}/${two(date.month)}/'
        '${date.year} ${two(date.hour)}:${two(date.minute)}';
  }

  Future<Map<String, String>> _loadIdentity(Map<String, dynamic> data) async {
    final staffId = _value(data, 'pelapor_id', '');
    final taskId = _value(data, 'tugas_id', '');

    final staff = staffId.isEmpty
        ? null
        : await _db.collection('users').doc(staffId).get();

    final task = taskId.isEmpty
        ? null
        : await _db.collection('tugas').doc(taskId).get();

    return {
      'staff':
          staff?.data()?['nama']?.toString() ??
          _value(data, 'nama_staf', 'Staff'),
      'tugas':
          task?.data()?['judul']?.toString() ??
          _value(data, 'judul_tugas', 'Tugas tidak ditemukan'),
    };
  }

  void _snack(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
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
              height: 1.45,
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
      padding: const EdgeInsets.all(18),
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
              color: _navy,
              fontSize: 16,
              fontWeight: FontWeight.bold,
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

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            minLines: 3,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: hint,
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
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

    // Hindari dispose sebelum animasi dialog selesai.
    Future<void>.delayed(const Duration(milliseconds: 300), controller.dispose);

    return result;
  }

  Future<void> _action(Future<void> Function() work) async {
    if (_saving) return;

    setState(() => _saving = true);

    try {
      await work();

      if (!mounted) return;

      _snack('Laporan berhasil diperbarui.');
    } catch (e) {
      if (!mounted) return;

      _snack('Gagal memproses laporan: $e');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Widget _button(
    String label,
    IconData icon,
    VoidCallback? onPressed, {
    bool outlined = false,
    Color? color,
  }) {
    final buttonColor = color ?? _blue;

    if (outlined) {
      return OutlinedButton.icon(
        onPressed: _saving ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: buttonColor,
          side: BorderSide(color: buttonColor),
          padding: const EdgeInsets.all(14),
        ),
        icon: Icon(icon),
        label: Text(label),
      );
    }

    return FilledButton.icon(
      onPressed: _saving ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: buttonColor,
        padding: const EdgeInsets.all(14),
      ),
      icon: Icon(icon),
      label: Text(label),
    );
  }

  // ============================================================
  // RIWAYAT KENDALA
  // ============================================================

  Widget _riwayatLaporan() {
    final stream = _db
        .collection('laporan_kendala')
        .doc(widget.laporanId)
        .collection('riwayat')
        .orderBy('created_at')
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _section('Riwayat Kendala', [
            Text(
              'Gagal memuat riwayat: '
              '${snapshot.error}',
            ),
          ]);
        }

        if (!snapshot.hasData) {
          return _section('Riwayat Kendala', [
            const Center(child: CircularProgressIndicator()),
          ]);
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return _section('Riwayat Kendala', [
            const Text(
              'Belum ada laporan lanjutan. '
              'Informasi laporan saat ini tersedia '
              'pada bagian atas.',
            ),
          ]);
        }

        return _section('Riwayat Kendala Sebelumnya', [
          for (var i = 0; i < docs.length; i++)
            Builder(
              builder: (context) {
                final data = docs[i].data();

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Putaran ${i + 1} • '
                          '${_tanggal(data['created_at'])}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _navy,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _line('Kendala', _value(data, 'deskripsi_sebelumnya')),
                        _line('Dampak', _value(data, 'dampak_sebelumnya')),
                        _line(
                          'Solusi Atasan',
                          _value(data, 'solusi_sebelumnya'),
                        ),
                        _line('Tanggapan Staff', _value(data, 'feedback')),
                        if (_value(data, 'solusi_file_path', '').isNotEmpty)
                          const Text(
                            'Lampiran solusi sebelumnya '
                            'tercatat dalam riwayat.',
                            style: TextStyle(color: _blue, fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ]);
      },
    );
  }

  // ============================================================
  // KIRIM DAN EDIT SOLUSI
  // ============================================================

  Future<void> _formSolusi({required bool edit}) async {
    if (_saving) return;

    final current = await _db
        .collection('laporan_kendala')
        .doc(widget.laporanId)
        .get();

    if (!mounted) return;

    final data = current.data() ?? {};

    final controller = TextEditingController(
      text: edit ? (data['solusi'] ?? '').toString() : '',
    );

    PlatformFile? selectedFile;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text(edit ? 'Edit Solusi' : 'Kirim Solusi'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: controller,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Keterangan solusi (wajib)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await FilePicker.pickFile(
                          type: FileType.custom,
                          allowedExtensions: [
                            'pdf',
                            'jpg',
                            'jpeg',
                            'png',
                            'docx',
                          ],
                        );

                        if (picked == null) {
                          return;
                        }

                        setModalState(() {
                          selectedFile = picked;
                        });
                      },
                      icon: const Icon(Icons.attach_file),
                      label: Text(
                        selectedFile?.name ?? 'Lampiran solusi (opsional)',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: () {
                    final solusi = controller.text.trim();

                    if (solusi.isEmpty) return;

                    Navigator.pop(dialogContext, {
                      'solusi': solusi,
                      'file': selectedFile,
                    });
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );

    Future<void>.delayed(const Duration(milliseconds: 300), controller.dispose);

    if (result == null) return;

    await _action(() async {
      String? path;
      String? nama;

      final file = result['file'] as PlatformFile?;

      if (file != null) {
        final bytes = await file.readAsBytes();

        if (bytes == null) {
          throw StateError(
            'File tidak berhasil dibaca. '
            'Silakan pilih ulang lampiran.',
          );
        }

        final uploaded = await _storageService.uploadHasilTugas(
          tugasId: 'solusi_${widget.laporanId}',
          namaFile: file.name,
          bytes: bytes,
          contentType: SupabaseStorageService.mimeTypeDariNama(file.name),
        );

        path = uploaded.path;
        nama = file.name;
      }

      if (edit) {
        await _service.editSolusi(
          laporanId: widget.laporanId,
          solusi: result['solusi'] as String,
          filePath: path,
          fileNama: nama,
        );
      } else {
        await _service.kirimSolusi(
          laporanId: widget.laporanId,
          solusi: result['solusi'] as String,
          filePath: path ?? '',
          fileNama: nama ?? '',
        );
      }
    });
  }

  // ============================================================
  // TINDAKAN ADMIN
  // ============================================================

  Widget _actions(String status, {required bool isActiveAssignment}) {
    final id = widget.laporanId;

    final canHandle =
        isActiveAssignment &&
        (status == StatusLaporanKendala.menungguReview ||
            status == StatusLaporanKendala.dalamPenanganan);

    if (!canHandle) {
      if (status == StatusLaporanKendala.selesai) {
        return const Text(
          'Laporan telah diselesaikan dan '
          'dikonfirmasi Staff.',
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Solusi telah dikirim. '
              'Menunggu konfirmasi Staff.',
            ),
            const SizedBox(height: 10),
            _button(
              'Edit Solusi',
              Icons.edit_outlined,
              () => _formSolusi(edit: true),
            ),
          ],
        );
      }

      return const Text(
        'Laporan tidak dapat diproses karena '
        'penugasan tidak sedang terkendala '
        'atau laporan bukan kendala aktif.',
        style: TextStyle(color: Colors.blueGrey),
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
              final alasan = await _askText(
                title: 'Alasan Penolakan',
                hint: 'Masukkan alasan penolakan...',
              );

              if (alasan != null) {
                await _action(
                  () => _service.tolakLaporan(laporanId: id, alasan: alasan),
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
          _button(
            'Kirim Solusi',
            Icons.send_outlined,
            () => _formSolusi(edit: false),
          ),
          _button(
            'Tolak Laporan',
            Icons.block_outlined,
            () async {
              final alasan = await _askText(
                title: 'Alasan Penolakan',
                hint: 'Masukkan alasan penolakan...',
              );

              if (alasan != null) {
                await _action(
                  () => _service.tolakLaporan(laporanId: id, alasan: alasan),
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

  // ============================================================
  // PREVIEW LAMPIRAN BUKTI
  // ============================================================

  Future<void> _lihatBukti(Map<String, dynamic> data) async {
    if (_loadingBukti) return;

    final path = _value(data, 'bukti_path', '');

    if (path.isEmpty) {
      _snack('Lampiran bukti tidak ditemukan.');
      return;
    }

    setState(() => _loadingBukti = true);

    try {
      final signedUrl = await _storageService.ambilLinkBuktiKendala(
        widget.laporanId,
      );

      if (!mounted) return;

      final namaFile = Uri.decodeComponent(path.split('/').last);

      final extension = namaFile.split('.').last.toLowerCase();

      final isPdf = extension == 'pdf';

      final isImage = ['png', 'jpg', 'jpeg'].contains(extension);

      if (!isPdf && !isImage) {
        throw StateError('Format lampiran tidak mendukung preview.');
      }

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          final size = MediaQuery.sizeOf(dialogContext);

          return Dialog(
            insetPadding: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: SizedBox(
              width: size.width > 900 ? 850 : size.width * 0.95,
              height: size.height * 0.85,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: _navy,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isPdf ? Icons.picture_as_pdf : Icons.image_outlined,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            namaFile,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
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
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) {
                                    return child;
                                  }

                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return const Center(
                                    child: Text('Gagal menampilkan gambar.'),
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
      if (mounted) {
        _snack('Gagal membuka bukti: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _loadingBukti = false);
      }
    }
  }

  // ============================================================
  // KONTEN DETAIL
  // ============================================================

  Widget _detailContent(
    Map<String, dynamic> data,
    String assignmentStatus,
    bool isActiveAssignment,
  ) {
    final status = _value(data, 'status');

    _identity ??= _loadIdentity(data);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
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
                    _tanggal(data['tanggal_laporan'] ?? data['created_at']),
                  ),
                  FutureBuilder<Map<String, String>>(
                    future: _identity,
                    builder: (context, snapshot) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _line(
                            'Staff Pelapor',
                            snapshot.data?['staff'] ?? 'Memuat...',
                          ),
                          _line(
                            'Tugas',
                            snapshot.data?['tugas'] ?? 'Memuat...',
                          ),
                        ],
                      );
                    },
                  ),
                  _line('Jenis Kendala', _value(data, 'jenis_kendala')),
                  _line('Prioritas', _value(data, 'prioritas')),
                  _line(
                    'Deskripsi Kendala',
                    _value(
                      data,
                      'deskripsi',
                      _value(data, 'deskripsi_kendala'),
                    ),
                  ),
                  _line('Dampak terhadap Tugas', _value(data, 'dampak')),
                ]),
                _section('Penanganan', [
                  _line('Solusi dari Atasan', _value(data, 'solusi')),
                  if (_value(data, 'alasan_penolakan') != '-')
                    _line('Alasan Penolakan', _value(data, 'alasan_penolakan')),
                  FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    future: _value(data, 'ditangani_oleh', '').isEmpty
                        ? null
                        : _db
                              .collection('users')
                              .doc(_value(data, 'ditangani_oleh'))
                              .get(),
                    builder: (context, snapshot) {
                      final profile = snapshot.data?.data();

                      final nama = (profile?['nama'] ?? '').toString().trim();

                      final jabatan = (profile?['jabatan'] ?? '')
                          .toString()
                          .trim();

                      return _line(
                        'Atasan Penanganan',
                        nama.isEmpty
                            ? 'Belum ada Atasan yang menangani'
                            : '$nama'
                                  '${jabatan.isEmpty ? '' : ' — $jabatan'}',
                      );
                    },
                  ),
                  _line('Pembaruan Terakhir', _tanggal(data['updated_at'])),
                  if (data['resolved_at'] != null)
                    _line('Tanggal Selesai', _tanggal(data['resolved_at'])),
                  if (data['rejected_at'] != null)
                    _line('Tanggal Ditolak', _tanggal(data['rejected_at'])),
                ]),
                _riwayatLaporan(),
                if (_value(data, 'bukti_path', '').isNotEmpty ||
                    _value(data, 'bukti_url', '').isNotEmpty)
                  _section('Lampiran Bukti', [
                    const Text(
                      'Lampiran bukti yang dikirim '
                      'Staff dapat dilihat melalui '
                      'tombol berikut.',
                    ),
                    const SizedBox(height: 12),
                    _line('Provider', _value(data, 'bukti_provider')),
                    _line(
                      'Nama File',
                      _value(data, 'bukti_path', '').isEmpty
                          ? '-'
                          : _value(data, 'bukti_path').split('/').last,
                    ),
                    FilledButton.icon(
                      onPressed:
                          _loadingBukti ||
                              _value(data, 'bukti_path', '').isEmpty
                          ? null
                          : () => _lihatBukti(data),
                      style: FilledButton.styleFrom(
                        backgroundColor: _blue,
                        padding: const EdgeInsets.all(14),
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
                        _loadingBukti ? 'Memuat Bukti...' : 'Lihat Bukti',
                      ),
                    ),
                  ]),
                _section('Tindakan Admin', [
                  if (_saving) const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                  _actions(status, isActiveAssignment: isActiveAssignment),
                ]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _body() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _detailStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Gagal memuat laporan: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.data!.exists) {
          return const Center(child: Text('Laporan tidak ditemukan.'));
        }

        final data = snapshot.data!.data()!;

        final assignmentId = _value(data, 'penugasan_id', '');

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _assignmentStream,
          builder: (context, assignmentSnapshot) {
            if (assignmentSnapshot.hasError) {
              return Center(
                child: Text(
                  'Gagal memuat penugasan: '
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

            final activeId = (assignment?['kendala_aktif_id'] ?? '').toString();

            final isActiveAssignment =
                assignmentStatus == 'terkendala' &&
                (activeId.isEmpty || activeId == widget.laporanId);

            return _detailContent(data, assignmentStatus, isActiveAssignment);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;

        return Scaffold(
          backgroundColor: _background,
          drawer: wide
              ? null
              : const AdminSidebar(currentIndex: 6, isDrawer: true),
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (wide) const AdminSidebar(currentIndex: 6),
              Expanded(
                child: Column(
                  children: [
                    AdminHeader(
                      title: 'Detail Laporan Kendala',
                      showSidebar: wide,
                    ),
                    Expanded(child: _body()),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
