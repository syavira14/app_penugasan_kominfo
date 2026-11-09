import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../services/file_preview_service.dart';
import '../../services/riwayat_file_service.dart';
import '../../services/riwayat_penugasan_service.dart';
import '../../services/staff_admin_api.dart';
import '../../services/supabase_storage_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_layout.dart';
import '../../widgets/simtas_file_preview_page.dart';

// ───────────────────────── Warna (disamakan dengan staff_kalender) ─────────────────────────
const Color kBiruTua = Color(0xFF1A1464);
const Color kBiruSedang = Color(0xFF1D5FA0);
const Color kBiruMuda = Color(0xFF4FA6DE);
const Color kBgLight = Color(0xFFF7F9FB);

const _historyKeys = [
  'riwayat_status',
  'riwayat',
  'log_status',
  'timeline',
  'history',
  'status_history',
];

String _s(dynamic v) => (v ?? '').toString().trim();

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

/// Satu kejadian pada alur status sebuah tugas (step-by-step Riwayat Status).
class _Ev {
  final String label;
  final DateTime? time;
  final String actor;
  final String note;
  const _Ev(this.label, this.time, this.actor, this.note);
}

String _evLabel(String raw) {
  final r = raw.toLowerCase();
  if (r.contains('tolak')) return 'Kendala Ditolak';
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
    label == 'Diberikan' ||
    label == 'Revisi' ||
    label == 'Disetujui' ||
    label == 'Kendala Ditolak';

Color _evColor(String label) {
  switch (label) {
    case 'Diberikan':
      return AppPalette.blue;
    case 'Dikerjakan':
      return Colors.orange.shade800;
    case 'Terkendala':
      return Colors.red.shade700;
    case 'Kendala Ditolak':
      return const Color(0xFFB42318);
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
    case 'Kendala Ditolak':
      return Icons.cancel_rounded;
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

String _statusKendalaLabel(String raw) {
  switch (raw.toLowerCase()) {
    case 'menunggu_review':
      return 'Menunggu Review';
    case 'dalam_penanganan':
      return 'Dalam Penanganan';
    case 'menunggu_konfirmasi':
      return 'Menunggu Konfirmasi';
    case 'selesai':
      return 'Selesai';
    case 'ditolak':
      return 'Ditolak';
    default:
      return raw.isEmpty ? '-' : raw;
  }
}

// ───────────────────────────────── Model ─────────────────────────────────
class TugasModel {
  final String id;
  final String tugasId;
  final String staffUid;
  final String namaStaff;
  final String judulTugas;
  final String deskripsiTugas;
  final String namaAtasan;
  final String prioritasTugas; // "Rendah", "Sedang", "Tinggi"
  final String statusAkhir;
  final DateTime? tanggalMulai;
  final DateTime? batasWaktu;
  final String keteranganHasil;
  final String fileHasil;
  final String fileHasilUrl;
  final String fileHasilPath;
  final Map<String, dynamic> rawAssignment;
  final Map<String, dynamic> rawTask;

  const TugasModel({
    required this.id,
    this.tugasId = '',
    this.staffUid = '',
    this.namaStaff = 'Staff',
    required this.judulTugas,
    required this.deskripsiTugas,
    required this.namaAtasan,
    required this.prioritasTugas,
    this.statusAkhir = 'disetujui',
    required this.tanggalMulai,
    required this.batasWaktu,
    this.keteranganHasil = '',
    this.fileHasil = '',
    this.fileHasilUrl = '',
    this.fileHasilPath = '',
    this.rawAssignment = const {},
    this.rawTask = const {},
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

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SupabaseStorageService _storage = SupabaseStorageService();

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
                tugasId: (row['tugas_id'] ?? '').toString(),
                staffUid: (row['staff_uid'] ?? uid).toString(),
                namaStaff: (row['nama_staff'] ?? 'Staff').toString(),
                judulTugas: (row['judul'] ?? '-').toString(),
                deskripsiTugas: (row['deskripsi'] ?? '-').toString(),
                namaAtasan: (row['nama_atasan'] ?? '-').toString(),
                prioritasTugas: _title(
                  (row['prioritas'] ?? 'sedang').toString(),
                ),
                statusAkhir:
                    (row['status_akhir'] ?? row['status'] ?? 'disetujui')
                        .toString(),
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
                rawAssignment: row['raw_assignment'] is Map
                    ? Map<String, dynamic>.from(row['raw_assignment'] as Map)
                    : row,
                rawTask: row['raw_task'] is Map
                    ? Map<String, dynamic>.from(row['raw_task'] as Map)
                    : row,
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

  DateTime? _date(dynamic value) => _parseDate(value);

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

  Widget _donePill(double scale, [String statusAkhir = 'disetujui']) {
    final bool stopped = statusAkhir.toLowerCase() == 'dihentikan';
    return _pill(
      stopped ? 'Dihentikan' : 'Selesai',
      stopped ? Colors.red.shade700 : Colors.green.shade700,
      stopped ? Icons.stop_circle_rounded : Icons.check_circle,
      scale,
    );
  }

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
    return '$base, ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
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
      try {
        return await SupabaseStorageService().buatLinkSementara(
          t.fileHasilPath,
        );
      } catch (_) {
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

  // ─────────────────────── Muat Riwayat Status Step-by-Step ───────────────────────

  Future<Map<String, List<Map<String, dynamic>>>> _loadExtra(
    TugasModel t,
  ) async {
    final id = t.id;
    final tid = t.tugasId;
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? t.staffUid;

    final sub = <Map<String, dynamic>>[];
    final kendala = <Map<String, dynamic>>[];
    final pengumpulan = <Map<String, dynamic>>[];
    final revisi = <Map<String, dynamic>>[];

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

    // Ambil seluruh laporan kendala (termasuk kendala berulang di sub-koleksi `riwayat`
    // maupun kendala yang dilaporkan sebelum akun staf di-reset password-nya)
    // agar hasilnya sama persis dengan Riwayat Tugas Staff di Role Atasan.
    try {
      final fetchedKendala = await StaffAdminApi.fetchKendalaForPenugasan(
        penugasanId: id,
        tugasId: tid,
        currentUid: currentUid,
        staffUid: t.staffUid,
        staffNama: t.namaStaff,
        rawTask: t.rawTask,
        rawAssignment: t.rawAssignment,
      );
      kendala.addAll(fetchedKendala);
    } catch (_) {}

    try {
      final snap = await _firestore
          .collection('penugasan')
          .doc(id)
          .collection('riwayat_pengumpulan')
          .get();
      for (final doc in snap.docs) {
        pengumpulan.add({'_id': doc.id, ...doc.data()});
      }
      pengumpulan.sort(
        (a, b) => (_parseDate(a['created_at']) ?? DateTime(1970)).compareTo(
          _parseDate(b['created_at']) ?? DateTime(1970),
        ),
      );
    } catch (_) {}

    try {
      final snap = await _firestore
          .collection('penugasan')
          .doc(id)
          .collection('riwayat_revisi')
          .get();
      for (final doc in snap.docs) {
        revisi.add({'_id': doc.id, ...doc.data()});
      }
      revisi.sort(
        (a, b) => (_parseDate(a['created_at']) ?? DateTime(1970)).compareTo(
          _parseDate(b['created_at']) ?? DateTime(1970),
        ),
      );
    } catch (_) {}

    return {
      'sub': sub,
      'kendala': kendala,
      'pengumpulan': pengumpulan,
      'revisi': revisi,
    };
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
    final rawOleh = _s(_first(m, ['oleh_nama', 'oleh', 'by', 'actor']));
    return _Ev(
      label,
      time,
      rawOleh.isNotEmpty ? rawOleh : (_byAtasan(label) ? atasan : staff),
      note,
    );
  }

  List<_Ev> _buildTimeline(
    TugasModel t,
    Map<String, List<Map<String, dynamic>>> extra,
  ) {
    final a = t.rawAssignment;
    final tk = t.rawTask;
    final staff = t.namaStaff;
    final atasan = t.namaAtasan;
    final mulai = t.tanggalMulai;
    final selesai = t.batasWaktu;

    final DateTime? waktuDiberikan =
        _parseDate(
          _first(tk, ['tanggal_tugas_diberikan', 'created_at']) ??
              _first(a, ['created_at', 'tanggal_diberikan', 'assigned_at']),
        ) ??
        mulai;

    final DateTime? waktuDisetujui =
        _parseDate(
          _first(a, [
            'tanggal_disetujui',
            'disetujui_at',
            'approved_at',
            'selesai_at',
            'updated_at',
          ]),
        ) ??
        selesai;

    _Ev diberikan() => _Ev(
      'Diberikan',
      waktuDiberikan,
      atasan,
      'Tugas diberikan kepada $staff.',
    );

    _Ev disetujui() => _Ev(
      'Disetujui',
      waktuDisetujui,
      atasan,
      _s(_first(a, ['catatan_atasan', 'catatan_persetujuan'])),
    );

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

    final ev = <_Ev>[];

    if (entries.isNotEmpty) {
      if (!entries.any((e) => e.label == 'Diberikan')) ev.add(diberikan());
      ev.addAll(entries);
      if (!ev.any((e) => e.label == 'Disetujui')) ev.add(disetujui());
    } else {
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
          t.keteranganHasil,
        ),
      );
      ev.add(disetujui());
    }

    // Sisipkan riwayat revisi dari sub-koleksi `riwayat_revisi` atau field `catatan_revisi`.
    if (!ev.any((e) => e.label == 'Revisi')) {
      final revList = extra['revisi'] ?? const <Map<String, dynamic>>[];
      final idx = ev.lastIndexWhere((e) => e.label == 'Disetujui');
      var pos = idx < 0 ? ev.length : idx;
      if (revList.isNotEmpty) {
        for (final r in revList) {
          ev.insert(
            pos++,
            _Ev(
              'Revisi',
              _parseDate(_first(r, ['created_at', 'updated_at', 'tanggal'])),
              atasan,
              _s(_first(r, ['catatan_atasan', 'catatan', 'keterangan'])),
            ),
          );
        }
      } else {
        final revisiNote = _s(a['catatan_revisi']);
        if (revisiNote.isNotEmpty) {
          ev.insert(
            pos,
            _Ev(
              'Revisi',
              _parseDate(_first(a, ['tanggal_revisi', 'revisi_at'])),
              atasan,
              revisiNote,
            ),
          );
        }
      }
    }

    // Sisipkan seluruh laporan kendala (termasuk kendala berulang di `_riwayat`
    // serta aksi "Kendala Ditolak" jika laporan kendala ditolak oleh atasan).
    if (!ev.any((e) => e.label == 'Terkendala')) {
      final idx = ev.lastIndexWhere((e) => e.label == 'Disetujui');
      var pos = idx < 0 ? ev.length : idx;
      for (final k in extra['kendala'] ?? const <Map<String, dynamic>>[]) {
        final riwayatLama = k['_riwayat'];
        if (riwayatLama is List) {
          for (final h in riwayatLama) {
            if (h is Map) {
              ev.insert(
                pos++,
                _Ev(
                  'Terkendala',
                  _parseDate(
                    _first(Map<String, dynamic>.from(h), [
                      'created_at',
                      'tanggal',
                      'waktu',
                    ]),
                  ),
                  staff,
                  _s(h['deskripsi_sebelumnya']).isNotEmpty
                      ? _s(h['deskripsi_sebelumnya'])
                      : _s(h['feedback']),
                ),
              );
            }
          }
        }

        final kTime = _parseDate(
          _first(k, [
            'created_at',
            'tanggal_laporan',
            'tanggal',
            'waktu',
            'timestamp',
            'dibuat_at',
          ]),
        );
        final kDesc = _s(
          _first(k, [
            'deskripsi',
            'alasan',
            'keterangan',
            'isi',
            'kendala',
            'catatan',
            'judul',
          ]),
        );
        ev.insert(pos++, _Ev('Terkendala', kTime, staff, kDesc));

        // Jika laporan kendala ditolak oleh atasan, tambahkan step "Kendala Ditolak".
        final kStatus = _s(k['status']).toLowerCase();
        final alasanTolak = _s(k['alasan_penolakan']);
        if (kStatus == 'ditolak' || alasanTolak.isNotEmpty) {
          final rejectTime =
              _parseDate(
                _first(k, ['rejected_at', 'ditolak_at', 'updated_at']),
              ) ??
              kTime;
          ev.insert(
            pos++,
            _Ev(
              'Kendala Ditolak',
              rejectTime,
              atasan,
              alasanTolak.isNotEmpty
                  ? 'Alasan penolakan: $alasanTolak'
                  : 'Laporan kendala ditolak oleh atasan.',
            ),
          );
        }
      }
    }

    // Urutkan stabil berdasarkan waktu; pastikan Diberikan di awal dan Disetujui di akhir.
    DateTime? last;
    final keys = <DateTime>[];
    for (final e in ev) {
      last = e.time ?? last;
      keys.add(last ?? DateTime.fromMillisecondsSinceEpoch(0));
    }
    int stageRank(String label) {
      if (label == 'Diberikan') return 0;
      if (label == 'Disetujui') return 2;
      return 1;
    }

    final idx = List<int>.generate(ev.length, (i) => i)
      ..sort((x, y) {
        final rx = stageRank(ev[x].label);
        final ry = stageRank(ev[y].label);
        if (rx != ry) return rx.compareTo(ry);
        final c = keys[x].compareTo(keys[y]);
        return c != 0 ? c : x.compareTo(y);
      });
    return [for (final i in idx) ev[i]];
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
          // HEADER GRADIENT FLAT
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

    final years = <int>{DateTime.now().year};
    for (final t in _daftarRiwayat) {
      if (t.batasWaktu != null) years.add(t.batasWaktu!.year);
    }
    if (_selectedYear != 0) years.add(_selectedYear);
    final yearList = years.toList()..sort((a, b) => b.compareTo(a));

    final byPeriod = _daftarRiwayat.where((t) {
      if (!_periodActive) return true;
      final d = t.batasWaktu;
      if (d == null) return false;
      if (_selectedMonth != 0 && d.month != _selectedMonth) return false;
      if (_selectedYear != 0 && d.year != _selectedYear) return false;
      return true;
    }).toList();

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

  Widget _searchBar(double scale) => Container(
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
        _pencarian = v;
        _page = 0;
      }),
      decoration: InputDecoration(
        hintText: 'Cari judul tugas atau atasan...',
        hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13 * scale),
        prefixIcon: const Icon(Icons.search_rounded, color: kBiruSedang),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
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
      height: 48,
      padding: EdgeInsets.symmetric(horizontal: 14 * scale),
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
          borderRadius: BorderRadius.circular(16),
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
                child: _donePill(scale, t.statusAkhir),
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
                  _donePill(scale, t.statusAkhir),
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
                'Diberikan: ${_fmt(t.tanggalMulai, jam: true)} WIB',
                scale,
              ),
              SizedBox(height: 4 * scale),
              _infoRow(
                Icons.event_rounded,
                'Batas waktu: ${_fmt(t.batasWaktu, jam: true)} WIB',
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

  // ─────────────────────────── Pop-up Dialog Detail + Step-by-Step Riwayat Status ───────────────────────────

  Widget _sectionTitle(String s) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      s,
      style: const TextStyle(
        fontSize: AppTypography.body,
        fontWeight: FontWeight.bold,
        color: kBiruTua,
      ),
    ),
  );

  Widget _historyCard(String title, List<Widget> children) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF1F6FC),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFD8E7F5)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, color: kBiruTua),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    ),
  );

  Widget _issueHistory(Map<String, List<Map<String, dynamic>>> extra) {
    final issues = extra['kendala'] ?? [];
    if (issues.isEmpty) {
      return const Text(
        'Tidak ada laporan kendala.',
        style: TextStyle(fontSize: 12),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < issues.length; i++) ...[
          Builder(
            builder: (context) {
              final k = issues[i];
              final statusRaw = _s(k['status']);
              final isDitolak =
                  statusRaw.toLowerCase() == 'ditolak' ||
                  _s(k['alasan_penolakan']).isNotEmpty;
              return _historyCard(
                'Laporan Kendala ${i + 1} (${_statusKendalaLabel(statusRaw)})',
                [
                  Text(
                    'Kendala: ${_s(k['deskripsi']).isEmpty ? '-' : _s(k['deskripsi'])}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    'Dampak: ${_s(k['dampak']).isEmpty ? '-' : _s(k['dampak'])}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  if (isDitolak)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Alasan Penolakan Atasan: ${_s(k['alasan_penolakan']).isEmpty ? '-' : _s(k['alasan_penolakan'])}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFB42318),
                        ),
                      ),
                    )
                  else
                    Text(
                      'Solusi Atasan: ${_s(k['solusi']).isEmpty ? '-' : _s(k['solusi'])}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  for (final h
                      in (k['_riwayat'] is List
                          ? k['_riwayat'] as List
                          : const []))
                    if (h is Map) ...[
                      const Divider(height: 18),
                      Text(
                        'Kendala sebelumnya: ${_s(h['deskripsi_sebelumnya'])}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        'Solusi sebelumnya: ${_s(h['solusi_sebelumnya'])}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        'Tanggapan Staff: ${_s(h['feedback'])}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                ],
              );
            },
          ),
        ],
      ],
    );
  }

  void _tampilkanPopUpDetail(TugasModel t) {
    final future = _loadExtra(t);
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 640,
            maxHeight: MediaQuery.of(ctx).size.height * 0.9,
          ),
          child: FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
            future: future,
            builder: (ctx, snap) {
              final loading = snap.connectionState == ConnectionState.waiting;
              final extra =
                  snap.data ??
                  const {
                    'sub': <Map<String, dynamic>>[],
                    'kendala': <Map<String, dynamic>>[],
                    'pengumpulan': <Map<String, dynamic>>[],
                    'revisi': <Map<String, dynamic>>[],
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
                            'Detail Riwayat Tugas',
                            style: TextStyle(
                              fontSize: AppTypography.section,
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

  Widget _detailContent(
    BuildContext ctx,
    TugasModel t,
    Map<String, List<Map<String, dynamic>>> extra,
  ) {
    final events = _buildTimeline(t, extra);
    final rekap = events
        .where(
          (e) =>
              e.label == 'Revisi' ||
              e.label == 'Terkendala' ||
              e.label == 'Kendala Ditolak',
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.judulTugas,
          style: const TextStyle(
            fontSize: AppTypography.subtitle,
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
          Icons.calendar_today_rounded,
          '${_fmt(t.tanggalMulai)} – ${_fmt(t.batasWaktu)}',
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
                children: [
                  _sectionTitle('Status'),
                  _donePill(1, t.statusAkhir),
                ],
              ),
            ),
          ],
        ),
        const Divider(height: 28),
        _sectionTitle('Deskripsi Tugas'),
        Text(
          t.deskripsiTugas,
          style: TextStyle(
            fontSize: AppTypography.small,
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
              fontSize: AppTypography.small,
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
              style: TextStyle(
                fontSize: AppTypography.small,
                color: Colors.grey.shade600,
              ),
            ),
          )
        else
          _fileCard(ctx, t),
        const Divider(height: 28),
        _sectionTitle('Riwayat Kendala & Solusi'),
        _issueHistory(extra),
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

  Widget _rekapSection(List<_Ev> rekap) {
    final jmlRevisi = rekap.where((e) => e.label == 'Revisi').length;
    final jmlKendala = rekap.where((e) => e.label == 'Terkendala').length;
    final jmlDitolak = rekap.where((e) => e.label == 'Kendala Ditolak').length;

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
              1,
            ),
            _pill(
              'Kendala: $jmlKendala kali',
              _evColor('Terkendala'),
              _evIcon('Terkendala'),
              1,
            ),
            if (jmlDitolak > 0)
              _pill(
                'Ditolak: $jmlDitolak kali',
                _evColor('Kendala Ditolak'),
                _evIcon('Kendala Ditolak'),
                1,
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
                    _pill(e.label, _evColor(e.label), _evIcon(e.label), 1),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _fmt(e.time, jam: true),
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
                      : e.label == 'Kendala Ditolak'
                      ? 'Ditolak oleh: ${e.actor}'
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
                    _fmt(e.time, jam: true),
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
