import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../services/laporan_kendala_service.dart';
import '../../services/staff_admin_api.dart';
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
  static const Color _sky = AppPalette.sky;
  static const Color _background = AppPalette.background;
  static const int _sidebarIndex = 6;

  final _db = FirebaseFirestore.instance;
  final _service = LaporanKendalaService();
  final _searchController = TextEditingController();

  final Map<String, Future<Map<String, String>>> _detailCache = {};

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _assignmentStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _reportStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _usersStream;

  Timer? _timer;

  String _query = '';
  String _status = 'semua';
  String _jenis = 'semua';
  String _prioritas = 'semua';
  String _urut = 'terbaru';
  String _selectedStaffId = 'semua';

  @override
  void initState() {
    super.initState();
    StaffAdminApi.cleanupOrphanedTugasData();
    _assignmentStream = _db.collection('penugasan').snapshots();
    _reportStream = _service.streamSemuaLaporan();
    _usersStream = _db.collection('users').snapshots();

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
    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.day} ${months[date.month - 1]} ${date.year}, ${two(date.hour)}:${two(date.minute)} WIB';
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
        return true;
      }
      final activeId = _value(assignment, 'kendala_aktif_id', '');
      return activeId.isEmpty || activeId == report.id;
    }

    if (_terminal(status)) {
      return true;
    }

    return true;
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

  IconData _statusIcon(String status) {
    switch (status) {
      case StatusLaporanKendala.menungguReview:
        return Icons.hourglass_top_rounded;
      case StatusLaporanKendala.dalamPenanganan:
        return Icons.handyman_rounded;
      case StatusLaporanKendala.menungguKonfirmasi:
        return Icons.mark_email_read_rounded;
      case StatusLaporanKendala.selesai:
        return Icons.check_circle_rounded;
      case StatusLaporanKendala.ditolak:
        return Icons.cancel_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  Widget _pill(String label, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<Map<String, String>> _loadDetail(Map<String, dynamic> data) async {
    final staffId = _value(data, 'pelapor_id', '');
    final tugasId = _value(data, 'tugas_id', '');

    String nama = _value(
      data,
      'pelapor_nama',
      _value(data, 'nama_staf', 'Staff'),
    );
    String tugas = _value(data, 'judul_tugas', 'Tugas Penugasan');

    if (staffId.isNotEmpty) {
      try {
        final staff = await _db.collection('users').doc(staffId).get();
        if (staff.exists) {
          nama = _value(staff.data()!, 'nama', nama);
        }
      } catch (_) {}
    }

    if (tugasId.isNotEmpty) {
      try {
        final task = await _db.collection('tugas').doc(tugasId).get();
        if (task.exists) {
          tugas = _value(task.data()!, 'judul', tugas);
        }
      } catch (_) {}
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
      _selectedStaffId = 'semua';
    });
  }

  bool _matches(Map<String, dynamic> data, String id) {
    if (_selectedStaffId != 'semua' &&
        _value(data, 'pelapor_id', '') != _selectedStaffId) {
      return false;
    }

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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _navy.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, color: _blue),
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: _navy,
          ),
          items: options.entries.map((entry) {
            return DropdownMenuItem(
              value: entry.key,
              child: Text(entry.value, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _filters() {
    final hasActiveFilter =
        _query.isNotEmpty ||
        _status != 'semua' ||
        _jenis != 'semua' ||
        _prioritas != 'semua' ||
        _urut != 'terbaru' ||
        _selectedStaffId != 'semua';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _navy.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _query = value.trim().toLowerCase();
                      });
                    },
                    decoration: InputDecoration(
                      hintText:
                          'Cari judul tugas, nama staff, atau deskripsi kendala...',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: _blue,
                      ),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                            ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              if (hasActiveFilter) ...[
                const SizedBox(width: 10),
                TextButton.icon(
                  onPressed: _reset,
                  icon: const Icon(Icons.restart_alt_rounded, size: 18),
                  label: const Text('Reset'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth >= 720
                  ? (constraints.maxWidth - 36) / 4
                  : constraints.maxWidth >= 430
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;

              return Wrap(
                spacing: 12,
                runSpacing: 10,
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
                      'internal': 'Kendala Internal',
                      'eksternal': 'Kendala Eksternal',
                    }, (v) => setState(() => _jenis = v ?? 'semua')),
                  ),
                  SizedBox(
                    width: width,
                    child: _dropdown('Prioritas', _prioritas, {
                      'semua': 'Semua Prioritas',
                      'tinggi': 'Prioritas Tinggi',
                      'sedang': 'Prioritas Sedang',
                      'rendah': 'Prioritas Rendah',
                    }, (v) => setState(() => _prioritas = v ?? 'semua')),
                  ),
                  SizedBox(
                    width: width,
                    child: _dropdown('Urutkan', _urut, {
                      'terbaru': 'Terbaru',
                      'terlama': 'Terlama',
                      'prioritas': 'Prioritas Tertinggi',
                      'status': 'Status A–Z',
                    }, (v) => setState(() => _urut = v ?? 'terbaru')),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _reportCard(
    QueryDocumentSnapshot<Map<String, dynamic>> doc, {
    required int staffTotalKendala,
    required int taskTotalKendala,
  }) {
    final data = doc.data();
    final status = _value(data, 'status', StatusLaporanKendala.menungguReview);
    final statusCol = _statusColor(status);
    final hasBukti =
        _value(data, 'bukti_path', '').isNotEmpty ||
        _value(data, 'bukti_url', '').isNotEmpty;
    final hasSolusiFile = _value(data, 'solusi_file_path', '').isNotEmpty;

    return FutureBuilder<Map<String, String>>(
      future: _details(doc.id, data),
      builder: (context, snapshot) {
        final info = snapshot.data;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: _navy.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
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
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border(
                    left: BorderSide(color: statusCol, width: 4.5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: statusCol.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _statusIcon(status),
                            color: statusCol,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                info?['tugas'] ?? 'Memuat judul tugas...',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _navy,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.person_outline_rounded,
                                    size: 14,
                                    color: _blue,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      info?['nama'] ?? 'Memuat staff...',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: _blue,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _pill(StatusLaporanKendala.label(status), statusCol),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _value(
                              data,
                              'deskripsi',
                              _value(data, 'deskripsi_kendala'),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              height: 1.4,
                              fontSize: 13,
                              color: Color(0xFF334155),
                            ),
                          ),
                          if (_value(data, 'dampak', '').isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Dampak: ${_value(data, 'dampak')}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.grey.shade600,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _pill(
                          'Jenis: ${_value(data, 'jenis_kendala')}',
                          _blue,
                          icon: Icons.category_outlined,
                        ),
                        _pill(
                          'Prioritas: ${_value(data, 'prioritas')}',
                          const Color(0xFFCA6D00),
                          icon: Icons.flag_rounded,
                        ),
                        _pill(
                          'Staff: ${staffTotalKendala}× kendala',
                          const Color(0xFFB42318),
                        ),
                        if (hasBukti)
                          _pill(
                            'Ada Bukti',
                            const Color(0xFF0C7C82),
                            icon: Icons.attach_file_rounded,
                          ),
                        if (hasSolusiFile)
                          _pill(
                            'File Solusi',
                            const Color(0xFF15803D),
                            icon: Icons.task_alt_rounded,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 13,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _tanggal(
                                data['tanggal_laporan'] ?? data['created_at'],
                              ),
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _blue.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Buka Detail',
                                style: TextStyle(
                                  color: _blue,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 14,
                                color: _blue,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStaffFrequencySection(List<Map<String, dynamic>> staffSummary) {
    if (staffSummary.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _navy.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3F2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.analytics_outlined,
                  color: Color(0xFFB42318),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ringkasan Kendala per Staff',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: _navy,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Klik kartu staff untuk menyaring daftar laporan kendala milik staff tersebut.',
                      style: TextStyle(fontSize: 11.5, color: Colors.blueGrey),
                    ),
                  ],
                ),
              ),
              if (_selectedStaffId != 'semua')
                TextButton.icon(
                  onPressed: () => setState(() => _selectedStaffId = 'semua'),
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Tampilkan Semua'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: staffSummary.map((item) {
              final String staffId = item['id'] as String;
              final String nama = item['nama'] as String;
              final String jabatan = item['jabatan'] as String;
              final int total = item['total'] as int;
              final int aktif = item['aktif'] as int;
              final int selesai = item['selesai'] as int;
              final bool selected = _selectedStaffId == staffId;

              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  setState(() {
                    _selectedStaffId = selected ? 'semua' : staffId;
                  });
                },
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 220,
                    maxWidth: 300,
                  ),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFEAF3FC)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected ? _blue : const Color(0xFFE2E8F0),
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: _blue.withOpacity(0.12),
                        child: Text(
                          nama.isNotEmpty ? nama[0].toUpperCase() : 'S',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _blue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nama,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: _navy,
                              ),
                            ),
                            Text(
                              jabatan != '-'
                                  ? jabatan
                                  : 'Aktif: $aktif • Selesai: $selesai',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.blueGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFB42318).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '$total×',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFB42318),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _content(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> reports,
    Map<String, Map<String, dynamic>> assignments,
    Map<String, Map<String, dynamic>> users,
  ) {
    final visible = reports.where((doc) => _visible(doc, assignments)).toList();

    final totalAll = reports.length;
    final pending = reports
        .where((d) => d.data()['status'] == StatusLaporanKendala.menungguReview)
        .length;
    final handling = reports
        .where(
          (d) => d.data()['status'] == StatusLaporanKendala.dalamPenanganan,
        )
        .length;
    final confirming = reports
        .where(
          (d) => d.data()['status'] == StatusLaporanKendala.menungguKonfirmasi,
        )
        .length;
    final completed = reports
        .where((d) => d.data()['status'] == StatusLaporanKendala.selesai)
        .length;
    final rejected = reports
        .where((d) => d.data()['status'] == StatusLaporanKendala.ditolak)
        .length;

    final Map<String, int> staffKendalaCount = {};
    final Map<String, int> taskKendalaCount = {};
    final Map<String, Map<String, dynamic>> staffStatsMap = {};

    for (final doc in reports) {
      final d = doc.data();
      final staffId = _value(d, 'pelapor_id', '');
      final tugasId = _value(d, 'tugas_id', '');
      final st = _value(d, 'status', StatusLaporanKendala.menungguReview);

      if (tugasId.isNotEmpty) {
        taskKendalaCount[tugasId] = (taskKendalaCount[tugasId] ?? 0) + 1;
      }
      if (staffId.isNotEmpty) {
        staffKendalaCount[staffId] = (staffKendalaCount[staffId] ?? 0) + 1;
        final u = users[staffId];
        final nama = u != null
            ? _value(u, 'nama', _value(d, 'nama_staf', 'Staff'))
            : _value(d, 'nama_staf', 'Staff');
        final jabatan = u != null ? _value(u, 'jabatan', '-') : '-';

        final entry = staffStatsMap.putIfAbsent(
          staffId,
          () => {
            'id': staffId,
            'nama': nama,
            'jabatan': jabatan,
            'total': 0,
            'aktif': 0,
            'selesai': 0,
            'ditolak': 0,
          },
        );
        entry['total'] = (entry['total'] as int) + 1;
        if (st == StatusLaporanKendala.selesai) {
          entry['selesai'] = (entry['selesai'] as int) + 1;
        } else if (st == StatusLaporanKendala.ditolak) {
          entry['ditolak'] = (entry['ditolak'] as int) + 1;
        } else {
          entry['aktif'] = (entry['aktif'] as int) + 1;
        }
      }
    }

    final staffSummary = staffStatsMap.values.toList()
      ..sort((a, b) => (b['total'] as int).compareTo(a['total'] as int));

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
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 900
                          ? 6
                          : constraints.maxWidth >= 600
                          ? 3
                          : 2;

                      final width =
                          (constraints.maxWidth - (columns - 1) * 10) / columns;

                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          SizedBox(
                            width: width,
                            child: _statCard(
                              'Total Laporan',
                              totalAll,
                              Icons.report_problem_rounded,
                              _navy,
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: _statCard(
                              'Menunggu Review',
                              pending,
                              Icons.hourglass_top_rounded,
                              const Color(0xFFB96B00),
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: _statCard(
                              'Dalam Penanganan',
                              handling,
                              Icons.handyman_rounded,
                              _blue,
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: _statCard(
                              'Menunggu Konfirmasi',
                              confirming,
                              Icons.fact_check_rounded,
                              const Color(0xFF7C3AED),
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: _statCard(
                              'Selesai',
                              completed,
                              Icons.check_circle_rounded,
                              const Color(0xFF15803D),
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: _statCard(
                              'Ditolak',
                              rejected,
                              Icons.cancel_rounded,
                              const Color(0xFFB42318),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildStaffFrequencySection(staffSummary),
                  const SizedBox(height: 16),
                  _filters(),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Text(
                        'Daftar Laporan Kendala',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: _navy,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _pill('${filtered.length} Laporan', _blue),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (filtered.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Tidak ada laporan kendala yang sesuai filter.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
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
                              SizedBox(
                                width: width,
                                child: _reportCard(
                                  doc,
                                  staffTotalKendala:
                                      staffKendalaCount[_value(
                                        doc.data(),
                                        'pelapor_id',
                                        '',
                                      )] ??
                                      1,
                                  taskTotalKendala:
                                      taskKendalaCount[_value(
                                        doc.data(),
                                        'tugas_id',
                                        '',
                                      )] ??
                                      1,
                                ),
                              ),
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
            child: Text('Gagal memuat penugasan: ${assignmentSnapshot.error}'),
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
                child: Text('Gagal memuat laporan: ${snapshot.error}'),
              );
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _usersStream,
              builder: (context, uSnap) {
                final users = <String, Map<String, dynamic>>{
                  if (uSnap.hasData)
                    for (final doc in uSnap.data!.docs) doc.id: doc.data(),
                };
                return _content(snapshot.data!.docs, assignments, users);
              },
            );
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
  static const Color _sky = AppPalette.sky;
  static const Color _background = AppPalette.background;

  final _db = FirebaseFirestore.instance;
  final _service = LaporanKendalaService();
  final _storageService = SupabaseStorageService();

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
    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.day} ${months[date.month - 1]} ${date.year}, ${two(date.hour)}:${two(date.minute)} WIB';
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
          _value(data, 'pelapor_nama', _value(data, 'nama_staf', 'Staff')),
      'jabatan': staff?.data()?['jabatan']?.toString() ?? '-',
      'tugas':
          task?.data()?['judul']?.toString() ??
          _value(data, 'judul_tugas', 'Tugas Penugasan'),
    };
  }

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? Colors.red.shade700 : _navy,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _blue.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: _blue),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.blueGrey,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    color: _navy,
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(
    String title,
    IconData icon,
    List<Widget> children, {
    Color iconColor = _blue,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _navy.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: _navy,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _attachmentCard({
    required String fileName,
    required String subtitle,
    required VoidCallback onPreview,
    required VoidCallback onDownload,
  }) {
    final cleanName = fileName.replaceFirst(RegExp(r'^\d{10,}_'), '');
    final ext = cleanName.contains('.')
        ? cleanName.split('.').last.toUpperCase()
        : 'FILE';
    final isImg = const ['JPG', 'JPEG', 'PNG', 'WEBP'].contains(ext);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F6FC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _blue.withOpacity(0.20)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _sky.withOpacity(0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isImg ? Icons.image_rounded : Icons.picture_as_pdf_rounded,
              color: _blue,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cleanName.isNotEmpty ? cleanName : 'Dokumen Lampiran',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: _navy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$ext • $subtitle',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Lihat Dokumen di Aplikasi',
            onPressed: onPreview,
            icon: const Icon(Icons.visibility_rounded, color: _blue),
          ),
          IconButton(
            tooltip: 'Unduh Dokumen ke Perangkat',
            onPressed: onDownload,
            icon: const Icon(Icons.download_rounded, color: _blue),
          ),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            title,
            style: const TextStyle(color: _navy, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: 400,
            child: TextField(
              controller: controller,
              autofocus: true,
              minLines: 3,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: hint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB42318),
              ),
              onPressed: () {
                final text = controller.text.trim();
                if (text.isEmpty) return;
                Navigator.pop(dialogContext, text);
              },
              child: const Text('Tolak Laporan'),
            ),
          ],
        );
      },
    );

    Future<void>.delayed(const Duration(milliseconds: 300), controller.dispose);
    return result;
  }

  Future<void> _action(Future<void> Function() work) async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      await work();
      if (!mounted) return;
      _snack('Laporan kendala berhasil diperbarui.');
    } catch (e) {
      if (!mounted) return;
      _snack('Gagal memproses laporan: $e', error: true);
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
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      );
    }

    return FilledButton.icon(
      onPressed: _saving ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: buttonColor,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  // ============================================================
  // PREVIEW & UNDUH LAMPIRAN IN-APP (BUKTI STAFF & SOLUSI ATASAN)
  // ============================================================

  Future<void> _bukaFileInApp({
    required String namaFile,
    required String path,
    String? fallbackUrl,
    required String kind,
    String? assignmentId,
    String? tugasId,
  }) async {
    await StaffAdminApi.openInAppFilePreview(
      context,
      namaFile: namaFile,
      path: path,
      fallbackUrl: fallbackUrl,
      assignmentId: assignmentId,
      laporanId: widget.laporanId,
      tugasId: tugasId,
      kind: kind,
    );
  }

  Future<void> _unduhFileInApp({
    required String namaFile,
    required String path,
    String? fallbackUrl,
    required String kind,
    String? assignmentId,
    String? tugasId,
  }) async {
    await StaffAdminApi.downloadSupabaseFile(
      context,
      namaFile: namaFile,
      path: path,
      fallbackUrl: fallbackUrl,
      assignmentId: assignmentId,
      laporanId: widget.laporanId,
      tugasId: tugasId,
      kind: kind,
    );
  }

  // ============================================================
  // KIRIM DAN EDIT SOLUSI (DENGAN DUKUNGAN FILE DOKUMEN)
  // ============================================================

  Future<void> _formSolusi({required bool edit}) async {
    if (_saving) return;

    final current = await _db
        .collection('laporan_kendala')
        .doc(widget.laporanId)
        .get();

    if (!mounted) return;

    final data = current.data() ?? {};
    final existingFileName = _value(
      data,
      'solusi_file_nama',
      _value(data, 'solusi_file_path', '').isNotEmpty
          ? _value(data, 'solusi_file_path').split('/').last
          : '',
    );

    final controller = TextEditingController(
      text: edit ? (data['solusi'] ?? '').toString() : '',
    );

    PlatformFile? selectedFile;
    Uint8List? selectedBytes;
    String? fileError;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: Text(
                edit ? 'Edit Solusi & Lampiran' : 'Kirim Solusi ke Staff',
                style: const TextStyle(
                  color: _navy,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: controller,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: 'Keterangan solusi / arahan (wajib)',
                          hintText:
                              'Tuliskan langkah solusi untuk membantu staff...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      InkWell(
                        onTap: () async {
                          try {
                            final picked = await FilePicker.pickFile(
                              type: FileType.custom,
                              allowedExtensions: const [
                                'pdf',
                                'jpg',
                                'jpeg',
                                'png',
                                'docx',
                              ],
                            );

                            if (picked == null) return;
                            final b = await picked.readAsBytes();

                            setModalState(() {
                              selectedFile = picked;
                              selectedBytes = b;
                              fileError = null;
                            });
                          } catch (e) {
                            setModalState(() {
                              fileError = 'Gagal membaca file: $e';
                            });
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F6FF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _blue.withOpacity(0.35)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.upload_file_rounded,
                                color: _blue,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      selectedFile != null
                                          ? selectedFile!.name
                                          : (edit && existingFileName.isNotEmpty
                                                ? 'Ganti file ($existingFileName)'
                                                : 'Lampirkan file solusi (PDF / Foto / DOCX)'),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: selectedFile != null
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        color: _navy,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      selectedFile != null
                                          ? 'File siap dikirim bersama solusi'
                                          : 'Opsional — klik untuk memilih dokumen',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (selectedFile != null)
                                IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    setModalState(() {
                                      selectedFile = null;
                                      selectedBytes = null;
                                    });
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (fileError != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          fileError!,
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Batal'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: _blue),
                  onPressed: () {
                    final solusi = controller.text.trim();
                    if (solusi.isEmpty) return;

                    Navigator.pop(dialogContext, {
                      'solusi': solusi,
                      'file': selectedFile,
                      'bytes': selectedBytes,
                    });
                  },
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: Text(edit ? 'Simpan Perubahan' : 'Kirim Solusi'),
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
      final preBytes = result['bytes'] as Uint8List?;

      if (file != null || (preBytes != null && preBytes.isNotEmpty)) {
        final bytes = (preBytes != null && preBytes.isNotEmpty)
            ? preBytes
            : await file!.readAsBytes();

        if (bytes == null || bytes.isEmpty) {
          throw StateError(
            'File tidak berhasil dibaca. Silakan pilih ulang lampiran.',
          );
        }

        final fName = file?.name ?? 'Lampiran_Solusi.pdf';
        final uploaded = await _storageService.uploadHasilTugas(
          tugasId: 'solusi_${widget.laporanId}',
          namaFile: fName,
          bytes: bytes,
          contentType: SupabaseStorageService.mimeTypeDariNama(fName),
        );

        path = uploaded.path;
        nama = fName;
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
  // RIWAYAT KENDALA SEBELUMNYA
  // ============================================================

  Widget _riwayatLaporan(String assignmentId, String tugasId) {
    final stream = _db
        .collection('laporan_kendala')
        .doc(widget.laporanId)
        .collection('riwayat')
        .orderBy('created_at')
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final docs = snapshot.data!.docs;

        return _section(
          'Riwayat Putaran Kendala Sebelumnya',
          Icons.history_rounded,
          [
            for (var i = 0; i < docs.length; i++)
              Builder(
                builder: (context) {
                  final d = docs[i].data();
                  final prevPath = _value(d, 'solusi_file_path', '');
                  final prevName = _value(
                    d,
                    'solusi_file_nama',
                    prevPath.isNotEmpty ? prevPath.split('/').last : 'Lampiran',
                  );

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Putaran ${i + 1} • ${_tanggal(d['created_at'])}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _navy,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('Kendala: ${_value(d, 'deskripsi_sebelumnya')}'),
                        const SizedBox(height: 4),
                        Text('Dampak: ${_value(d, 'dampak_sebelumnya')}'),
                        const SizedBox(height: 4),
                        Text(
                          'Solusi Atasan: ${_value(d, 'solusi_sebelumnya')}',
                        ),
                        const SizedBox(height: 4),
                        Text('Tanggapan Staff: ${_value(d, 'feedback')}'),
                        if (prevPath.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _attachmentCard(
                            fileName: prevName,
                            subtitle: 'Lampiran solusi putaran ${i + 1}',
                            onPreview: () => _bukaFileInApp(
                              namaFile: prevName,
                              path: prevPath,
                              kind: 'solusi',
                              assignmentId: assignmentId,
                              tugasId: tugasId,
                            ),
                            onDownload: () => _unduhFileInApp(
                              namaFile: prevName,
                              path: prevPath,
                              kind: 'solusi',
                              assignmentId: assignmentId,
                              tugasId: tugasId,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
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
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Color(0xFF15803D)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Laporan kendala ini telah diselesaikan dan dikonfirmasi oleh Staff.',
                  style: TextStyle(
                    color: Color(0xFF15803D),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      }

      if (status == StatusLaporanKendala.ditolak) {
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3F2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFECDCA)),
          ),
          child: const Row(
            children: [
              Icon(Icons.cancel_rounded, color: Color(0xFFB42318)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Laporan kendala ini telah ditolak. Data tetap tersimpan sebagai riwayat.',
                  style: TextStyle(
                    color: Color(0xFFB42318),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      }

      if (status == StatusLaporanKendala.menungguKonfirmasi &&
          isActiveAssignment) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F3FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFDDD6FE)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.mark_email_read_rounded, color: Color(0xFF7C3AED)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Solusi telah dikirim dan sedang menunggu konfirmasi dari Staff. Anda masih dapat memperbarui keterangan atau lampiran file solusi.',
                      style: TextStyle(
                        color: Color(0xFF5B21B6),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _button(
              'Edit Solusi & Lampiran File',
              Icons.edit_note_rounded,
              () => _formSolusi(edit: true),
            ),
          ],
        );
      }

      return const Text(
        'Laporan sudah tidak aktif karena penugasan telah berlanjut.',
        style: TextStyle(color: Colors.blueGrey),
      );
    }

    if (status == StatusLaporanKendala.menungguReview) {
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _button('Terima & Tangani', Icons.handyman_rounded, () {
            _action(() => _service.mulaiPenanganan(id));
          }),
          _button(
            'Tolak Laporan',
            Icons.block_rounded,
            () async {
              final alasan = await _askText(
                title: 'Alasan Penolakan Laporan',
                hint: 'Masukkan alasan mengapa laporan kendala ini ditolak...',
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
        spacing: 12,
        runSpacing: 12,
        children: [
          _button(
            'Kirim Solusi & File',
            Icons.send_rounded,
            () => _formSolusi(edit: false),
          ),
          _button(
            'Tolak Laporan',
            Icons.block_rounded,
            () async {
              final alasan = await _askText(
                title: 'Alasan Penolakan Laporan',
                hint: 'Masukkan alasan mengapa laporan kendala ini ditolak...',
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
  // KONTEN DETAIL
  // ============================================================

  Widget _detailContent(
    Map<String, dynamic> data,
    String assignmentStatus,
    bool isActiveAssignment,
  ) {
    final status = _value(data, 'status');
    final statusCol = _statusColor(status);
    final assignmentId = _value(data, 'penugasan_id', '');
    final tugasId = _value(data, 'tugas_id', '');
    final buktiPath = _value(data, 'bukti_path', '');
    final buktiUrl = _value(data, 'bukti_url', '');
    final solusiPath = _value(data, 'solusi_file_path', '');
    final solusiNama = _value(
      data,
      'solusi_file_nama',
      solusiPath.isNotEmpty ? solusiPath.split('/').last : 'Dokumen_Solusi.pdf',
    );

    _identity ??= _loadIdentity(data);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // TOMBOL KEMBALI KE DAFTAR LAPORAN KENDALA
                TextButton.icon(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text(
                    'Kembali ke Daftar Laporan Kendala',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: _blue,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // BANNER HEADER STATUS
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_navy, _blue],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: _navy.withOpacity(0.18),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: FutureBuilder<Map<String, String>>(
                    future: _identity,
                    builder: (context, snapshot) {
                      final judul =
                          snapshot.data?['tugas'] ?? 'Memuat Tugas...';
                      final staff =
                          snapshot.data?['staff'] ?? 'Memuat Staff...';

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  StatusLaporanKendala.label(status),
                                  style: TextStyle(
                                    color: statusCol,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Prioritas ${_value(data, 'prioritas')}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            judul,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.person_outline_rounded,
                                size: 16,
                                color: Colors.white70,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Dilaporkan oleh: $staff • ${_tanggal(data['tanggal_laporan'] ?? data['created_at'])}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),

                // SEKSI 1: INFORMASI LAPORAN KENDALA
                _section(
                  'Informasi Laporan Kendala',
                  Icons.report_problem_rounded,
                  [
                    FutureBuilder<Map<String, String>>(
                      future: _identity,
                      builder: (context, snapshot) {
                        return LayoutBuilder(
                          builder: (context, c) {
                            final twoCol = c.maxWidth >= 560;
                            final w = twoCol
                                ? (c.maxWidth - 12) / 2
                                : c.maxWidth;
                            return Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                SizedBox(
                                  width: w,
                                  child: _infoTile(
                                    Icons.badge_outlined,
                                    'Staff Pelapor',
                                    snapshot.data?['staff'] ?? 'Memuat...',
                                  ),
                                ),
                                SizedBox(
                                  width: w,
                                  child: _infoTile(
                                    Icons.assignment_outlined,
                                    'Judul Tugas',
                                    snapshot.data?['tugas'] ?? 'Memuat...',
                                  ),
                                ),
                                SizedBox(
                                  width: w,
                                  child: _infoTile(
                                    Icons.category_outlined,
                                    'Jenis Kendala',
                                    _value(data, 'jenis_kendala'),
                                  ),
                                ),
                                SizedBox(
                                  width: w,
                                  child: _infoTile(
                                    Icons.sync_alt_rounded,
                                    'Status Penugasan',
                                    assignmentStatus.isEmpty
                                        ? '-'
                                        : assignmentStatus.toUpperCase(),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Deskripsi Kendala',
                      style: TextStyle(
                        color: _navy,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        _value(
                          data,
                          'deskripsi',
                          _value(data, 'deskripsi_kendala'),
                        ),
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Dampak terhadap Tugas',
                      style: TextStyle(
                        color: _navy,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Text(
                        _value(data, 'dampak'),
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                ),

                // SEKSI 2: LAMPIRAN BUKTI KENDALA STAFF
                if (buktiPath.isNotEmpty || buktiUrl.isNotEmpty)
                  _section(
                    'Lampiran Bukti Kendala dari Staff',
                    Icons.attach_file_rounded,
                    [
                      _attachmentCard(
                        fileName: buktiPath.isNotEmpty
                            ? Uri.decodeComponent(buktiPath.split('/').last)
                            : 'Bukti_Kendala.pdf',
                        subtitle:
                            'Klik ikon mata untuk melihat isi dokumen di aplikasi',
                        onPreview: () => _bukaFileInApp(
                          namaFile: buktiPath.isNotEmpty
                              ? Uri.decodeComponent(buktiPath.split('/').last)
                              : 'Bukti_Kendala.pdf',
                          path: buktiPath,
                          fallbackUrl: buktiUrl,
                          kind: 'kendala',
                          assignmentId: assignmentId,
                          tugasId: tugasId,
                        ),
                        onDownload: () => _unduhFileInApp(
                          namaFile: buktiPath.isNotEmpty
                              ? Uri.decodeComponent(buktiPath.split('/').last)
                              : 'Bukti_Kendala.pdf',
                          path: buktiPath,
                          fallbackUrl: buktiUrl,
                          kind: 'kendala',
                          assignmentId: assignmentId,
                          tugasId: tugasId,
                        ),
                      ),
                    ],
                  ),

                // SEKSI 3: PENANGANAN & SOLUSI ATASAN
                _section(
                  'Penanganan & Solusi Atasan',
                  Icons.verified_user_outlined,
                  [
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

                        return _infoTile(
                          Icons.supervisor_account_rounded,
                          'Ditangani Oleh',
                          nama.isEmpty
                              ? 'Belum ada Atasan yang menangani'
                              : '$nama${jabatan.isEmpty ? '' : ' — $jabatan'}',
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Arahan / Solusi dari Atasan',
                      style: TextStyle(
                        color: _navy,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F9FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBAE6FD)),
                      ),
                      child: Text(
                        _value(
                          data,
                          'solusi',
                          'Belum ada solusi yang dikirimkan.',
                        ),
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: _navy,
                        ),
                      ),
                    ),
                    if (solusiPath.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const Text(
                        'Lampiran Dokumen Solusi Atasan',
                        style: TextStyle(
                          color: _navy,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _attachmentCard(
                        fileName: solusiNama,
                        subtitle: 'Dokumen panduan solusi dari Atasan',
                        onPreview: () => _bukaFileInApp(
                          namaFile: solusiNama,
                          path: solusiPath,
                          kind: 'solusi',
                          assignmentId: assignmentId,
                          tugasId: tugasId,
                        ),
                        onDownload: () => _unduhFileInApp(
                          namaFile: solusiNama,
                          path: solusiPath,
                          kind: 'solusi',
                          assignmentId: assignmentId,
                          tugasId: tugasId,
                        ),
                      ),
                    ],
                    if (_value(data, 'alasan_penolakan', '').isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const Text(
                        'Alasan Penolakan',
                        style: TextStyle(
                          color: Color(0xFFB42318),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFECDCA)),
                        ),
                        child: Text(
                          _value(data, 'alasan_penolakan'),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFFB42318),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                // SEKSI 4: RIWAYAT PUTARAN SEBELUMNYA
                _riwayatLaporan(assignmentId, tugasId),

                // SEKSI 5: TINDAKAN ATASAN
                _section('Tindakan Atasan', Icons.touch_app_rounded, [
                  if (_saving) ...[
                    const LinearProgressIndicator(),
                    const SizedBox(height: 12),
                  ],
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
                  'Gagal memuat penugasan: ${assignmentSnapshot.error}',
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
