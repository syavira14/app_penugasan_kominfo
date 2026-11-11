import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../widgets/app_layout.dart';
import 'tugas_detail_page.dart';

// ─────────────────────────── Konstanta & Helper ───────────────────────────

const _navy = Color(0xFF1A1464);
const _blue = Color(0xFF1D5FA0);
const _sky = Color(0xFF4FA6DE);
const _bg = Color(0xFFF7F9FB);
const _maxActive = 5; // maksimal tugas aktif bersamaan
const _maxMonthlyTotal = 15; // kuota tugas per bulan
const _maxPerPriority = 5; // kuota per prioritas

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

bool _isActive(Map<String, dynamic> t) =>
    t['status'] != 'Selesai' && t['status'] != 'Antrean';

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

int _byDeadline(Map<String, dynamic> a, Map<String, dynamic> b) {
  final da = a['deadline'] as DateTime?;
  final db = b['deadline'] as DateTime?;
  if (da == null && db == null) return 0;
  if (da == null) return 1;
  if (db == null) return -1;
  return da.compareTo(db);
}

Color _prioColor(String p) {
  if (p == 'Tinggi') return Colors.red.shade600;
  if (p == 'Rendah') return Colors.green.shade600;
  return Colors.amber.shade700;
}

Color _statusColor(String s) {
  switch (s) {
    case 'Berlangsung':
      return Colors.orange.shade800;
    case 'Dikumpulkan':
      return Colors.deepPurple.shade400;
    case 'Revisi':
      return Colors.deepOrange.shade600;
    case 'Terkendala':
      return Colors.red.shade700;
    case 'Selesai':
      return Colors.green.shade700;
    case 'Antrean':
      return Colors.blueGrey.shade600;
    default:
      return Colors.blueGrey.shade500;
  }
}

String _statusLabel(String s) => s;

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
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  ),
);

Widget _workBadge(bool sibuk) => sibuk
    ? _pill('Sibuk', Colors.orange.shade800, icon: Icons.work_rounded)
    : _pill('Tersedia', Colors.green.shade700, icon: Icons.check_circle);

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

// ─────────────────────────────── Halaman ───────────────────────────────

class RekapanPribadiPage extends StatefulWidget {
  const RekapanPribadiPage({super.key});

  @override
  State<RekapanPribadiPage> createState() => _RekapanPribadiPageState();
}

class _RekapanPribadiPageState extends State<RekapanPribadiPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Periode terpilih (selalu tanggal 1).
  DateTime _selectedDate = DateTime(DateTime.now().year, DateTime.now().month);

  Stream<QuerySnapshot<Map<String, dynamic>>>? _assignmentStream;
  late final Future<Map<String, dynamic>> _profileFuture;

  // Dimuat ulang hanya saat data penugasan berubah (bukan saat ganti periode),
  // sehingga tidak ada kedipan loading ketika filter bulan diganti.
  QuerySnapshot<Map<String, dynamic>>? _lastSnap;
  Future<List<Map<String, dynamic>>>? _tasksFuture;
  final Map<String, Map<String, dynamic>> _tugasCache = {};

  @override
  void initState() {
    super.initState();
    final user = _auth.currentUser;
    if (user != null) {
      _assignmentStream = _firestore
          .collection('penugasan')
          .where('staff_id', isEqualTo: user.uid)
          .snapshots();
      _profileFuture = _loadProfile(user);
    } else {
      _profileFuture = Future.value(<String, dynamic>{});
    }
  }

  // ───────────────────────────── Data ─────────────────────────────

  Future<Map<String, dynamic>> _loadProfile(User user) async {
    Map<String, dynamic> data = {};
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      data = doc.data() ?? {};
    } catch (_) {}
    data['nama'] = (data['nama'] ?? user.displayName ?? user.email ?? 'Staff')
        .toString();
    return data;
  }

  Future<List<Map<String, dynamic>>> _loadTasks(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final out = <Map<String, dynamic>>[];
    for (final doc in docs) {
      try {
        final a = doc.data();
        final tugasId = (a['tugas_id'] ?? '').toString();
        if (tugasId.isEmpty) continue;

        var task = _tugasCache[tugasId];
        if (task == null) {
          final t = await _firestore.collection('tugas').doc(tugasId).get();
          if (!t.exists) continue;
          task = t.data() ?? {};
          _tugasCache[tugasId] = task;
        }

        final tenggat = _parseDate(
          task['tanggal_selesai_tugas'] ?? a['deadline'] ?? a['tenggat'],
        );
        final diberikan =
            _parseDate(
              task['tanggal_mulai_tugas'] ??
                  task['tanggal_tugas_diberikan'] ??
                  a['created_at'] ??
                  a['tanggal_diberikan'],
            ) ??
            tenggat;

        out.add({
          'penugasan_id': doc.id,
          'tugas_id': tugasId,
          'judul': (task['judul'] ?? 'Tugas tanpa judul').toString(),
          'status': _taskStatus(a['status']),
          'prioritas': _priorityOf(a, task),
          'mulai': diberikan,
          'selesai': tenggat,
          'deadline': tenggat ?? diberikan,
        });
      } catch (_) {}
    }
    return out;
  }

  // ───────────────────────────── Build ─────────────────────────────

  @override
  Widget build(BuildContext context) {
    final double scale = (MediaQuery.of(context).size.width / 375).clamp(
      0.85,
      1.25,
    );

    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          _header(scale),
          Expanded(
            child: _assignmentStream == null
                ? const Center(
                    child: Text('Silakan login untuk melihat rekapan.'),
                  )
                : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _assignmentStream,
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return Center(
                          child: Text(
                            'Gagal memuat data rekapan:\n${snap.error}',
                            textAlign: TextAlign.center,
                          ),
                        );
                      }
                      if (!snap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!identical(snap.data, _lastSnap)) {
                        _lastSnap = snap.data;
                        _tasksFuture = _loadTasks(snap.data!.docs);
                      }
                      return FutureBuilder<List<Map<String, dynamic>>>(
                        future: _tasksFuture,
                        builder: (context, taskSnap) {
                          if (taskSnap.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          return _body(taskSnap.data ?? [], scale);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _header(double scale) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_sky, _blue, _navy],
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
                      'Rekapan & Monitoring Kinerja',
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
    );
  }

  Widget _body(List<Map<String, dynamic>> all, double scale) {
    final m = _selectedDate.month;
    final y = _selectedDate.year;

    // Daftar: semua tugas yang berjalan di bulan terpilih.
    final inMonth = all.where((t) => _overlapsMonth(t, m, y)).toList();
    final active = inMonth.where(_isActive).toList()..sort(_byDeadline);
    final others = inMonth.where((t) => !_isActive(t)).toList()
      ..sort((a, b) => _byDeadline(b, a));

    // Kuota/kinerja: hanya tugas yang DIBERIKAN pada bulan terpilih.
    final given = all.where((t) => _givenIn(t, m, y)).toList();
    final total = given.length;
    final selesai = given.where((t) => t['status'] == 'Selesai').length;
    final berjalan = given.where(_isActive).length;
    final terkendala = given.where((t) => t['status'] == 'Terkendala').length;
    final persen = total > 0 ? selesai / total : 0.0;
    int count(String p) => given.where((t) => t['prioritas'] == p).length;

    return ResponsiveContent(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(0, 16 * scale, 0, 24 * scale),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _profileCard(active.length >= _maxActive, scale),
            SizedBox(height: 14 * scale),
            _periodCard(scale),
            SizedBox(height: 14 * scale),
            _activeCard(active.length, scale),
            SizedBox(height: 20 * scale),

            _sectionTitle(
              'Kinerja Periode ${_months[m - 1]} $y',
              scale,
              caption: 'Dihitung dari tugas yang diberikan pada bulan ini.',
            ),
            Row(
              children: [
                for (final p in const ['Tinggi', 'Sedang', 'Rendah']) ...[
                  Expanded(child: _prioBox(p, count(p), scale)),
                  if (p != 'Rendah') SizedBox(width: 10 * scale),
                ],
              ],
            ),
            SizedBox(height: 20 * scale),

            _sectionTitle('Ringkasan Produktivitas', scale),
            _productivityCard(
              total: total,
              selesai: selesai,
              berjalan: berjalan,
              terkendala: terkendala,
              persen: persen,
              scale: scale,
            ),
            SizedBox(height: 20 * scale),

            _sectionTitle(
              'Rincian Tugas Aktif',
              scale,
              caption:
                  'Termasuk tugas yang diberikan bulan sebelumnya dan masih berjalan.',
            ),
            _taskList(
              active,
              'Tidak ada tugas aktif pada ${_months[m - 1]} $y.',
              scale,
            ),
            if (others.isNotEmpty) ...[
              SizedBox(height: 20 * scale),
              _sectionTitle('Antrean & Riwayat', scale),
              _taskList(others, '', scale),
            ],
          ],
        ),
      ),
    );
  }

  // ─────────────────────────── Komponen UI ───────────────────────────

  Widget _sectionTitle(String text, double scale, {String? caption}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 16 * scale,
              fontWeight: FontWeight.bold,
              color: _navy,
            ),
          ),
          if (caption != null) ...[
            SizedBox(height: 2 * scale),
            Text(
              caption,
              style: TextStyle(
                fontSize: 11 * scale,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _profileCard(bool sibuk, double scale) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _profileFuture,
      builder: (context, snap) {
        final p = snap.data ?? const <String, dynamic>{};
        final foto = (p['foto_base64'] ?? '').toString();
        ImageProvider? image;
        if (foto.isNotEmpty) {
          try {
            image = MemoryImage(base64Decode(foto));
          } catch (_) {}
        }
        final jabatan = (p['jabatan'] ?? '-').toString();
        final phone = (p['no_hp'] ?? '-').toString();

        return Container(
          padding: EdgeInsets.all(16 * scale),
          decoration: _card(),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28 * scale,
                backgroundColor: const Color(0xFFE2EFFB),
                backgroundImage: image,
                child: image == null
                    ? Icon(Icons.person, color: _blue, size: 30 * scale)
                    : null,
              ),
              SizedBox(width: 14 * scale),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (p['nama'] ?? 'Staff').toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17 * scale,
                        fontWeight: FontWeight.bold,
                        color: _navy,
                      ),
                    ),
                    SizedBox(height: 2 * scale),
                    Text(
                      jabatan.isEmpty ? '-' : jabatan,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5 * scale,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 4 * scale),
                    Row(
                      children: [
                        Icon(Icons.phone, size: 13 * scale, color: _blue),
                        SizedBox(width: 5 * scale),
                        Flexible(
                          child: Text(
                            phone,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5 * scale,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8 * scale),
              _workBadge(sibuk),
            ],
          ),
        );
      },
    );
  }

  Widget _periodCard(double scale) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 16 * scale,
        vertical: 10 * scale,
      ),
      decoration: _card(14),
      child: Row(
        children: [
          const Icon(Icons.filter_alt_rounded, color: _blue),
          SizedBox(width: 10 * scale),
          Expanded(
            child: Text(
              'Periode Kinerja:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _navy,
                fontSize: 13 * scale,
              ),
            ),
          ),
          InkWell(
            onTap: _showMonthYearPicker,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: 12 * scale,
                vertical: 6 * scale,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _blue, width: 1.2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_month, size: 16 * scale, color: _blue),
                  SizedBox(width: 6 * scale),
                  Text(
                    '${_months[_selectedDate.month - 1]} ${_selectedDate.year}',
                    style: TextStyle(
                      fontSize: 12.5 * scale,
                      fontWeight: FontWeight.bold,
                      color: _blue,
                    ),
                  ),
                  Icon(Icons.arrow_drop_down, size: 18 * scale, color: _blue),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _activeCard(int activeCount, double scale) {
    return Container(
      padding: EdgeInsets.all(16 * scale),
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
              Expanded(
                child: Text(
                  'Tugas aktif periode ini',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _navy,
                    fontSize: 13.5 * scale,
                  ),
                ),
              ),
              Text(
                '$activeCount/$_maxActive',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _navy,
                  fontSize: 14 * scale,
                ),
              ),
            ],
          ),
          SizedBox(height: 10 * scale),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (activeCount / _maxActive).clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: Colors.white,
              valueColor: const AlwaysStoppedAnimation(_blue),
            ),
          ),
          SizedBox(height: 6 * scale),
          Text(
            'Maksimal $_maxActive tugas aktif secara bersamaan',
            style: TextStyle(fontSize: 11 * scale, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _prioBox(String p, int n, double scale) {
    final color = _prioColor(p);
    return Container(
      padding: EdgeInsets.all(14 * scale),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(radius: 4, backgroundColor: color),
              SizedBox(width: 6 * scale),
              Text(
                p,
                style: TextStyle(
                  fontSize: 11 * scale,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 6 * scale),
          RichText(
            text: TextSpan(
              text: '$n',
              style: TextStyle(
                fontSize: 24 * scale,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              children: [
                TextSpan(
                  text: ' /$_maxPerPriority',
                  style: TextStyle(
                    fontSize: 12 * scale,
                    fontWeight: FontWeight.w600,
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

  Widget _productivityCard({
    required int total,
    required int selesai,
    required int berjalan,
    required int terkendala,
    required double persen,
    required double scale,
  }) {
    Widget stat(String label, String value, Color color) => Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18 * scale,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 2 * scale),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11 * scale, color: Colors.grey.shade600),
          ),
        ],
      ),
    );

    return Container(
      padding: EdgeInsets.all(16 * scale),
      decoration: _card(),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tingkat Penyelesaian',
                style: TextStyle(
                  fontSize: 12.5 * scale,
                  fontWeight: FontWeight.bold,
                  color: _navy,
                ),
              ),
              Text(
                '${(persen * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 14 * scale,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
          SizedBox(height: 8 * scale),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: persen,
              minHeight: 8 * scale,
              backgroundColor: Colors.grey.shade200,
              color: Colors.green.shade600,
            ),
          ),
          SizedBox(height: 14 * scale),
          const Divider(height: 1),
          SizedBox(height: 14 * scale),
          Row(
            children: [
              stat('Kuota Bulan Ini', '$total/$_maxMonthlyTotal', _navy),
              stat('Selesai', '$selesai', Colors.green.shade700),
              stat('Berjalan', '$berjalan', Colors.orange.shade800),
              stat('Terkendala', '$terkendala', Colors.red.shade700),
            ],
          ),
        ],
      ),
    );
  }

  Widget _taskList(
    List<Map<String, dynamic>> list,
    String emptyText,
    double scale,
  ) {
    if (list.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(20 * scale),
        decoration: _card(14),
        child: Text(
          emptyText,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13 * scale),
        ),
      );
    }
    return Column(children: [for (final t in list) _taskCard(t, scale)]);
  }

  Widget _taskCard(Map<String, dynamic> t, double scale) {
    final prio = t['prioritas'] as String;
    final status = t['status'] as String;
    final accent = _prioColor(prio);

    return Padding(
      padding: EdgeInsets.only(bottom: 10 * scale),
      child: Container(
        decoration: _card(),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    TugasDetailPage(penugasanId: t['penugasan_id'] as String),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(width: 4 * scale, color: accent),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.all(14 * scale),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t['judul'] as String,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14 * scale,
                                fontWeight: FontWeight.bold,
                                color: _navy,
                              ),
                            ),
                            SizedBox(height: 8 * scale),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                _pill(prio, accent, icon: Icons.flag_rounded),
                                _pill(
                                  _statusLabel(status),
                                  _statusColor(status),
                                ),
                              ],
                            ),
                            SizedBox(height: 8 * scale),
                            Row(
                              children: [
                                Icon(
                                  Icons.event_rounded,
                                  size: 14 * scale,
                                  color: Colors.grey.shade500,
                                ),
                                SizedBox(width: 5 * scale),
                                Expanded(
                                  child: Text(
                                    '${_fmtDate(t['mulai'] as DateTime?)}  –  ${_fmtDate(t['selesai'] as DateTime?)}',
                                    style: TextStyle(
                                      fontSize: 11.5 * scale,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(right: 10 * scale),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.grey.shade400,
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

  // ───────────────────────── Picker Bulan & Tahun ─────────────────────────

  void _showMonthYearPicker() {
    int tempYear = _selectedDate.year;
    int tempMonth = _selectedDate.month;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              titlePadding: const EdgeInsets.all(16),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, color: _blue),
                    onPressed: () => setDialogState(() => tempYear--),
                  ),
                  Text(
                    '$tempYear',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: _navy,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, color: _blue),
                    onPressed: () => setDialogState(() => tempYear++),
                  ),
                ],
              ),
              content: SizedBox(
                width: 300,
                height: 220,
                child: GridView.builder(
                  shrinkWrap: true,
                  itemCount: 12,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 2.0,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemBuilder: (context, index) {
                    final isSelected = (index + 1) == tempMonth;
                    return InkWell(
                      onTap: () => setDialogState(() => tempMonth = index + 1),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? _blue : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _shortMonths[index],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isSelected ? Colors.white : _navy,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text(
                    'Batal',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedDate = DateTime(tempYear, tempMonth);
                    });
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Pilih'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
