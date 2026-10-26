import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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

class TugasStaffPage extends StatefulWidget {
  const TugasStaffPage({super.key});

  @override
  State<TugasStaffPage> createState() => _TugasStaffPageState();
}

class _TugasStaffPageState extends State<TugasStaffPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _filterAktif = 'Semua';

  Stream<QuerySnapshot<Map<String, dynamic>>> get _assignmentStream {
    final user = _auth.currentUser;
    if (user == null) {
      return const Stream.empty();
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
    Map<String, dynamic> adminData = {};

    if (adminId.isNotEmpty) {
      final adminDoc = await _firestore.collection('users').doc(adminId).get();
      adminData = adminDoc.data() ?? {};
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
      'nama_atasan': adminData['nama'] ?? '-',
      'status': assignmentData['status'] ?? 'pending',
      'file_hasil_url': assignmentData['file_hasil_url'],
      'file_hasil_nama': assignmentData['file_hasil_nama'],
      'catatan_staff': assignmentData['catatan_staff'],
      'catatan_revisi': assignmentData['catatan_revisi'],
    };
  }

  Future<List<TugasModel>> _loadTasks(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> assignments,
  ) async {
    final List<TugasModel> result = [];

    for (final assignment in assignments) {
      try {
        final data = await _buildTaskData(assignment);
        final status = (data['status'] ?? 'pending').toString().toLowerCase();

        if (status == 'disetujui') {
          continue;
        }

        result.add(
          TugasModel(
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
          ),
        );
      } catch (_) {}
    }

    return result;
  }

  List<TugasModel> _filterTasks(List<TugasModel> tasks) {
    if (_filterAktif == 'Semua') {
      return tasks;
    }

    if (_filterAktif == 'Dikumpulkan') {
      return tasks.where((task) {
        return task.statusTugas == 'dikumpulkan' ||
            task.statusTugas == 'revisi';
      }).toList();
    }

    if (_filterAktif == 'Terkendala') {
      return tasks.where((task) => task.statusTugas == 'terkendala').toList();
    }

    return tasks.where((task) {
      return _displayStatus(task.statusTugas) == _filterAktif;
    }).toList();
  }

  String _displayStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'berlangsung':
        return 'Berlangsung';
      case 'dikumpulkan':
      case 'revisi':
        return 'Dikumpulkan';
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
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _assignmentStream,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Gagal memuat tugas:\n${snapshot.error}',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12 * scale),
                            ),
                          );
                        }

                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final assignments = snapshot.data?.docs ?? [];

                        return FutureBuilder<List<TugasModel>>(
                          future: _loadTasks(assignments),
                          builder: (context, taskSnapshot) {
                            if (taskSnapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            if (taskSnapshot.hasError) {
                              return Center(
                                child: Text(
                                  'Gagal memuat detail tugas:\n${taskSnapshot.error}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 12 * scale),
                                ),
                              );
                            }

                            final tasks = _filterTasks(taskSnapshot.data ?? []);

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Daftar Tugas',
                                  style: TextStyle(
                                    fontSize: 17 * scale,
                                    fontWeight: FontWeight.bold,
                                    color: kBiruTua,
                                  ),
                                ),
                                SizedBox(height: 14 * scale),
                                Expanded(
                                  child: tasks.isEmpty
                                      ? _EmptyTaskState(
                                          pesan: _getPesanKosong(),
                                        )
                                      : ListView.builder(
                                          padding: EdgeInsets.zero,
                                          itemCount: tasks.length,
                                          itemBuilder: (context, index) {
                                            return _buildTaskCard(
                                              context,
                                              tasks[index],
                                              scale,
                                            );
                                          },
                                        ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterTabs(double scale, double screenWidth) {
    final tabs = [
      'Semua',
      'Pending',
      'Berlangsung',
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
                fontSize: 12.5 * scale,
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

  Widget _buildTaskCard(BuildContext context, TugasModel tugas, double scale) {
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

  Color _warnaStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'berlangsung':
        return kBiruSedang;
      case 'dikumpulkan':
        return Colors.green;
      case 'revisi':
        return Colors.orange.shade800;
      case 'terkendala':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

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
