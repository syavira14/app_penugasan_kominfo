import 'dart:convert';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/admin_header.dart';
import 'admin_sidebar.dart';

// ─────────────────────────── Konstanta & Helper ───────────────────────────

const _navy = AppPalette.navy;
const _blue = AppPalette.blue;
const _sky = AppPalette.sky;
const _bg = AppPalette.background;
const _maxActive = 5;
const _maxMonthlyTotal = 15;
const _sideWidth = 360.0;

const _months = [
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
const _shortMonths = [
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

String _taskStatus(dynamic value) {
  switch ((value ?? 'pending').toString().toLowerCase()) {
    case 'berlangsung':
      return 'Berlangsung';
    case 'dikumpulkan':
      return 'Dikumpulkan';
    case 'revisi':
      return 'Revisi';
    case 'terkendala':
      return 'Terkendala';
    case 'disetujui':
    case 'selesai':
      return 'Selesai';
    case 'antrean':
    case 'menunggu giliran':
      return 'Antrean';
    default:
      return 'Pending';
  }
}

String _priorityOf(Map<String, dynamic> a, Map<String, dynamic>? task) {
  final p =
      (a['prioritas'] ??
              a['priority'] ??
              task?['prioritas'] ??
              task?['priority'] ??
              'sedang')
          .toString()
          .toLowerCase();
  if (p.contains('tinggi') || p == 'high') return 'Tinggi';
  if (p.contains('rendah') || p == 'low') return 'Rendah';
  return 'Sedang';
}

DateTime? _parseDate(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
  return null;
}

String _fmtDate(DateTime? d) =>
    d == null ? '-' : '${d.day} ${_shortMonths[d.month - 1]} ${d.year}';

/// Kuota bulanan dihitung dari bulan tugas DIBERIKAN (tanggal mulai).
bool _givenIn(Map<String, dynamic> t, int month, int year) {
  final d = t['mulai'] as DateTime?;
  return d != null && d.month == month && d.year == year;
}

/// Tugas dianggap "berjalan" di sebuah bulan bila rentang
/// diberikan -> tenggat menyentuh bulan tersebut (bisa lintas bulan/tahun).
bool _overlapsMonth(Map<String, dynamic> t, int month, int year) {
  final start = t['mulai'] as DateTime?;
  final end = (t['selesai'] as DateTime?) ?? start;
  if (start == null || end == null) return false;
  final monthStart = DateTime(year, month, 1);
  final monthEnd = DateTime(year, month + 1, 1);
  final s = DateTime(start.year, start.month, start.day);
  final e = DateTime(end.year, end.month, end.day);
  final lo = s.isBefore(e) ? s : e;
  final hi = s.isBefore(e) ? e : s;
  return lo.isBefore(monthEnd) && !hi.isBefore(monthStart);
}

bool _isActive(Map<String, dynamic> t) =>
    t['status'] != 'Selesai' && t['status'] != 'Antrean';

Color _prioColor(String p) {
  if (p == 'Tinggi') return Colors.red.shade600;
  if (p == 'Rendah') return Colors.green.shade600;
  return Colors.amber.shade700;
}

Color _statusColor(String s) {
  switch (s) {
    case 'Berlangsung':
      return AppTaskStatus.color('berlangsung');
    case 'Dikumpulkan':
      return AppTaskStatus.color('dikumpulkan');
    case 'Revisi':
      return AppTaskStatus.color('revisi');
    case 'Terkendala':
      return AppTaskStatus.color('terkendala');
    case 'Selesai':
      return AppTaskStatus.color('disetujui');
    case 'Antrean':
      return Colors.blueGrey.shade600;
    default:
      return Colors.blueGrey.shade500;
  }
}

Widget _pill(String text, Color color, {IconData? icon}) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
  decoration: BoxDecoration(
    color: color.withOpacity(.12),
    borderRadius: BorderRadius.circular(20),
  ),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (icon != null) ...[
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
      ],
      Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: AppTypography.caption,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  ),
);

Widget _workBadge(String status) => status == 'Sibuk'
    ? _pill('Sibuk', Colors.orange.shade800, icon: Icons.work_rounded)
    : _pill('Tersedia', Colors.green.shade700, icon: Icons.check_circle);

Widget _avatar(Map<String, dynamic> s, double radius) {
  final b = (s['foto_base64'] ?? '').toString();
  ImageProvider? image;
  if (b.isNotEmpty) {
    try {
      image = MemoryImage(base64Decode(b));
    } catch (_) {}
  }
  return CircleAvatar(
    radius: radius,
    backgroundColor: const Color(0xFFEAF3FC),
    backgroundImage: image,
    child: image == null
        ? Icon(Icons.person, color: _blue, size: radius + 4)
        : null,
  );
}

BoxDecoration _card([double r = 16]) => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(r),
  boxShadow: [
    BoxShadow(
      color: _navy.withOpacity(.05),
      blurRadius: 14,
      offset: const Offset(0, 4),
    ),
  ],
);

// ─────────────────────────────── Halaman Utama ───────────────────────────────

class StatusStaffPage extends StatefulWidget {
  const StatusStaffPage({super.key});

  @override
  State<StatusStaffPage> createState() => _StatusStaffPageState();
}

class _StatusStaffPageState extends State<StatusStaffPage>
    with AutomaticKeepAliveClientMixin {
  static const _perPage = 10;
  final db = FirebaseFirestore.instance;
  final search = TextEditingController();
  String query = '';
  String filter = 'Semua';
  int page = 0;
  late Future<List<Map<String, dynamic>>> _assignFuture;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _assignFuture = _loadAssignments();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _loadAssignments() async {
    final snaps = await Future.wait([
      db.collection('penugasan').get(),
      db.collection('tugas').get(),
    ]);
    final tugas = {for (final d in snaps[1].docs) d.id: d.data()};
    final out = <Map<String, dynamic>>[];
    for (final doc in snaps[0].docs) {
      final a = doc.data();
      final task = tugas[(a['tugas_id'] ?? '').toString()];

      // Tenggat (tanggal selesai yang direncanakan)
      final tenggat = _parseDate(
        task?['tanggal_selesai_tugas'] ?? a['deadline'] ?? a['tenggat'],
      );
      // Tanggal tugas diberikan / mulai
      final diberikan =
          _parseDate(
            task?['tanggal_mulai_tugas'] ??
                task?['tanggal_tugas_diberikan'] ??
                a['created_at'] ??
                a['tanggal_diberikan'],
          ) ??
          tenggat;

      out.add({
        'id': doc.id,
        'uid':
            (a['staff_uid'] ??
                    a['staff_id'] ??
                    a['uid_staff'] ??
                    a['user_id'] ??
                    '')
                .toString(),
        'nama': (a['staff_nama'] ?? a['nama_staff'] ?? '')
            .toString()
            .trim()
            .toLowerCase(),
        'nip': (a['staff_nip'] ?? a['nip_staff'] ?? '').toString(),
        'judul':
            (task?['judul'] ??
                    a['judul'] ??
                    a['tugas_judul'] ??
                    'Tugas tanpa judul')
                .toString(),
        'status': _taskStatus(a['status']),
        'prioritas': _priorityOf(a, task),
        'mulai': diberikan,
        'selesai': tenggat,
        // dipakai untuk urutan & tampilan tenggat
        'deadline': tenggat ?? diberikan,
      });
    }
    return out;
  }

  List<Map<String, dynamic>> _tasksFor(
    Map<String, dynamic> staff,
    String uid,
    List<Map<String, dynamic>> assignments,
  ) {
    final name = (staff['nama'] ?? '').toString().trim().toLowerCase();
    final nip = (staff['nip'] ?? '').toString();
    return assignments.where((a) {
      final byUid = (a['uid'] as String).isNotEmpty && a['uid'] == uid;
      final byName = name.isNotEmpty && a['nama'] == name;
      final byNip = nip.isNotEmpty && a['nip'] == nip;
      return byUid || byName || byNip;
    }).toList();
  }

  List<Map<String, dynamic>> _buildRows(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    List<Map<String, dynamic>> assignments,
  ) {
    final rows = <Map<String, dynamic>>[];
    for (final doc in docs) {
      final staff = doc.data();
      final role = (staff['role'] ?? 'staff').toString().toLowerCase();
      if (role == 'admin' || role == 'atasan') continue;
      final tasks = _tasksFor(staff, doc.id, assignments);
      final active = tasks.where(_isActive).toList()
        ..sort((a, b) {
          final da = a['deadline'] as DateTime?;
          final dbl = b['deadline'] as DateTime?;
          if (da == null && dbl == null) return 0;
          if (da == null) return 1;
          if (dbl == null) return -1;
          return da.compareTo(dbl);
        });
      rows.add({
        'id': doc.id,
        'staff': staff,
        'tasks': tasks,
        'active': active,
        'current': active.isEmpty ? null : active.first,
        'status': active.length >= _maxActive ? 'Sibuk' : 'Tersedia',
      });
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final wide = MediaQuery.of(context).size.width >= 900;
    return Scaffold(
      backgroundColor: _bg,
      drawer: wide ? null : const AdminSidebar(currentIndex: 3, isDrawer: true),
      body: Row(
        children: [
          if (wide) const AdminSidebar(currentIndex: 3),
          Expanded(
            child: Column(
              children: [
                AdminHeader(title: 'Status Karyawan', showSidebar: wide),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: db.collection('users').snapshots(),
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return _message('Gagal memuat staff: ${snap.error}');
                      }
                      if (!snap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return FutureBuilder<List<Map<String, dynamic>>>(
                        future: _assignFuture,
                        builder: (context, aSnap) {
                          if (aSnap.hasError) {
                            return _message(
                              'Gagal memuat penugasan: ${aSnap.error}',
                            );
                          }
                          if (!aSnap.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          final all = _buildRows(snap.data!.docs, aSnap.data!);
                          return _content(all, wide);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(List<Map<String, dynamic>> all, bool wide) {
    final q = query.toLowerCase().trim();
    final filtered = all.where((r) {
      final s = r['staff'] as Map<String, dynamic>;
      bool has(String k) => (s[k] ?? '').toString().toLowerCase().contains(q);
      final matches = q.isEmpty || has('nama') || has('nip') || has('jabatan');
      return matches && (filter == 'Semua' || r['status'] == filter);
    }).toList();

    final pages = math.max(1, (filtered.length / _perPage).ceil());
    final pg = page.clamp(0, pages - 1);
    final shown = filtered.skip(pg * _perPage).take(_perPage).toList();

    return LayoutBuilder(
      builder: (context, c) {
        final twoCol = c.maxWidth >= 1100;
        final main = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ringkasan sekarang tampil juga di mobile (versi ringkas).
            _summary(all, compact: !wide),
            SizedBox(height: wide ? 16 : 12),
            _toolbar(wide),
            const SizedBox(height: 14),
            if (shown.isEmpty)
              _empty()
            else if (wide)
              _tableCard(shown, pg, pages)
            else
              Column(children: [_mobileList(shown), _pager(pg, pages)]),
          ],
        );
        final side = Column(
          children: [
            _workloadCard(),
            const SizedBox(height: 16),
            _statusInfoCard(),
          ],
        );
        return SingleChildScrollView(
          padding: EdgeInsets.all(wide ? 24 : 16),
          child: !wide
              // Mobile: kartu keterangan ditaruh di bawah daftar staff.
              ? Column(children: [main, const SizedBox(height: 16), side])
              : twoCol
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: main),
                    const SizedBox(width: 20),
                    SizedBox(width: _sideWidth, child: side),
                  ],
                )
              : Column(children: [main, const SizedBox(height: 16), side]),
        );
      },
    );
  }

  Widget _toolbar(bool wide) {
    final searchField = Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: search,
        onChanged: (v) => setState(() {
          query = v;
          page = 0;
        }),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Cari nama, jabatan, atau NIP...',
          hintStyle: TextStyle(
            color: Colors.grey.shade500,
            fontSize: AppTypography.body,
          ),
          prefixIcon: const Icon(Icons.search_rounded, color: _blue),
          suffixIcon: query.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () {
                    search.clear();
                    setState(() {
                      query = '';
                      page = 0;
                    });
                  },
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
    final segmented = Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: ['Semua', 'Tersedia', 'Sibuk'].map((f) {
          final sel = filter == f;
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() {
              filter = f;
              page = 0;
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
              decoration: BoxDecoration(
                color: sel ? _blue : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                f,
                style: TextStyle(
                  color: sel ? Colors.white : _navy,
                  fontWeight: FontWeight.w600,
                  fontSize: AppTypography.small,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
    if (wide) {
      return Row(
        children: [
          Expanded(child: searchField),
          const SizedBox(width: 12),
          segmented,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [searchField, const SizedBox(height: 10), segmented],
    );
  }

  Widget _summary(List<Map<String, dynamic>> rows, {bool compact = false}) {
    final total = rows.length;
    final busy = rows.where((r) => r['status'] == 'Sibuk').length;
    final available = total - busy;

    Widget statCard(String label, int value, IconData icon, Color color) {
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '$value',
                      style: TextStyle(
                        fontSize: AppTypography.section,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Label boleh turun ke baris kedua, tidak dipotong.
            Text(
              label,
              maxLines: 2,
              softWrap: true,
              style: TextStyle(
                fontSize: AppTypography.caption,
                height: 1.2,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: statCard('Total Staff', total, Icons.groups_rounded, _blue),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: statCard(
              'Tersedia',
              available,
              Icons.check_circle_rounded,
              Colors.green.shade700,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: statCard(
              'Sibuk',
              busy,
              Icons.work_rounded,
              Colors.orange.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tableCard(List<Map<String, dynamic>> rows, int pg, int pages) {
    Widget head(String t, int flex) => Expanded(
      flex: flex,
      child: Text(
        t,
        style: TextStyle(
          fontSize: AppTypography.caption,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade600,
        ),
      ),
    );
    return Container(
      decoration: _card(),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                head('Nama Karyawan', 22),
                head('Batas Kuota', 16),
                head('Aktif', 12),
                head('Tinggi', 12),
                head('Sedang', 12),
                head('Rendah', 12),
                head('Status Karyawan', 18),
                head('Detail', 12),
              ],
            ),
          ),
          for (final r in rows) _tableRow(r),
          _pager(pg, pages),
        ],
      ),
    );
  }

  Widget _tableRow(Map<String, dynamic> r) {
    final s = r['staff'] as Map<String, dynamic>;
    final ts = r['tasks'] as List<Map<String, dynamic>>;
    final now = DateTime.now();

    // Kuota bulan ini dihitung dari tugas yang DIBERIKAN pada bulan ini.
    final currentMonthTasks = ts
        .where((t) => _givenIn(t, now.month, now.year))
        .length;

    int count(String p) => ts
        .where((t) => t['prioritas'] == p && _givenIn(t, now.month, now.year))
        .length;

    return InkWell(
      onTap: () => _detail(r),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 22,
              child: Row(
                children: [
                  _avatar(s, 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (s['nama'] ?? 'Staff').toString(),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: AppTypography.body,
                            color: _navy,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          (s['jabatan'] ?? '-').toString(),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: AppTypography.small,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 16,
              child: Text(
                '$currentMonthTasks/$_maxMonthlyTotal',
                style: const TextStyle(
                  fontSize: AppTypography.small,
                  fontWeight: FontWeight.bold,
                  color: _navy,
                ),
              ),
            ),
            Expanded(
              flex: 12,
              child: Text(
                '${(r['active'] as List).length}/5',
                style: const TextStyle(
                  fontSize: AppTypography.small,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              flex: 12,
              child: Text(
                '${count('Tinggi')}/5',
                style: TextStyle(
                  fontSize: AppTypography.small,
                  fontWeight: FontWeight.w600,
                  color: Colors.red.shade700,
                ),
              ),
            ),
            Expanded(
              flex: 12,
              child: Text(
                '${count('Sedang')}/5',
                style: TextStyle(
                  fontSize: AppTypography.small,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade800,
                ),
              ),
            ),
            Expanded(
              flex: 12,
              child: Text(
                '${count('Rendah')}/5',
                style: TextStyle(
                  fontSize: AppTypography.small,
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade700,
                ),
              ),
            ),
            Expanded(
              flex: 18,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _workBadge(r['status'] as String),
              ),
            ),
            Expanded(
              flex: 12,
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => _detail(r),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Detail',
                    style: TextStyle(
                      color: _blue,
                      fontWeight: FontWeight.bold,
                      fontSize: AppTypography.small,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pager(int pg, int pages) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: Colors.grey.shade200)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: 'Halaman sebelumnya',
          onPressed: pg > 0 ? () => setState(() => page = pg - 1) : null,
          icon: const Icon(Icons.chevron_left),
          color: Colors.grey.shade700,
          disabledColor: Colors.grey.shade300,
          visualDensity: VisualDensity.compact,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            '${pg + 1} / $pages',
            style: const TextStyle(
              fontSize: AppTypography.body,
              fontWeight: FontWeight.w500,
              color: _navy,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Halaman berikutnya',
          onPressed: pg < pages - 1
              ? () => setState(() => page = pg + 1)
              : null,
          icon: const Icon(Icons.chevron_right),
          color: Colors.grey.shade700,
          disabledColor: Colors.grey.shade300,
          visualDensity: VisualDensity.compact,
        ),
      ],
    ),
  );

  Widget _mobileList(List<Map<String, dynamic>> rows) => Column(
    children: rows.map((r) {
      final s = r['staff'] as Map<String, dynamic>;
      final active = r['active'] as List<Map<String, dynamic>>;
      final ts = r['tasks'] as List<Map<String, dynamic>>;
      final now = DateTime.now();

      int count(String p) => ts
          .where((t) => t['prioritas'] == p && _givenIn(t, now.month, now.year))
          .length;

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: _card(),
        child: Column(
          children: [
            Row(
              children: [
                _avatar(s, 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (s['nama'] ?? 'Staff').toString(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: AppTypography.section,
                          color: _navy,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        (s['jabatan'] ?? '-').toString(),
                        style: TextStyle(
                          fontSize: AppTypography.small,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                _workBadge(r['status'] as String),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _mobileStatBox('Aktif', '${active.length}/5', _blue),
                _mobileStatBox(
                  'Tinggi',
                  '${count('Tinggi')}/5',
                  Colors.red.shade700,
                ),
                _mobileStatBox(
                  'Sedang',
                  '${count('Sedang')}/5',
                  Colors.orange.shade800,
                ),
                _mobileStatBox(
                  'Rendah',
                  '${count('Rendah')}/5',
                  Colors.green.shade700,
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _detail(r),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Lihat Detail Karyawan'),
              ),
            ),
          ],
        ),
      );
    }).toList(),
  );

  Widget _mobileStatBox(String label, String value, Color color) => Expanded(
    child: Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: AppTypography.small,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: AppTypography.caption,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _workloadCard() {
    final now = DateTime.now();
    Widget box(String label, Color color) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: CircleAvatar(radius: 4, backgroundColor: color),
                ),
                const SizedBox(width: 6),
                // Dua baris (tanpa ellipsis) supaya tidak terpotong.
                Flexible(
                  child: Text(
                    'Prioritas\n$label',
                    style: const TextStyle(
                      fontSize: AppTypography.caption,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '5 tugas',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: AppTypography.body,
                color: _navy,
              ),
            ),
          ],
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.calendar_month, color: _blue, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ringkasan Beban Kerja Bulan Ini',
                  style: TextStyle(fontWeight: FontWeight.bold, color: _navy),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 28, top: 2),
            child: Text(
              '${_months[now.month - 1]} ${now.year}',
              style: TextStyle(
                fontSize: AppTypography.small,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              box('Tinggi', Colors.red.shade600),
              const SizedBox(width: 8),
              box('Sedang', Colors.amber.shade700),
              const SizedBox(width: 8),
              box('Rendah', Colors.green.shade600),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF3FC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info, color: _blue, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Setiap karyawan mendapatkan 15 tugas per bulan (5 tinggi, 5 sedang, 5 rendah).\nMaksimal 5 tugas dapat dikerjakan secara bersamaan.',
                    style: TextStyle(
                      fontSize: AppTypography.caption,
                      color: Color(0xFF475569),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusInfoCard() {
    Widget item(
      IconData icon,
      Color color,
      String title,
      String l1,
      String l2,
    ) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: color.withOpacity(.15),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: AppTypography.body,
                  ),
                ),
                const SizedBox(height: 3),
                Text(l1, style: const TextStyle(fontSize: AppTypography.small)),
                Text(
                  l2,
                  style: TextStyle(
                    fontSize: AppTypography.caption,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.assignment_ind, color: _blue, size: 20),
              SizedBox(width: 8),
              Text(
                'Status Karyawan',
                style: TextStyle(fontWeight: FontWeight.bold, color: _navy),
              ),
            ],
          ),
          const Divider(height: 24),
          item(
            Icons.check_circle,
            Colors.green.shade700,
            'Tersedia',
            'Jumlah tugas aktif < $_maxActive',
            'Masih ada kapasitas untuk menerima tugas baru.',
          ),
          const Divider(height: 8),
          item(
            Icons.work_rounded,
            Colors.orange.shade700,
            'Sibuk',
            'Jumlah tugas aktif = $_maxActive',
            'Sedang mengerjakan tugas sesuai kapasitas.',
          ),
        ],
      ),
    );
  }

  Widget _empty() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(28),
    decoration: _card(),
    child: const Center(child: Text('Data karyawan tidak ditemukan.')),
  );

  Widget _message(String text) => Center(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Text(text, textAlign: TextAlign.center),
    ),
  );

  void _detail(Map<String, dynamic> row) {
    // Pakai adminRoute (tanpa animasi) supaya langsung tampil, sama seperti
    // perpindahan lewat sidebar, tanpa efek geser/berkedip.
    Navigator.push(
      context,
      adminRoute(
        StatusStaffDetailPage(
          staff: Map<String, dynamic>.from(row['staff'] as Map),
          tasks: List<Map<String, dynamic>>.from(row['tasks'] as List),
        ),
      ),
    );
  }
}

// ────────────────────────────── Halaman Detail ──────────────────────────────

class StatusStaffDetailPage extends StatefulWidget {
  final Map<String, dynamic> staff;
  final List<Map<String, dynamic>> tasks;

  const StatusStaffDetailPage({
    super.key,
    required this.staff,
    required this.tasks,
  });

  @override
  State<StatusStaffDetailPage> createState() => _StatusStaffDetailPageState();
}

class _StatusStaffDetailPageState extends State<StatusStaffDetailPage> {
  late int _selectedMonth;
  late int _selectedYear;
  late List<int> _availableYears;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;

    final years = <int>{now.year};
    for (final t in widget.tasks) {
      final a = t['mulai'] as DateTime?;
      final b = t['selesai'] as DateTime?;
      if (a != null) years.add(a.year);
      if (b != null) years.add(b.year);
    }
    _availableYears = years.toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;

    // Daftar: semua tugas yang berjalan di bulan terpilih (termasuk yang
    // diberikan bulan sebelumnya dan baru selesai di bulan ini).
    final filteredTasks = widget.tasks
        .where((t) => _overlapsMonth(t, _selectedMonth, _selectedYear))
        .toList();

    final active = filteredTasks.where(_isActive).toList()
      ..sort((a, b) {
        final da = a['deadline'] as DateTime?;
        final dbl = b['deadline'] as DateTime?;
        if (da == null && dbl == null) return 0;
        if (da == null) return 1;
        if (dbl == null) return -1;
        return da.compareTo(dbl);
      });

    final others = filteredTasks.where((t) => !_isActive(t)).toList();

    // Kuota/kinerja: hanya tugas yang DIBERIKAN pada bulan terpilih.
    int count(String p) => widget.tasks
        .where(
          (t) =>
              t['prioritas'] == p && _givenIn(t, _selectedMonth, _selectedYear),
        )
        .length;

    final dynamicStatus = active.length >= _maxActive ? 'Sibuk' : 'Tersedia';

    final phone =
        (widget.staff['no_hp'] ??
                widget.staff['telepon'] ??
                widget.staff['no_hp'] ??
                widget.staff['phone'] ??
                '-')
            .toString();

    final Widget bodyContent = SingleChildScrollView(
      padding: EdgeInsets.all(wide ? 24 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text(
              'Kembali ke Status Staff',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            style: TextButton.styleFrom(foregroundColor: _blue),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: _card(),
            child: Row(
              children: [
                _avatar(widget.staff, 30),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (widget.staff['nama'] ?? 'Staff').toString(),
                        style: const TextStyle(
                          fontSize: AppTypography.subtitle,
                          fontWeight: FontWeight.bold,
                          color: _navy,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        (widget.staff['jabatan'] ?? '-').toString(),
                        style: TextStyle(
                          fontSize: AppTypography.body,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.phone, size: 14, color: _blue),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              phone,
                              style: TextStyle(
                                fontSize: AppTypography.small,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _workBadge(dynamicStatus),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: _card(14),
            child: Row(
              children: [
                const Icon(Icons.filter_alt_rounded, color: _blue),
                const SizedBox(width: 10),
                const Text(
                  'Periode Kinerja:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _navy,
                    fontSize: AppTypography.body,
                  ),
                ),
                const Spacer(),

                DropdownButton<int>(
                  value: _selectedMonth,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.arrow_drop_down, color: _blue),
                  items: List.generate(12, (index) {
                    return DropdownMenuItem(
                      value: index + 1,
                      child: Text(
                        _months[index],
                        style: const TextStyle(
                          fontSize: AppTypography.body,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedMonth = val);
                  },
                ),
                const SizedBox(width: 12),

                DropdownButton<int>(
                  value: _selectedYear,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.arrow_drop_down, color: _blue),
                  items: _availableYears.map((y) {
                    return DropdownMenuItem(
                      value: y,
                      child: Text(
                        '$y',
                        style: const TextStyle(
                          fontSize: AppTypography.body,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedYear = val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF3FC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _blue.withOpacity(.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Tugas aktif periode ini',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _navy,
                        ),
                      ),
                    ),
                    Text(
                      '${active.length}/$_maxActive',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _navy,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: (active.length / _maxActive).clamp(0.0, 1.0),
                    minHeight: 10,
                    backgroundColor: Colors.white,
                    valueColor: const AlwaysStoppedAnimation(_blue),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Maksimal $_maxActive tugas aktif per karyawan',
                  style: TextStyle(
                    fontSize: AppTypography.caption,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          Text(
            'Kinerja Periode ${_months[_selectedMonth - 1]} $_selectedYear',
            style: const TextStyle(
              fontSize: AppTypography.section,
              fontWeight: FontWeight.bold,
              color: _navy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Dihitung dari tugas yang diberikan pada bulan ini.',
            style: TextStyle(
              fontSize: AppTypography.caption,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final p in const ['Tinggi', 'Sedang', 'Rendah']) ...[
                Expanded(
                  child: Container(
                    margin: EdgeInsets.only(right: p == 'Rendah' ? 0 : 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _prioColor(p).withOpacity(.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _prioColor(p).withOpacity(.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 4,
                              backgroundColor: _prioColor(p),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              p,
                              style: const TextStyle(
                                fontSize: AppTypography.caption,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${count(p)}',
                          style: TextStyle(
                            fontSize: AppTypography.largeHeading,
                            fontWeight: FontWeight.bold,
                            color: _prioColor(p),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),

          const Text(
            'Rincian Tugas Aktif',
            style: TextStyle(
              fontSize: AppTypography.section,
              fontWeight: FontWeight.bold,
              color: _navy,
            ),
          ),
          const SizedBox(height: 10),
          _taskList(
            active,
            'Belum ada tugas aktif untuk karyawan pada periode ini.',
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Termasuk tugas yang diberikan bulan sebelumnya dan masih berjalan.',
              style: TextStyle(
                fontSize: AppTypography.caption,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          if (others.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text(
              'Antrean & Riwayat',
              style: TextStyle(
                fontSize: AppTypography.section,
                fontWeight: FontWeight.bold,
                color: _navy,
              ),
            ),
            const SizedBox(height: 10),
            _taskList(others, ''),
          ],

          const SizedBox(height: 20),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: _bg,
      drawer: wide ? null : const AdminSidebar(currentIndex: 3, isDrawer: true),
      body: Row(
        children: [
          if (wide) const AdminSidebar(currentIndex: 3),
          Expanded(
            child: Column(
              children: [
                AdminHeader(title: 'Detail Status Staff', showSidebar: wide),
                Expanded(child: bodyContent),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _taskList(List<Map<String, dynamic>> list, String emptyText) {
    if (list.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: _card(14),
        child: Text(
          emptyText,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: AppTypography.body,
          ),
        ),
      );
    }
    return Container(
      decoration: _card(14),
      child: Column(
        children: [
          for (var i = 0; i < list.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                border: i == 0
                    ? null
                    : Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  _pill(
                    list[i]['prioritas'] as String,
                    _prioColor(list[i]['prioritas'] as String),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      list[i]['judul'].toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: AppTypography.small,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _pill(
                    list[i]['status'] as String,
                    _statusColor(list[i]['status'] as String),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _fmtDate(list[i]['deadline'] as DateTime?),
                    style: TextStyle(
                      fontSize: AppTypography.caption,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
