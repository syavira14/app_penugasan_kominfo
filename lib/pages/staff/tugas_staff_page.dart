import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_layout.dart';
import 'tugas_detail_page.dart';

const Color kBiruTua = Color(0xFF1A1464);
const Color kBiruSedang = Color(0xFF1D5FA0);
const Color kBiruMuda = Color(0xFF4FA6DE);
const Color kBgLight = Color(0xFFF7F9FB);

class TugasModel {
  final String idTugas;
  final String penugasanId;
  final String judulTugas;
  final String deskripsiTugas;
  final String lokasi;
  final DateTime? tanggalDiberikan;
  final DateTime? tanggalMulai;
  final DateTime? tanggalSelesai;
  final String prioritasTugas;
  final String namaAtasan;
  final String statusTugas;
  final String? fileHasil;
  final String? keteranganHasil;
  final String? catatanRevisi;

  const TugasModel({
    required this.idTugas,
    required this.penugasanId,
    required this.judulTugas,
    required this.deskripsiTugas,
    required this.lokasi,
    required this.tanggalDiberikan,
    required this.tanggalMulai,
    required this.tanggalSelesai,
    required this.prioritasTugas,
    required this.namaAtasan,
    required this.statusTugas,
    this.fileHasil,
    this.keteranganHasil,
    this.catatanRevisi,
  });
}

enum _UrutTugas { terbaru, terlama, namaAZ, prioritas }

String _namaUrut(_UrutTugas u) {
  switch (u) {
    case _UrutTugas.terbaru:
      return 'Terbaru';
    case _UrutTugas.terlama:
      return 'Terlama';
    case _UrutTugas.namaAZ:
      return 'Nama A-Z';
    case _UrutTugas.prioritas:
      return 'Prioritas';
  }
}

int _bobotPrioritas(String p) {
  switch (p.toLowerCase()) {
    case 'tinggi':
      return 3;
    case 'rendah':
      return 1;
    default:
      return 2;
  }
}

class TugasStaffPage extends StatefulWidget {
  const TugasStaffPage({super.key});

  @override
  State<TugasStaffPage> createState() => _TugasStaffPageState();
}

class _TugasStaffPageState extends State<TugasStaffPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _filterAktif = 'Semua';
  _UrutTugas _urut = _UrutTugas.terbaru;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  List<TugasModel> _semuaTugas = const [];
  bool _memuat = true;
  String? _error;
  int _loadVersion = 0;
  final Map<String, String> _namaAdminCache = {};

  @override
  void initState() {
    super.initState();
    _sub = _assignmentStream.listen(
      (snapshot) async {
        final version = ++_loadVersion;
        try {
          final tasks = await _loadTasks(snapshot.docs);
          if (!mounted || version != _loadVersion) return;
          setState(() {
            _semuaTugas = tasks;
            _error = null;
            _memuat = false;
          });
        } catch (e) {
          if (!mounted || version != _loadVersion) return;
          setState(() {
            _error = 'Gagal memuat detail tugas:\n$e';
            _memuat = false;
          });
        }
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() {
          _error = 'Gagal memuat tugas:\n$e';
          _memuat = false;
        });
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> get _assignmentStream {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }

    return _firestore
        .collection('penugasan')
        .where('staff_id', isEqualTo: user.uid)
        .snapshots();
  }

  DateTime? _asDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    return null;
  }

  Future<Map<String, dynamic>> _buildTaskData(
    QueryDocumentSnapshot<Map<String, dynamic>> assignment,
  ) async {
    final assignmentData = assignment.data();
    final tugasId = (assignmentData['tugas_id'] ?? '').toString();

    final tugasDoc = await _firestore.collection('tugas').doc(tugasId).get();
    final tugasData = tugasDoc.data() ?? {};

    final adminId = (tugasData['dibuat_oleh'] ?? '').toString();
    String namaAdmin = '-';

    if (adminId.isNotEmpty) {
      final cached = _namaAdminCache[adminId];
      if (cached != null) {
        namaAdmin = cached;
      } else {
        final adminDoc = await _firestore
            .collection('users')
            .doc(adminId)
            .get();
        namaAdmin = (adminDoc.data()?['nama'] ?? '-').toString();
        _namaAdminCache[adminId] = namaAdmin;
      }
    }

    return {
      'assignment_id': assignment.id,
      'tugas_id': tugasId,
      'judul': tugasData['judul'] ?? '',
      'deskripsi': tugasData['deskripsi'] ?? '',
      'tempat_tugas': tugasData['tempat_tugas'] ?? '',
      'tanggal_tugas_diberikan': tugasData['tanggal_tugas_diberikan'],
      'tanggal_mulai_tugas': tugasData['tanggal_mulai_tugas'],
      'tanggal_selesai_tugas': tugasData['tanggal_selesai_tugas'],
      'prioritas': tugasData['prioritas'] ?? 'sedang',
      'nama_atasan': namaAdmin,
      'status': assignmentData['status'] ?? 'pending',
      'tanggal_dihentikan': assignmentData['tanggal_dihentikan'],
      'file_hasil_url': assignmentData['file_hasil_url'],
      'file_hasil_nama': assignmentData['file_hasil_nama'],
      'catatan_staff': assignmentData['catatan_staff'],
      'catatan_revisi': assignmentData['catatan_revisi'],
    };
  }

  Future<List<TugasModel>> _loadTasks(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> assignments,
  ) async {
    // Dimuat paralel agar tidak menunggu satu per satu.
    final hasil = await Future.wait(assignments.map(_muatSatuTugas));
    return hasil.whereType<TugasModel>().toList();
  }

  Future<TugasModel?> _muatSatuTugas(
    QueryDocumentSnapshot<Map<String, dynamic>> assignment,
  ) async {
    try {
      final data = await _buildTaskData(assignment);
      final status = (data['status'] ?? 'pending').toString().toLowerCase();

      if (status == 'disetujui') return null;

      return TugasModel(
        idTugas: data['tugas_id'].toString(),
        penugasanId: data['assignment_id'].toString(),
        judulTugas: data['judul'].toString(),
        deskripsiTugas: data['deskripsi'].toString(),
        lokasi: data['tempat_tugas'].toString(),
        tanggalDiberikan: _asDate(data['tanggal_tugas_diberikan']),
        tanggalMulai: _asDate(data['tanggal_mulai_tugas']),
        tanggalSelesai: _asDate(data['tanggal_selesai_tugas']),
        prioritasTugas: data['prioritas'].toString(),
        namaAtasan: data['nama_atasan'].toString(),
        statusTugas: status,
        fileHasil: data['file_hasil_nama']?.toString(),
        keteranganHasil: data['catatan_staff']?.toString(),
        catatanRevisi: data['catatan_revisi']?.toString(),
      );
    } catch (_) {
      return null;
    }
  }

  List<TugasModel> _filterTasks(List<TugasModel> tasks) {
    final List<TugasModel> hasil;

    if (_filterAktif == 'Semua') {
      hasil = List<TugasModel>.of(tasks);
    } else if (_filterAktif == 'Dikumpulkan') {
      hasil = tasks.where((t) => t.statusTugas == 'dikumpulkan').toList();
    } else if (_filterAktif == 'Revisi') {
      hasil = tasks.where((t) => t.statusTugas == 'revisi').toList();
    } else if (_filterAktif == 'Terkendala') {
      hasil = tasks.where((t) => t.statusTugas == 'terkendala').toList();
    } else {
      // Pending juga memuat tugas yang dihentikan atasan.
      hasil = tasks
          .where((t) => _displayStatus(t.statusTugas) == _filterAktif)
          .toList();
    }

    _urutkan(hasil);
    return hasil;
  }

  /// Tugas yang baru dibuat belum punya tanggal dari server (null) sehingga
  /// dianggap paling baru dan tampil di paling atas.
  DateTime _tglBuat(TugasModel t) => t.tanggalDiberikan ?? DateTime.now();

  void _urutkan(List<TugasModel> list) {
    int terbaruDulu(TugasModel a, TugasModel b) =>
        _tglBuat(b).compareTo(_tglBuat(a));

    switch (_urut) {
      case _UrutTugas.terbaru:
        list.sort(terbaruDulu);
        break;
      case _UrutTugas.terlama:
        list.sort((a, b) => _tglBuat(a).compareTo(_tglBuat(b)));
        break;
      case _UrutTugas.namaAZ:
        list.sort((a, b) {
          final c = a.judulTugas.toLowerCase().compareTo(
            b.judulTugas.toLowerCase(),
          );
          return c != 0 ? c : terbaruDulu(a, b);
        });
        break;
      case _UrutTugas.prioritas:
        list.sort((a, b) {
          final c = _bobotPrioritas(
            b.prioritasTugas,
          ).compareTo(_bobotPrioritas(a.prioritasTugas));
          return c != 0 ? c : terbaruDulu(a, b);
        });
        break;
    }
  }

  String _displayStatus(String status) {
    switch (status.toLowerCase()) {
      // Tugas yang dihentikan atasan ditampilkan sebagai Pending.
      case 'dihentikan':
      case 'pending':
        return 'Pending';
      case 'berlangsung':
        return 'Berlangsung';
      case 'dikumpulkan':
        return 'Dikumpulkan';
      case 'revisi':
        return 'Revisi';
      case 'terkendala':
        return 'Terkendala';
      default:
        return status;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _formatDateTime(DateTime? date) {
    if (date == null) return '-';
    return '${_formatDate(date)} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  String _getPesanKosong() {
    switch (_filterAktif) {
      case 'Terkendala':
        return 'Belum ada tugas yang terkendala';
      case 'Dikumpulkan':
        return 'Belum ada tugas yang dikumpulkan';
      case 'Revisi':
        return 'Belum ada tugas yang perlu direvisi';
      case 'Pending':
      case 'Berlangsung':
      case 'Semua':
      default:
        return 'Belum ada tugas';
    }
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final double scale = (width / 375).clamp(0.85, 1.25);

    return Scaffold(
      backgroundColor: kBgLight,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            children: [
              // HEADER GRADIENT
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Title Bar dengan ResponsiveContent agar persis sama dengan Dashboard
                        ResponsiveContent(
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
                                    'Tugas Saya',
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
                        SizedBox(height: 16 * scale),
                        // Filter Tabs
                        _buildFilterTabs(scale, width),
                      ],
                    ),
                  ),
                ),
              ),

              // AREA UTAMA KONTEN (DAFTAR TUGAS)
              Expanded(
                child: ResponsiveContent(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(0, 16 * scale, 0, 12 * scale),
                    child: _buildDaftar(scale),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDaftar(double scale) {
    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12 * scale),
        ),
      );
    }

    if (_memuat) {
      return const Center(child: CircularProgressIndicator());
    }

    final tasks = _filterTasks(_semuaTugas);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Daftar Tugas',
                style: TextStyle(
                  fontSize: 17 * scale,
                  fontWeight: FontWeight.bold,
                  color: kBiruTua,
                ),
              ),
            ),
            _buildUrutDropdown(scale),
          ],
        ),
        SizedBox(height: 14 * scale),
        Expanded(
          child: tasks.isEmpty
              ? _EmptyTaskState(pesan: _getPesanKosong())
              : ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    return _buildTaskCard(context, tasks[index], scale);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildUrutDropdown(double scale) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14 * scale),
        border: Border.all(color: kBiruSedang.withOpacity(.25)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<_UrutTugas>(
          value: _urut,
          isDense: true,
          borderRadius: BorderRadius.circular(14 * scale),
          dropdownColor: Colors.white,
          icon: Icon(Icons.sort_rounded, color: kBiruSedang, size: 20 * scale),
          style: TextStyle(
            fontSize: 13 * scale,
            fontWeight: FontWeight.bold,
            color: kBiruTua,
          ),
          items: _UrutTugas.values
              .map(
                (u) => DropdownMenuItem<_UrutTugas>(
                  value: u,
                  child: Text(_namaUrut(u)),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            setState(() => _urut = v);
          },
        ),
      ),
    );
  }

  Widget _buildFilterTabs(double scale, double screenWidth) {
    final tabs = [
      'Semua',
      'Pending',
      'Berlangsung',
      'Revisi',
      'Terkendala',
      'Dikumpulkan',
    ];

    final listItems = tabs.map((tab) {
      final bool aktif = tab == _filterAktif;

      return Padding(
        padding: EdgeInsets.only(right: 8 * scale),
        child: InkWell(
          borderRadius: BorderRadius.circular(15 * scale),
          onTap: () {
            setState(() {
              _filterAktif = tab;
            });
          },
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: 16 * scale,
              vertical: 9 * scale,
            ),
            decoration: BoxDecoration(
              color: aktif ? Colors.white : Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(15 * scale),
            ),
            child: Text(
              tab,
              style: TextStyle(
                color: aktif ? kBiruTua : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14 * scale,
              ),
            ),
          ),
        ),
      );
    }).toList();

    // Di layar desktop (>= 600px): Rata tengah
    if (screenWidth >= 600) {
      return ResponsiveContent(
        child: Center(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: listItems,
            ),
          ),
        ),
      );
    }

    // Di layar mobile (< 600px): Menggunakan ResponsiveContent agar padding horizontal sama persis dengan konten Dashboard
    return ResponsiveContent(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: listItems,
        ),
      ),
    );
  }

  Widget _buildTaskCard(BuildContext context, TugasModel tugas, double base) {
    // Semua filter memakai ukuran besar yang sama agar mudah dibaca (usia 40+).
    final double scale = (base * 1.25).clamp(1.0, 1.5);
    final statusColor = _warnaStatus(tugas.statusTugas);
    final prioritasColor = _warnaPrioritas(tugas.prioritasTugas);

    return InkWell(
      borderRadius: BorderRadius.circular(20 * scale),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TugasDetailPage(penugasanId: tugas.penugasanId),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 16 * scale),
        padding: EdgeInsets.all(16 * scale),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20 * scale),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    tugas.judulTugas,
                    style: TextStyle(
                      fontSize: 15 * scale,
                      fontWeight: FontWeight.bold,
                      color: kBiruTua,
                    ),
                  ),
                ),
                _badge(_displayStatus(tugas.statusTugas), statusColor, scale),
              ],
            ),
            SizedBox(height: 9 * scale),
            Text(
              tugas.deskripsiTugas,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12 * scale,
                color: Colors.grey.shade700,
              ),
            ),
            SizedBox(height: 12 * scale),
            _row(Icons.person_outline, 'Atasan', tugas.namaAtasan, scale),
            SizedBox(height: 7 * scale),
            _row(Icons.location_on_outlined, 'Lokasi', tugas.lokasi, scale),
            SizedBox(height: 7 * scale),
            _row(
              Icons.calendar_today_outlined,
              'Mulai',
              _formatDateTime(tugas.tanggalMulai),
              scale,
            ),
            SizedBox(height: 7 * scale),
            _row(
              Icons.event_available_outlined,
              'Batas',
              _formatDateTime(tugas.tanggalSelesai),
              scale,
              highlight:
                  tugas.tanggalSelesai != null &&
                  tugas.tanggalSelesai!.isBefore(DateTime.now()) &&
                  tugas.statusTugas != 'dikumpulkan' &&
                  tugas.statusTugas != 'disetujui',
            ),
            SizedBox(height: 10 * scale),
            _badge('Prioritas ${tugas.prioritasTugas}', prioritasColor, scale),
            if (tugas.statusTugas == 'revisi' &&
                (tugas.catatanRevisi ?? '').isNotEmpty) ...[
              SizedBox(height: 10 * scale),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(10 * scale),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(.08),
                  borderRadius: BorderRadius.circular(10 * scale),
                ),
                child: Text(
                  'Catatan revisi: ${tugas.catatanRevisi}',
                  style: TextStyle(
                    fontSize: 11.5 * scale,
                    color: Colors.orange.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _warnaStatus(String status) => AppTaskStatus.color(status);

  Color _warnaPrioritas(String prioritas) {
    switch (prioritas.toLowerCase()) {
      case 'tinggi':
        return Colors.red;
      case 'rendah':
        return Colors.green;
      default:
        return Colors.orange;
    }
  }

  Widget _badge(String text, Color color, double scale) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 10 * scale,
        vertical: 5 * scale,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(.1),
        borderRadius: BorderRadius.circular(9 * scale),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10.5 * scale,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _row(
    IconData icon,
    String label,
    String value,
    double scale, {
    bool highlight = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 14 * scale,
          color: highlight ? Colors.redAccent : Colors.grey[500],
        ),
        SizedBox(width: 7 * scale),
        Text(
          '$label: ',
          style: TextStyle(color: Colors.grey[600], fontSize: 11 * scale),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: highlight ? Colors.redAccent : Colors.black87,
              fontSize: 11 * scale,
              fontWeight: highlight ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyTaskState extends StatelessWidget {
  final String pesan;

  const _EmptyTaskState({required this.pesan});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 52,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          Text(
            pesan,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}
