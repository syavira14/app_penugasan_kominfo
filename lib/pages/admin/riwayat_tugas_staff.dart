import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../services/riwayat_file_service.dart';
import '../../widgets/admin_header.dart';
import 'admin_sidebar.dart';

// ───────────────────────── Helper data (di luar State) ─────────────────────────

/// Nama field yang mungkin berisi pemberi tugas (uid atau nama atasan).
const _atasanKeys = [
  'atasan_uid',
  'atasan_id',
  'atasan_nama',
  'atasan',
  'pemberi_tugas_uid',
  'pemberi_tugas_id',
  'pemberi_tugas',
  'dibuat_oleh_uid',
  'dibuat_oleh',
  'created_by',
  'assigned_by',
  'diberikan_oleh',
];

/// Nama field yang mungkin berisi orang yang menyetujui (ACC) tugas.
const _penyetujuKeys = [
  'disetujui_oleh',
  'disetujui_oleh_uid',
  'approved_by',
  'acc_oleh',
];

/// Nama field (array di dokumen penugasan) yang mungkin menyimpan log status.
const _historyKeys = [
  'riwayat_status',
  'riwayat',
  'log_status',
  'timeline',
  'history',
  'status_history',
];

String _s(dynamic v) => (v ?? '').toString().trim();

/// Ambil nilai pertama yang tidak kosong dari daftar key.
dynamic _first(Map<String, dynamic>? m, List<String> keys) {
  if (m == null) return null;
  for (final k in keys) {
    final v = m[k];
    if (v == null) continue;
    if (v is List && v.isEmpty) continue;
    if (v.toString().trim().isEmpty) continue;
    return v;
  }
  return null;
}

DateTime? _parseDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
  return null;
}

/// Cocokkan nilai mentah (uid / nama) dengan user yang terdaftar di database.
String? _personFromRaw(dynamic raw, Map<String, Map<String, dynamic>> users) {
  final r = _s(raw);
  if (r.isEmpty) return null;
  final byId = users[r];
  if (byId != null && _s(byId['nama']).isNotEmpty) return _s(byId['nama']);
  final low = r.toLowerCase();
  for (final u in users.values) {
    if (_s(u['nama']).toLowerCase() == low) return _s(u['nama']);
  }
  return null;
}

/// Cari data staff di koleksi users berdasarkan uid, NIP, lalu nama.
Map<String, dynamic>? _findStaff(
  Map<String, dynamic> a,
  Map<String, Map<String, dynamic>> users,
) {
  for (final k in const ['staff_uid', 'staff_id', 'uid_staff', 'user_id']) {
    final id = _s(a[k]);
    if (id.isNotEmpty && users[id] != null) return users[id];
  }
  final nip = _s(_first(a, ['staff_nip', 'nip_staff']));
  final name = _s(_first(a, ['staff_nama', 'nama_staff'])).toLowerCase();
  if (nip.isNotEmpty) {
    for (final u in users.values) {
      if (_s(u['nip']) == nip) return u;
    }
  }
  if (name.isNotEmpty) {
    for (final u in users.values) {
      if (_s(u['nama']).toLowerCase() == name) return u;
    }
  }
  return null;
}

/// Nama atasan harus sesuai user yang terdaftar di database.
String _resolveAtasan(
  Map<String, dynamic> a,
  Map<String, dynamic> t,
  Map<String, Map<String, dynamic>> users,
  List<Map<String, dynamic>> pool, {
  List<String> extraKeys = const [],
}) {
  for (final src in [a, t]) {
    for (final k in [...extraKeys, ..._atasanKeys]) {
      final n = _personFromRaw(src[k], users);
      if (n != null) return n;
    }
  }
  if (pool.length == 1) return _s(pool.first['nama']);
  return '-';
}

String _extOf(String name) {
  final i = name.lastIndexOf('.');
  return i < 0 ? '' : name.substring(i + 1).toLowerCase();
}

bool _isImageExt(String ext) =>
    const ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext);

String _extFromMime(String mime) {
  switch (mime.toLowerCase()) {
    case 'application/pdf':
      return 'pdf';
    case 'image/png':
      return 'png';
    case 'image/jpeg':
      return 'jpg';
    case 'application/msword':
      return 'doc';
    case 'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
      return 'docx';
    case 'application/vnd.ms-excel':
      return 'xls';
    case 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet':
      return 'xlsx';
    default:
      return 'pdf';
  }
}

String _fmtSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// Kumpulkan semua lampiran hasil pekerjaan dari dokumen penugasan.
List<Map<String, dynamic>> _extractFiles(
  Map<String, dynamic> a, [
  String assignmentId = '',
]) {
  final out = <Map<String, dynamic>>[];
  final seen = <String>{};
  final nameField = _s(
    _first(a, ['file_hasil_nama', 'file_nama', 'nama_file', 'lampiran_nama']),
  );
  final mimeField = _s(_first(a, ['file_hasil_mime', 'file_mime', 'mime']));

  void push({
    String url = '',
    String b64 = '',
    String nama = '',
    String mime = '',
  }) {
    var data = b64;
    var m = mime;
    if (data.startsWith('data:')) {
      final comma = data.indexOf(',');
      if (comma > 0) {
        final header = data.substring(5, comma);
        m = header.split(';').first;
        data = data.substring(comma + 1);
      }
    }
    final key = url.isNotEmpty ? url : data.hashCode.toString();
    if ((url.isEmpty && data.isEmpty) || !seen.add(key)) return;
    out.add({'url': url, 'b64': data, 'nama': nama, 'mime': m});
  }

  void add(dynamic v, {bool base64Field = false}) {
    if (v == null) return;
    if (v is List) {
      for (final e in v) {
        add(e, base64Field: base64Field);
      }
      return;
    }
    if (v is Map) {
      final m = Map<String, dynamic>.from(v);
      push(
        url: _s(_first(m, ['url', 'link', 'file_url', 'downloadUrl'])),
        b64: _s(_first(m, ['base64', 'file_base64', 'data'])),
        nama: _s(_first(m, ['nama', 'name', 'file_nama', 'filename'])),
        mime: _s(_first(m, ['mime', 'type'])),
      );
      return;
    }
    final s = _s(v);
    if (s.isEmpty) return;
    if (s.startsWith('http')) {
      push(url: s, nama: nameField, mime: mimeField);
    } else if (base64Field || s.startsWith('data:') || s.length > 200) {
      push(b64: s, nama: nameField, mime: mimeField);
    }
  }

  for (final k in const [
    'file_hasil_url',
    'file_hasil',
    'lampiran',
    'file_url',
    'hasil_url',
  ]) {
    add(a[k]);
  }
  for (final k in const ['file_hasil_base64', 'file_base64']) {
    add(a[k], base64Field: true);
  }
  // File hasil yang disimpan di Supabase hanya punya path (tanpa URL):
  // URL sementara diminta saat file dilihat / diunduh.
  final path = _s(a['file_hasil_path']);
  if (path.isNotEmpty && out.isEmpty) {
    out.add({
      'url': '',
      'b64': '',
      'nama': nameField.isNotEmpty ? nameField : path.split('/').last,
      'mime': mimeField,
    });
  }
  for (final f in out) {
    f['path'] = path;
    f['aid'] = assignmentId;
  }
  return out;
}

/// Satu kejadian pada alur status sebuah tugas.
class _Ev {
  final String label;
  final DateTime? time;
  final String actor;
  final String note;
  const _Ev(this.label, this.time, this.actor, this.note);
}

String _evLabel(String raw) {
  final r = raw.toLowerCase();
  if (r.contains('revisi')) return 'Revisi';
  if (r.contains('kendala')) return 'Terkendala';
  if (r.contains('kumpul')) return 'Dikumpulkan';
  if (r.contains('setuju') || r.contains('acc') || r.contains('selesai')) {
    return 'Disetujui';
  }
  if (r.contains('berlangsung') || r.contains('kerja') || r.contains('mulai')) {
    return 'Dikerjakan';
  }
  if (r.contains('beri') ||
      r.contains('pending') ||
      r.contains('antre') ||
      r.contains('menunggu')) {
    return 'Diberikan';
  }
  return raw.isEmpty ? 'Update' : raw;
}

bool _byAtasan(String label) =>
    label == 'Diberikan' || label == 'Revisi' || label == 'Disetujui';

Color _evColor(String label) {
  switch (label) {
    case 'Diberikan':
      return AppPalette.blue;
    case 'Dikerjakan':
      return Colors.orange.shade800;
    case 'Terkendala':
      return Colors.red.shade700;
    case 'Revisi':
      return Colors.deepOrange.shade600;
    case 'Dikumpulkan':
      return Colors.deepPurple.shade400;
    case 'Disetujui':
      return Colors.green.shade700;
    default:
      return Colors.blueGrey.shade600;
  }
}

IconData _evIcon(String label) {
  switch (label) {
    case 'Diberikan':
      return Icons.assignment_ind_rounded;
    case 'Dikerjakan':
      return Icons.play_circle_fill_rounded;
    case 'Terkendala':
      return Icons.report_problem_rounded;
    case 'Revisi':
      return Icons.edit_note_rounded;
    case 'Dikumpulkan':
      return Icons.upload_file_rounded;
    case 'Disetujui':
      return Icons.check_circle;
    default:
      return Icons.circle;
  }
}

// ───────────────────────────────── Halaman ─────────────────────────────────

class RiwayatTugasStaffPage extends StatefulWidget {
  const RiwayatTugasStaffPage({super.key});

  @override
  State<RiwayatTugasStaffPage> createState() => _RiwayatTugasStaffPageState();
}

class _RiwayatTugasStaffPageState extends State<RiwayatTugasStaffPage>
    with AutomaticKeepAliveClientMixin {
  static const Color navy = AppPalette.navy;
  static const Color blue = AppPalette.blue;
  static const Color sky = AppPalette.sky;
  static const Color background = AppPalette.background;

  static const double _sidebarBreakpoint = 900;
  static const int _sidebarIndex = 5;
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

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Cache user terdaftar (id -> data), diisi saat data dibangun.
  Map<String, Map<String, dynamic>> _usersById = {};

  String pencarian = '';
  int page = 0;

  /// 0 = semua bulan, 1..12 = bulan tertentu.
  int _selectedMonth = 0;

  /// 0 = semua tahun, selain itu = tahun tertentu.
  int _selectedYear = 0;

  @override
  bool get wantKeepAlive => true;

  BoxDecoration _card([double r = 16]) => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(r),
    boxShadow: [
      BoxShadow(
        color: navy.withOpacity(.05),
        blurRadius: 14,
        offset: const Offset(0, 4),
      ),
    ],
  );

  Color _prioColor(String p) {
    final str = p.toLowerCase();
    if (str.contains('tinggi') || str == 'high') return Colors.red.shade600;
    if (str.contains('rendah') || str == 'low') return Colors.green.shade600;
    return Colors.amber.shade700;
  }

  Widget _pill(String text, Color color, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withOpacity(.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
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

  Widget _prioPill(String p) => _pill(p, _prioColor(p), Icons.flag_rounded);

  Widget _donePill(String text) =>
      _pill(text, Colors.green.shade700, Icons.check_circle);

  Widget _avatar(double radius, [String foto = '']) {
    ImageProvider? image;
    if (foto.isNotEmpty) {
      try {
        image = MemoryImage(base64Decode(foto));
      } catch (_) {}
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFEAF3FC),
      backgroundImage: image,
      child: image == null
          ? Icon(Icons.person, color: blue, size: radius + 3)
          : null,
    );
  }

  String _fmt(DateTime? d, [String? jam]) {
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
    return jam == null ? base : '$base, $jam';
  }

  /// Tanggal + jam (jam disembunyikan bila data hanya berisi tanggal).
  String _fmtDT(DateTime? d) {
    if (d == null) return 'Waktu tidak tercatat';
    if (d.hour == 0 && d.minute == 0) return _fmt(d);
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return _fmt(d, '$hh:$mm');
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

  // ─────────────────────────── Olah Data Firestore ───────────────────────────

  /// Gabungkan penugasan + tugas + users secara sinkron.
  List<Map<String, dynamic>> _buildHistory(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> assignments,
    Map<String, Map<String, dynamic>> tugas,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> userDocs,
  ) {
    final users = {for (final d in userDocs) d.id: d.data()};
    _usersById = users;

    var pool = users.values
        .where((u) => _s(u['role']).toLowerCase() == 'atasan')
        .toList();
    if (pool.isEmpty) {
      pool = users.values
          .where((u) => _s(u['role']).toLowerCase() == 'admin')
          .toList();
    }

    final result = <Map<String, dynamic>>[];

    for (final item in assignments) {
      final aData = item.data();
      final status = (aData['status'] ?? '').toString().toLowerCase();
      if (status != 'disetujui' && status != 'selesai') continue;

      final tid = (aData['tugas_id'] ?? '').toString();
      final tData = tugas[tid] ?? <String, dynamic>{};
      final judul = (tData['judul'] ?? 'Tanpa Judul').toString();

      // Staff: jabatan & foto diambil dari database users.
      final staffUser = _findStaff(aData, users);
      final staffNama =
          _s(_first(aData, ['staff_nama', 'nama_staff'])).isNotEmpty
          ? _s(_first(aData, ['staff_nama', 'nama_staff']))
          : (_s(staffUser?['nama']).isNotEmpty
                ? _s(staffUser?['nama'])
                : 'Staff');
      final jabatanUser = _s(staffUser?['jabatan']);
      final jabatanAssign = _s(aData['staff_jabatan']);
      final jabatan = jabatanUser.isNotEmpty
          ? jabatanUser
          : (jabatanAssign.isNotEmpty ? jabatanAssign : '-');

      final atasan = _resolveAtasan(aData, tData, users, pool);
      final penyetuju = _resolveAtasan(
        aData,
        tData,
        users,
        pool,
        extraKeys: _penyetujuKeys,
      );

      result.add({
        'id': item.id,
        'tugas_id': tid,
        'staff_uid': _s(
          _first(aData, ['staff_uid', 'staff_id', 'uid_staff', 'user_id']),
        ),
        'staff': staffNama,
        'jabatan': jabatan,
        'foto': _s(staffUser?['foto_base64']),
        'judul': judul,
        'prioritas': (tData['prioritas'] ?? 'Sedang').toString(),
        'deskripsi': _s(tData['deskripsi']).isEmpty
            ? 'Tidak ada deskripsi.'
            : _s(tData['deskripsi']),
        'atasan': atasan,
        'penyetuju': penyetuju,
        'files': _extractFiles(aData, item.id),
        'mulai': _parseDate(
          tData['tanggal_mulai_tugas'] ?? tData['created_at'],
        ),
        'selesai': _parseDate(
          tData['tanggal_selesai_tugas'] ?? aData['updated_at'],
        ),
        'a': aData,
        't': tData,
      });
    }

    // Terbaru di atas; yang tanggalnya kosong di paling bawah.
    result.sort((a, b) {
      final da = a['selesai'] as DateTime?;
      final db = b['selesai'] as DateTime?;
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });
    return result;
  }

  /// Data tambahan saat detail dibuka: sub-koleksi riwayat & laporan kendala.
  Future<Map<String, List<Map<String, dynamic>>>> _loadExtra(
    Map<String, dynamic> t,
  ) async {
    final id = t['id'] as String;
    final tid = t['tugas_id'] as String;
    final staffUid = t['staff_uid'] as String;
    final staffNama = (t['staff'] as String).toLowerCase();

    final sub = <Map<String, dynamic>>[];
    final kendala = <Map<String, dynamic>>[];

    try {
      final s = await _firestore
          .collection('penugasan')
          .doc(id)
          .collection('riwayat_status')
          .get();
      for (final d in s.docs) {
        sub.add(d.data());
      }
    } catch (_) {}

    try {
      final seen = <String>{};
      final queries = <Future<QuerySnapshot<Map<String, dynamic>>>>[
        _firestore
            .collection('laporan_kendala')
            .where('penugasan_id', isEqualTo: id)
            .get(),
        if (tid.isNotEmpty)
          _firestore
              .collection('laporan_kendala')
              .where('tugas_id', isEqualTo: tid)
              .get(),
      ];
      for (final f in queries) {
        QuerySnapshot<Map<String, dynamic>> snap;
        try {
          snap = await f;
        } catch (_) {
          continue;
        }
        for (final d in snap.docs) {
          if (!seen.add(d.id)) continue;
          final k = d.data();
          // Jika dicari lewat tugas_id, pastikan laporan milik staff ini.
          final kUid = _s(
            _first(k, ['staff_uid', 'staff_id', 'uid_staff', 'user_id']),
          );
          final kNama = _s(
            _first(k, ['staff_nama', 'nama_staff']),
          ).toLowerCase();
          final sameStaff =
              (kUid.isEmpty && kNama.isEmpty) ||
              (kUid.isNotEmpty && kUid == staffUid) ||
              (kNama.isNotEmpty && kNama == staffNama);
          if (_s(k['penugasan_id']) == id || sameStaff) kendala.add(k);
        }
      }
    } catch (_) {}

    return {'sub': sub, 'kendala': kendala};
  }

  /// Susun alur status lengkap: diberikan → dikerjakan → kendala/revisi → ACC.
  List<_Ev> _buildTimeline(
    Map<String, dynamic> t,
    Map<String, List<Map<String, dynamic>>> extra,
  ) {
    final a = Map<String, dynamic>.from(t['a'] as Map);
    final tk = Map<String, dynamic>.from(t['t'] as Map);
    final staff = t['staff'] as String;
    final atasan = t['atasan'] as String;
    final penyetuju = t['penyetuju'] as String;
    final mulai = t['mulai'] as DateTime?;
    final selesai = t['selesai'] as DateTime?;

    _Ev diberikan() => _Ev(
      'Diberikan',
      _parseDate(
            _first(tk, ['tanggal_tugas_diberikan', 'created_at']) ??
                _first(a, ['created_at', 'tanggal_diberikan', 'assigned_at']),
          ) ??
          mulai,
      atasan,
      'Tugas diberikan kepada $staff.',
    );

    _Ev disetujui() => _Ev(
      'Disetujui',
      _parseDate(
            _first(a, [
              'tanggal_disetujui',
              'disetujui_at',
              'approved_at',
              'selesai_at',
            ]),
          ) ??
          selesai,
      penyetuju,
      _s(_first(a, ['catatan_atasan', 'catatan_persetujuan'])),
    );

    // 1) Log status yang tersimpan di database (array / sub-koleksi).
    final entries = <_Ev>[];
    for (final k in _historyKeys) {
      final v = a[k];
      if (v is List) {
        for (final e in v) {
          if (e is Map) {
            entries.add(
              _evFromMap(Map<String, dynamic>.from(e), staff, atasan),
            );
          }
        }
      }
    }
    for (final m in extra['sub'] ?? const <Map<String, dynamic>>[]) {
      entries.add(_evFromMap(m, staff, atasan));
    }

    final revisiNote = _s(a['catatan_revisi']);
    final ev = <_Ev>[];

    if (entries.isNotEmpty) {
      if (!entries.any((e) => e.label == 'Diberikan')) ev.add(diberikan());
      ev.addAll(entries);
      if (!ev.any((e) => e.label == 'Disetujui')) ev.add(disetujui());
    } else {
      // 2) Belum ada log: susun dari field yang tersedia.
      ev.add(diberikan());
      ev.add(
        _Ev(
          'Dikerjakan',
          _parseDate(
                _first(a, ['tanggal_mulai_kerja', 'mulai_at', 'started_at']),
              ) ??
              mulai,
          staff,
          (mulai != null || selesai != null)
              ? 'Periode pengerjaan: ${_fmt(mulai)} – ${_fmt(selesai)}'
              : '',
        ),
      );
      ev.add(
        _Ev(
          'Dikumpulkan',
          _parseDate(
            _first(a, [
              'tanggal_dikumpulkan',
              'dikumpulkan_at',
              'submitted_at',
            ]),
          ),
          staff,
          '',
        ),
      );
      ev.add(disetujui());
    }

    // Catatan revisi tunggal (bila belum ada event Revisi), sisipkan sebelum ACC.
    if (revisiNote.isNotEmpty && !ev.any((e) => e.label == 'Revisi')) {
      final idx = ev.lastIndexWhere((e) => e.label == 'Disetujui');
      ev.insert(
        idx < 0 ? ev.length : idx,
        _Ev(
          'Revisi',
          _parseDate(_first(a, ['tanggal_revisi', 'revisi_at'])),
          atasan,
          revisiNote,
        ),
      );
    }

    // Laporan kendala dari koleksi laporan_kendala.
    if (!ev.any((e) => e.label == 'Terkendala')) {
      final idx = ev.lastIndexWhere((e) => e.label == 'Disetujui');
      var pos = idx < 0 ? ev.length : idx;
      for (final k in extra['kendala'] ?? const <Map<String, dynamic>>[]) {
        ev.insert(
          pos++,
          _Ev(
            'Terkendala',
            _parseDate(
              _first(k, [
                'created_at',
                'tanggal',
                'waktu',
                'timestamp',
                'dibuat_at',
              ]),
            ),
            staff,
            _s(
              _first(k, [
                'deskripsi',
                'alasan',
                'keterangan',
                'isi',
                'kendala',
                'catatan',
                'judul',
              ]),
            ),
          ),
        );
      }
    }

    // Urutkan stabil berdasarkan waktu; event tanpa waktu mengikuti sebelumnya.
    DateTime? last;
    final keys = <DateTime>[];
    for (final e in ev) {
      last = e.time ?? last;
      keys.add(last ?? DateTime.fromMillisecondsSinceEpoch(0));
    }
    final idx = List<int>.generate(ev.length, (i) => i)
      ..sort((x, y) {
        final c = keys[x].compareTo(keys[y]);
        return c != 0 ? c : x.compareTo(y);
      });
    return [for (final i in idx) ev[i]];
  }

  _Ev _evFromMap(Map<String, dynamic> m, String staff, String atasan) {
    final label = _evLabel(
      _s(_first(m, ['status', 'aksi', 'label', 'judul', 'tipe'])),
    );
    final time = _parseDate(
      _first(m, [
        'waktu',
        'tanggal',
        'timestamp',
        'created_at',
        'dibuat_at',
        'at',
      ]),
    );
    final note = _s(
      _first(m, [
        'catatan',
        'keterangan',
        'note',
        'alasan',
        'pesan',
        'deskripsi',
      ]),
    );
    final oleh = _personFromRaw(
      _first(m, ['oleh_nama', 'oleh', 'by', 'actor', 'user_id', 'uid']),
      _usersById,
    );
    return _Ev(label, time, oleh ?? (_byAtasan(label) ? atasan : staff), note);
  }

  // ───────────────────────────── Unduh & Pratinjau ─────────────────────────────

  String _fileName(Map<String, dynamic> f, Map<String, dynamic> item) {
    var n = _s(f['nama']);
    if (n.isEmpty) {
      final url = _s(f['url']);
      if (url.isNotEmpty) {
        try {
          final segs = Uri.parse(url).pathSegments;
          if (segs.isNotEmpty) n = segs.last.split('/').last;
        } catch (_) {}
      }
    }
    if (n.isEmpty) {
      n = '${_s(item['judul']).replaceAll(RegExp(r'[^\w\-]+'), '_')}_Hasil';
    }
    if (_extOf(n).isEmpty) n = '$n.${_extFromMime(_s(f['mime']))}';
    return n;
  }

  /// Untuk file yang hanya punya path (Supabase): minta URL sementara dulu.
  Future<Map<String, dynamic>> _resolveFile(Map<String, dynamic> f) async {
    if (_s(f['url']).isNotEmpty || _s(f['b64']).isNotEmpty) return f;
    final aid = _s(f['aid']);
    final path = _s(f['path']);
    if (aid.isEmpty || path.isEmpty) return f;
    try {
      final url = await ambilUrlFileHasil(aid, path: path);
      return {...f, 'url': url};
    } catch (e) {
      debugPrint('[riwayat] gagal ambil url file: $e');
      return f;
    }
  }

  Future<Uint8List?> _fileBytes(Map<String, dynamic> f) async {
    final b64 = _s(f['b64']);
    if (b64.isNotEmpty) {
      try {
        return base64Decode(b64.replaceAll(RegExp(r'\s'), ''));
      } catch (_) {
        return null;
      }
    }
    final url = _s(f['url']);
    if (url.isEmpty) return null;
    try {
      final r = await http.get(Uri.parse(url));
      if (r.statusCode == 200) return r.bodyBytes;
    } catch (_) {}
    return null;
  }

  Future<void> _downloadFile(
    BuildContext ctx,
    Map<String, dynamic> f,
    String name,
  ) async {
    final messenger = ScaffoldMessenger.of(ctx);
    messenger.showSnackBar(SnackBar(content: Text('Mengunduh $name...')));

    f = await _resolveFile(f);
    final bytes = await _fileBytes(f);
    if (bytes != null) {
      final ext = _extOf(name);
      final base = ext.isEmpty
          ? name
          : name.substring(0, name.length - ext.length - 1);
      try {
        await FileSaver.instance.saveFile(
          name: base,
          bytes: bytes,
          ext: ext,
          mimeType: MimeType.other,
        );
        messenger.showSnackBar(
          SnackBar(content: Text('File "$name" berhasil diunduh')),
        );
        return;
      } catch (_) {}
    }

    // Cadangan: buka tautan di browser agar bisa disimpan manual.
    final url = _s(f['url']);
    if (url.isNotEmpty) {
      try {
        if (await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        )) {
          return;
        }
      } catch (_) {}
    }
    messenger.showSnackBar(
      const SnackBar(content: Text('Gagal mengunduh file')),
    );
  }

  Future<void> _previewFile(
    BuildContext ctx,
    Map<String, dynamic> f,
    String name,
  ) async {
    final messenger = ScaffoldMessenger.of(ctx);
    f = await _resolveFile(f);
    final ext = _extOf(name);
    final url = _s(f['url']);

    if (_isImageExt(ext)) {
      final bytes = _s(f['b64']).isNotEmpty ? await _fileBytes(f) : null;
      if (!ctx.mounted) return;
      showDialog(
        context: ctx,
        builder: (dctx) => Dialog(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
                            color: navy,
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
                    child: bytes != null
                        ? Image.memory(bytes, fit: BoxFit.contain)
                        : Image.network(
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
      return;
    }

    // PDF / dokumen lain: buka di tab/aplikasi pembaca bila punya tautan.
    if (url.isNotEmpty) {
      try {
        if (await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        )) {
          return;
        }
      } catch (_) {}
    }
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Pratinjau untuk file ini belum tersedia, silakan unduh terlebih dahulu.',
        ),
      ),
    );
  }

  // ─────────────────────────────────── Build ───────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final double w = MediaQuery.of(context).size.width;
    final bool showSidebar = w >= _sidebarBreakpoint;

    final Widget bodyContent = Column(
      children: [
        AdminHeader(title: 'Riwayat Tugas Staff', showSidebar: showSidebar),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _firestore.collection('penugasan').snapshots(),
            builder: (context, aSnap) {
              if (aSnap.hasError) {
                return Center(child: Text('Gagal memuat data: ${aSnap.error}'));
              }
              if (!aSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _firestore.collection('tugas').snapshots(),
                builder: (context, tSnap) {
                  if (tSnap.hasError) {
                    return Center(
                      child: Text('Gagal memuat tugas: ${tSnap.error}'),
                    );
                  }
                  if (!tSnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _firestore.collection('users').snapshots(),
                    builder: (context, uSnap) {
                      if (uSnap.hasError) {
                        return Center(
                          child: Text('Gagal memuat user: ${uSnap.error}'),
                        );
                      }
                      if (!uSnap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final tugas = {
                        for (final d in tSnap.data!.docs) d.id: d.data(),
                      };
                      final data = _buildHistory(
                        aSnap.data!.docs,
                        tugas,
                        uSnap.data!.docs,
                      );
                      return _buildMainLayout(data, showSidebar);
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: background,
      drawer: showSidebar
          ? null
          : const AdminSidebar(currentIndex: _sidebarIndex, isDrawer: true),
      body: showSidebar
          ? Row(
              children: [
                const AdminSidebar(currentIndex: _sidebarIndex),
                Expanded(child: bodyContent),
              ],
            )
          : bodyContent,
    );
  }

  Widget _buildMainLayout(List<Map<String, dynamic>> data, bool showSidebar) {
    final q = pencarian.toLowerCase().trim();

    // Daftar tahun yang tersedia dari data (terbaru di atas).
    final years = <int>{DateTime.now().year};
    for (final t in data) {
      final d = t['selesai'] as DateTime?;
      if (d != null) years.add(d.year);
    }
    if (_selectedYear != 0) years.add(_selectedYear);
    final yearList = years.toList()..sort((a, b) => b.compareTo(a));

    // 1) Filter periode (bulan & tahun) -> dipakai juga untuk ringkasan.
    final byPeriod = data.where((t) {
      if (!_periodActive) return true;
      final d = t['selesai'] as DateTime?;
      if (d == null) return false;
      if (_selectedMonth != 0 && d.month != _selectedMonth) return false;
      if (_selectedYear != 0 && d.year != _selectedYear) return false;
      return true;
    }).toList();

    // 2) Filter pencarian di atas hasil periode.
    final filtered = byPeriod.where((t) {
      return q.isEmpty ||
          (t['staff'] as String).toLowerCase().contains(q) ||
          (t['judul'] as String).toLowerCase().contains(q);
    }).toList();

    final pages = math.max(1, (filtered.length / _perPage).ceil());
    final pg = page.clamp(0, pages - 1);
    final shown = filtered.skip(pg * _perPage).take(_perPage).toList();

    return SingleChildScrollView(
      padding: EdgeInsets.all(showSidebar ? 20 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _summary(byPeriod, showSidebar),
          const SizedBox(height: 16),
          _filterBar(showSidebar, yearList),
          const SizedBox(height: 16),
          if (showSidebar)
            _tableCard(filtered, shown, pg, pages)
          else
            _mobileList(filtered),
        ],
      ),
    );
  }

  Widget _summary(List<Map<String, dynamic>> base, bool wide) {
    int n(String p) => base
        .where(
          (t) => (t['prioritas'] as String).toLowerCase() == p.toLowerCase(),
        )
        .length;

    Widget _statCard(String label, int value, IconData icon, Color color) {
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

    final cards = <Widget>[
      _statCard('Total Selesai', base.length, Icons.description_rounded, blue),
      _statCard(
        'Prioritas Tinggi',
        n('Tinggi'),
        Icons.local_fire_department_rounded,
        _prioColor('Tinggi'),
      ),
      _statCard(
        'Prioritas Sedang',
        n('Sedang'),
        Icons.event_note_rounded,
        _prioColor('Sedang'),
      ),
      _statCard(
        'Prioritas Rendah',
        n('Rendah'),
        Icons.check_circle_rounded,
        _prioColor('Rendah'),
      ),
    ];

    if (wide) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: cards[i]),
            ],
          ],
        ),
      );
    }

    // Mobile: 2 x 2 supaya angka dan label tetap terbaca.
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 10),
              Expanded(child: cards[1]),
            ],
          ),
        ),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: cards[2]),
              const SizedBox(width: 10),
              Expanded(child: cards[3]),
            ],
          ),
        ),
      ],
    );
  }

  // ───────────────────────── Pencarian + Filter Periode ─────────────────────────

  Widget _searchBar() {
    return Container(
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
        onChanged: (v) => setState(() {
          pencarian = v;
          page = 0;
        }),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Cari nama staff atau judul tugas...',
          hintStyle: TextStyle(
            color: Colors.grey.shade500,
            fontSize: AppTypography.body,
          ),
          prefixIcon: const Icon(Icons.search_rounded, color: blue),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _periodDropdown({
    required int value,
    required List<DropdownMenuItem<int>> items,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
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
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, color: blue),
          style: const TextStyle(
            fontSize: AppTypography.body,
            fontWeight: FontWeight.w600,
            color: navy,
          ),
          items: items,
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }

  Widget _filterBar(bool wide, List<int> yearList) {
    final monthDropdown = _periodDropdown(
      value: _selectedMonth,
      items: [
        const DropdownMenuItem(value: 0, child: Text('Semua Bulan')),
        for (var i = 0; i < 12; i++)
          DropdownMenuItem(value: i + 1, child: Text(_monthNames[i])),
      ],
      onChanged: (v) => setState(() {
        _selectedMonth = v;
        page = 0;
      }),
    );

    final yearDropdown = _periodDropdown(
      value: _selectedYear,
      items: [
        const DropdownMenuItem(value: 0, child: Text('Semua Tahun')),
        for (final y in yearList) DropdownMenuItem(value: y, child: Text('$y')),
      ],
      onChanged: (v) => setState(() {
        _selectedYear = v;
        page = 0;
      }),
    );

    final resetButton = TextButton.icon(
      onPressed: _periodActive
          ? () => setState(() {
              _selectedMonth = 0;
              _selectedYear = 0;
              page = 0;
            })
          : null,
      icon: const Icon(Icons.restart_alt_rounded, size: 18),
      label: const Text('Reset'),
    );

    if (wide) {
      return Row(
        children: [
          Expanded(child: _searchBar()),
          const SizedBox(width: 12),
          const Icon(Icons.filter_alt_rounded, color: blue),
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
        _searchBar(),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: monthDropdown),
            const SizedBox(width: 8),
            Expanded(child: yearDropdown),
          ],
        ),
        Align(alignment: Alignment.centerRight, child: resetButton),
      ],
    );
  }

  Widget _tableCard(
    List<Map<String, dynamic>> all,
    List<Map<String, dynamic>> shown,
    int pg,
    int pages,
  ) {
    Widget head(String t, int flex) => Expanded(
      flex: flex,
      child: Text(
        t,
        style: TextStyle(
          fontSize: AppTypography.small,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade700,
        ),
      ),
    );

    return Container(
      decoration: _card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Riwayat Tugas',
                    style: TextStyle(
                      fontSize: AppTypography.section,
                      fontWeight: FontWeight.bold,
                      color: navy,
                    ),
                  ),
                ),
                _pill(_periodLabel, blue, Icons.calendar_month_rounded),
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
                head('Nama Staff', 22),
                head('Judul Tugas', 24),
                head('Prioritas', 12),
                head('Tanggal Mulai', 13),
                head('Tanggal Selesai', 13),
                head('Status', 11),
              ],
            ),
          ),
          if (shown.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text('Tidak ada riwayat tugas selesai pada periode ini'),
              ),
            )
          else
            for (var i = 0; i < shown.length; i++)
              _tableRow(shown[i], pg * _perPage + i + 1),
          // Pager di tengah, hanya "1/1".
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
            child: Center(child: _pager(pg, pages)),
          ),
        ],
      ),
    );
  }

  Widget _tableRow(Map<String, dynamic> t, int no) {
    return InkWell(
      onTap: () => _showDetailPopup(t),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: Text(
                '$no',
                style: const TextStyle(fontSize: AppTypography.small),
              ),
            ),
            Expanded(
              flex: 22,
              child: Row(
                children: [
                  _avatar(18, t['foto'] as String),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t['staff'] as String,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: AppTypography.small,
                            color: navy,
                          ),
                        ),
                        Text(
                          t['jabatan'] as String,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: AppTypography.caption,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 24,
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Text(
                  t['judul'] as String,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: AppTypography.small),
                ),
              ),
            ),
            Expanded(
              flex: 12,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _prioPill(t['prioritas'] as String),
              ),
            ),
            Expanded(
              flex: 13,
              child: Text(
                _fmt(t['mulai'] as DateTime?),
                style: const TextStyle(fontSize: AppTypography.small),
              ),
            ),
            Expanded(
              flex: 13,
              child: Text(
                _fmt(t['selesai'] as DateTime?),
                style: const TextStyle(fontSize: AppTypography.small),
              ),
            ),
            Expanded(
              flex: 11,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _donePill('Selesai'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pager(int pg, int pages) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        onPressed: pg > 0 ? () => setState(() => page = pg - 1) : null,
        icon: const Icon(Icons.chevron_left),
      ),
      Text(
        '${pg + 1}/$pages',
        style: const TextStyle(fontWeight: FontWeight.bold, color: navy),
      ),
      IconButton(
        onPressed: pg < pages - 1 ? () => setState(() => page = pg + 1) : null,
        icon: const Icon(Icons.chevron_right),
      ),
    ],
  );

  Widget _mobileList(List<Map<String, dynamic>> list) {
    if (list.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: Text('Tidak ada riwayat tugas pada periode ini')),
      );
    }
    return Column(
      children: list
          .map(
            (t) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: _card(),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _showDetailPopup(t),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      _avatar(22, t['foto'] as String),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t['judul'] as String,
                              style: const TextStyle(
                                fontSize: AppTypography.body,
                                fontWeight: FontWeight.bold,
                                color: navy,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${t['staff']} • ${t['jabatan']}',
                              style: TextStyle(
                                fontSize: AppTypography.small,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            Text(
                              _fmt(t['selesai'] as DateTime?),
                              style: TextStyle(
                                fontSize: AppTypography.small,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _donePill('Selesai'),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  // ─────────────────────────── Pop-up Dialog Detail ───────────────────────────

  void _showDetailPopup(Map<String, dynamic> t) {
    final future = _loadExtra(t);
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
          child: FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
            future: future,
            builder: (c, snap) {
              final loading = snap.connectionState != ConnectionState.done;
              final extra =
                  snap.data ??
                  <String, List<Map<String, dynamic>>>{
                    'sub': <Map<String, dynamic>>[],
                    'kendala': <Map<String, dynamic>>[],
                  };
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Detail Tugas',
                            style: TextStyle(
                              fontSize: AppTypography.section,
                              fontWeight: FontWeight.bold,
                              color: navy,
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
                  if (loading)
                    const LinearProgressIndicator(minHeight: 2)
                  else
                    const Divider(height: 1),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: _detailContent(ctx, t, extra),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String s) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      s,
      style: const TextStyle(
        fontSize: AppTypography.body,
        fontWeight: FontWeight.bold,
        color: navy,
      ),
    ),
  );

  Widget _detailContent(
    BuildContext ctx,
    Map<String, dynamic> t,
    Map<String, List<Map<String, dynamic>>> extra,
  ) {
    final DateTime? tglMulai = t['mulai'] as DateTime?;
    final DateTime? tglSelesai = t['selesai'] as DateTime?;
    final files = List<Map<String, dynamic>>.from(t['files'] as List);
    final events = _buildTimeline(t, extra);
    final rekap = events
        .where((e) => e.label == 'Revisi' || e.label == 'Terkendala')
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Judul (tanpa label "Selesai" di kiri atas).
        Text(
          t['judul'] as String,
          style: const TextStyle(
            fontSize: AppTypography.subtitle,
            fontWeight: FontWeight.bold,
            color: navy,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _avatar(20, t['foto'] as String),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t['jabatan'] as String,
                    style: TextStyle(
                      fontSize: AppTypography.small,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    t['staff'] as String,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: AppTypography.body,
                      color: navy,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(Icons.assignment_ind_rounded, size: 15, color: blue),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Diberikan oleh: ${t['atasan']}',
                style: const TextStyle(fontSize: AppTypography.small),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.calendar_today_rounded, size: 15, color: blue),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${_fmt(tglMulai)} – ${_fmt(tglSelesai)}',
                style: const TextStyle(fontSize: AppTypography.small),
              ),
            ),
          ],
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
                  _prioPill(t['prioritas'] as String),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [_sectionTitle('Status'), _donePill('Selesai')],
              ),
            ),
          ],
        ),
        const Divider(height: 28),
        _sectionTitle('Deskripsi Tugas'),
        Text(
          t['deskripsi'] as String,
          style: TextStyle(
            fontSize: AppTypography.small,
            height: 1.4,
            color: Colors.grey.shade700,
          ),
        ),
        const Divider(height: 28),
        _sectionTitle('Lampiran Hasil Pekerjaan'),
        if (files.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF3FC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Tidak ada lampiran hasil pekerjaan.',
              style: TextStyle(
                fontSize: AppTypography.small,
                color: Colors.grey.shade600,
              ),
            ),
          )
        else
          for (final f in files) _fileCard(ctx, f, t),
        const Divider(height: 28),
        _sectionTitle('Rekap Revisi & Kendala'),
        _rekapSection(rekap),
        const Divider(height: 28),
        _sectionTitle('Riwayat Status'),
        const SizedBox(height: 4),
        for (var i = 0; i < events.length; i++)
          _timelineRow(events[i], isLast: i == events.length - 1),
      ],
    );
  }

  Widget _fileCard(
    BuildContext ctx,
    Map<String, dynamic> f,
    Map<String, dynamic> item,
  ) {
    final name = _fileName(f, item);
    final ext = _extOf(name);
    final info = _s(f['b64']).isNotEmpty
        ? '${ext.toUpperCase()} • ${_fmtSize(_s(f['b64']).length * 3 ~/ 4)}'
        : ext.toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3FC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: sky.withOpacity(.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _isImageExt(ext)
                  ? Icons.image_rounded
                  : Icons.description_rounded,
              color: blue,
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
                    fontSize: AppTypography.small,
                    fontWeight: FontWeight.w600,
                    color: navy,
                  ),
                ),
                Text(
                  info,
                  style: TextStyle(
                    fontSize: AppTypography.caption,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Lihat',
            onPressed: () => _previewFile(ctx, f, name),
            icon: const Icon(Icons.visibility_rounded, color: blue),
          ),
          IconButton(
            tooltip: 'Unduh',
            onPressed: () => _downloadFile(ctx, f, name),
            icon: const Icon(Icons.download_rounded, color: blue),
          ),
        ],
      ),
    );
  }

  Widget _rekapSection(List<_Ev> rekap) {
    final jmlRevisi = rekap.where((e) => e.label == 'Revisi').length;
    final jmlKendala = rekap.where((e) => e.label == 'Terkendala').length;

    if (rekap.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.verified_rounded,
              size: 18,
              color: Colors.green.shade700,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Tidak ada revisi maupun kendala selama pengerjaan.',
                style: TextStyle(
                  fontSize: AppTypography.small,
                  color: Colors.green.shade800,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _pill(
              'Revisi: $jmlRevisi kali',
              _evColor('Revisi'),
              _evIcon('Revisi'),
            ),
            _pill(
              'Kendala: $jmlKendala kali',
              _evColor('Terkendala'),
              _evIcon('Terkendala'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (final e in rekap)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _evColor(e.label).withOpacity(.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _evColor(e.label).withOpacity(.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _pill(e.label, _evColor(e.label), _evIcon(e.label)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _fmtDT(e.time),
                        style: TextStyle(
                          fontSize: AppTypography.caption,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  e.note.isEmpty ? 'Tanpa catatan.' : e.note,
                  style: TextStyle(
                    fontSize: AppTypography.small,
                    height: 1.4,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  e.label == 'Revisi'
                      ? 'Diminta oleh: ${e.actor}'
                      : 'Dilaporkan oleh: ${e.actor}',
                  style: TextStyle(
                    fontSize: AppTypography.caption,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _timelineRow(_Ev e, {required bool isLast}) {
    final color = _evColor(e.label);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Icon(_evIcon(e.label), size: 20, color: color),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    color: color.withOpacity(.25),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.label == 'Disetujui' ? 'Disetujui (Di-ACC)' : e.label,
                    style: TextStyle(
                      fontSize: AppTypography.small,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  Text(
                    _fmtDT(e.time),
                    style: TextStyle(
                      fontSize: AppTypography.caption,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  Text(
                    'Oleh: ${e.actor}',
                    style: TextStyle(
                      fontSize: AppTypography.caption,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  if (e.note.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withOpacity(.07),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        e.note,
                        style: TextStyle(
                          fontSize: AppTypography.small,
                          height: 1.35,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
