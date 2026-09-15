import 'package:flutter/material.dart';
import 'tugas_detail_page.dart';

/// ==== PALET WARNA KOMINFO (biru gradasi) ====
const Color kBiruTua = Color(0xFF1A1464);
const Color kBiruSedang = Color(0xFF1D5FA0);
const Color kBiruMuda = Color(0xFF4FA6DE);
const Color kBgLight = Color(0xFFF7F9FB);

class TugasModel {
  final int idTugas;
  final int idAtasan;
  final int idStaff;
  final String judulTugas;
  final String deskripsiTugas;
  final String lokasi;
  final DateTime tanggalDiberikan;
  final DateTime tanggalMulai;
  final DateTime batasWaktu;
  final String prioritasTugas; // "Tinggi" | "Sedang" | "Rendah"
  String
  statusTugas; // "Pending" | "Berlangsung" | "Menunggu Disetujui" | "Revisi" | "ACC"
  String? fileHasil;
  String? keteranganHasil;
  final String namaAtasan;

  TugasModel({
    required this.idTugas,
    required this.idAtasan,
    required this.idStaff,
    required this.judulTugas,
    required this.deskripsiTugas,
    required this.lokasi,
    required this.tanggalDiberikan,
    required this.tanggalMulai,
    required this.batasWaktu,
    required this.prioritasTugas,
    required this.statusTugas,
    this.fileHasil,
    this.keteranganHasil,
    required this.namaAtasan,
  });
}

List<TugasModel> dummyTugasStaff() {
  return [
    TugasModel(
      idTugas: 1,
      idAtasan: 101,
      idStaff: 55,
      judulTugas: "Penyusunan Laporan TIK",
      deskripsiTugas: "Susun laporan bulanan penggunaan infrastruktur TIK.",
      lokasi: "Ruang Rapat Lantai 3",
      tanggalDiberikan: DateTime(2026, 8, 25),
      tanggalMulai: DateTime(2026, 8, 28),
      batasWaktu: DateTime(2026, 9, 3, 12, 45),
      prioritasTugas: "Tinggi",
      statusTugas: "Berlangsung",
      namaAtasan: "Saad Ibn Sayeed",
    ),
    TugasModel(
      idTugas: 2,
      idAtasan: 102,
      idStaff: 55,
      judulTugas: "Maintenance Server",
      deskripsiTugas: "Lakukan pemeliharaan rutin server utama.",
      lokasi: "Data Center Kominfo",
      tanggalDiberikan: DateTime(2026, 8, 26),
      tanggalMulai: DateTime(2026, 8, 30),
      batasWaktu: DateTime(2026, 9, 2, 15, 0),
      prioritasTugas: "Sedang",
      statusTugas: "Menunggu Disetujui", // Masuk ke tab "Dikumpulkan"
      fileHasil: "laporan_maintenance.pdf",
      keteranganHasil: "Semua server sudah dicek.",
      namaAtasan: "Jonathan Eve",
    ),
    TugasModel(
      idTugas: 3,
      idAtasan: 103,
      idStaff: 55,
      judulTugas: "Desain Banner Kominfo",
      deskripsiTugas: "Buat desain banner sosialisasi.",
      lokasi: "Ruang Media Center",
      tanggalDiberikan: DateTime(2026, 8, 30),
      tanggalMulai: DateTime(2026, 9, 1),
      batasWaktu: DateTime(2026, 9, 22, 9, 0),
      prioritasTugas: "Rendah",
      statusTugas: "Pending",
      namaAtasan: "Marques Browney",
    ),
    TugasModel(
      idTugas: 4,
      idAtasan: 104,
      idStaff: 55,
      judulTugas: "Revisi Format Dokumen",
      deskripsiTugas: "Perbaiki format tabel pada lampiran 2.",
      lokasi: "Kantor Utama",
      tanggalDiberikan: DateTime(2026, 8, 27),
      tanggalMulai: DateTime(2026, 8, 29),
      batasWaktu: DateTime(2026, 9, 5, 16, 0),
      prioritasTugas: "Tinggi",
      statusTugas: "Revisi", // Masuk ke tab "Dikumpulkan"
      namaAtasan: "Saad Ibn Sayeed",
    ),
  ];
}

class TugasStaffPage extends StatefulWidget {
  const TugasStaffPage({super.key});

  @override
  State<TugasStaffPage> createState() => _TugasStaffPageState();
}

class _TugasStaffPageState extends State<TugasStaffPage> {
  final List<TugasModel> _semuaTugas = dummyTugasStaff();
  String _filterAktif = "Semua";

  // Filter tugas: Mengabaikan tugas yang sudah di-ACC (karena masuk Riwayat)
  List<TugasModel> get _tugasTerfilter {
    final tugasAktif = _semuaTugas
        .where((t) => t.statusTugas != "ACC")
        .toList();

    if (_filterAktif == "Semua") {
      return tugasAktif;
    } else if (_filterAktif == "Dikumpulkan") {
      return tugasAktif
          .where(
            (t) =>
                t.statusTugas == "Menunggu Disetujui" ||
                t.statusTugas == "Revisi",
          )
          .toList();
    } else {
      return tugasAktif.where((t) => t.statusTugas == _filterAktif).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgLight,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double scale = (constraints.maxWidth / 375).clamp(0.85, 1.25);
          return Column(
            children: [
              // ---- HEADER GRADASI ----
              ClipPath(
                clipper: HeaderCurveClipper(),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(
                    20 * scale,
                    16 * scale,
                    20 * scale,
                    35 * scale,
                  ),
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
                    child: Column(
                      children: [
                        Row(
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
                                  "Tugas Saya",
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
                        SizedBox(height: 20 * scale),
                        _buildFilterTabs(scale),
                      ],
                    ),
                  ),
                ),
              ),

              // ---- KONTEN UTAMA ----
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    20 * scale,
                    10 * scale,
                    20 * scale,
                    12 * scale,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Daftar Tugas",
                        style: TextStyle(
                          fontSize: 17 * scale,
                          fontWeight: FontWeight.bold,
                          color: kBiruTua,
                        ),
                      ),
                      SizedBox(height: 14 * scale),
                      Expanded(
                        child: _tugasTerfilter.isEmpty
                            ? Center(
                                child: Text(
                                  "Belum ada tugas pada kategori ini",
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 13 * scale,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                padding: EdgeInsets.zero,
                                itemCount: _tugasTerfilter.length,
                                itemBuilder: (context, index) {
                                  final tugas = _tugasTerfilter[index];
                                  return _buildTaskCard(context, tugas, scale);
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---- TABS FILTER SESUAI PERMINTAAN ----
  Widget _buildFilterTabs(double scale) {
    final tabs = ["Semua", "Pending", "Berlangsung", "Dikumpulkan"];
    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: tabs.map((tab) {
            final bool aktif = tab == _filterAktif;
            return Padding(
              padding: EdgeInsets.only(right: 12 * scale),
              child: InkWell(
                borderRadius: BorderRadius.circular(15 * scale),
                onTap: () => setState(() => _filterAktif = tab),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16 * scale,
                    vertical: 9 * scale,
                  ),
                  decoration: BoxDecoration(
                    color: aktif
                        ? Colors.white
                        : Colors.white.withOpacity(0.15),
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
          }).toList(),
        ),
      ),
    );
  }

  // ---- CARD TUGAS DENGAN INFORMASI LENGKAP ----
  Widget _buildTaskCard(BuildContext context, TugasModel tugas, double scale) {
    final statusColor = _warnaStatus(tugas.statusTugas);
    final prioritasColor = _warnaPrioritas(tugas.prioritasTugas);

    return InkWell(
      borderRadius: BorderRadius.circular(20 * scale),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TugasDetailPage(tugas: tugas),
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
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Prioritas & Status Aktivitas
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Badge Prioritas
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10 * scale,
                    vertical: 4 * scale,
                  ),
                  decoration: BoxDecoration(
                    color: prioritasColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8 * scale),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.flag, size: 12 * scale, color: prioritasColor),
                      SizedBox(width: 4 * scale),
                      Text(
                        "Prioritas ${tugas.prioritasTugas}",
                        style: TextStyle(
                          color: prioritasColor,
                          fontSize: 10.5 * scale,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                // Badge Status Aktivitas
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10 * scale,
                    vertical: 4 * scale,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8 * scale),
                  ),
                  child: Text(
                    tugas.statusTugas.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10 * scale,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10 * scale),

            // Judul Tugas
            Text(
              tugas.judulTugas,
              style: TextStyle(
                fontSize: 16 * scale,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 8 * scale),

            // Info Lokasi
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 14 * scale,
                  color: Colors.grey[600],
                ),
                SizedBox(width: 4 * scale),
                Expanded(
                  child: Text(
                    tugas.lokasi,
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 11.5 * scale,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: 10 * scale),
            const Divider(height: 1, thickness: 0.5),
            SizedBox(height: 10 * scale),

            // Info Tanggal & Atasan
            Column(
              children: [
                _buildInfoRow(
                  Icons.event_available,
                  "Diberikan",
                  _formatTanggal(tugas.tanggalDiberikan),
                  scale,
                ),
                SizedBox(height: 4 * scale),
                _buildInfoRow(
                  Icons.play_circle_outline,
                  "Mulai Dikerjakan",
                  _formatTanggal(tugas.tanggalMulai),
                  scale,
                ),
                SizedBox(height: 4 * scale),
                _buildInfoRow(
                  Icons.timer_outlined,
                  "Deadline",
                  _formatTanggalJam(tugas.batasWaktu),
                  scale,
                  isHighlight: true,
                ),
                SizedBox(height: 6 * scale),
                _buildInfoRow(
                  Icons.person_outline,
                  "Diberikan Oleh",
                  tugas.namaAtasan,
                  scale,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value,
    double scale, {
    bool isHighlight = false,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 13 * scale,
          color: isHighlight ? Colors.redAccent : Colors.grey[500],
        ),
        SizedBox(width: 6 * scale),
        Text(
          "$label: ",
          style: TextStyle(color: Colors.grey[600], fontSize: 11 * scale),
        ),
        Text(
          value,
          style: TextStyle(
            color: isHighlight ? Colors.redAccent : Colors.black87,
            fontSize: 11 * scale,
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Color _warnaStatus(String status) {
    switch (status) {
      case "Berlangsung":
        return Colors.orange.shade800;
      case "Menunggu Disetujui":
        return Colors.blue.shade700;
      case "Revisi":
        return Colors.purple.shade700;
      case "Pending":
      default:
        return Colors.blueGrey;
    }
  }

  Color _warnaPrioritas(String prioritas) {
    switch (prioritas) {
      case "Tinggi":
        return Colors.red;
      case "Sedang":
        return Colors.orange;
      case "Rendah":
      default:
        return Colors.green;
    }
  }

  String _formatTanggal(DateTime dt) {
    const bulan = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "Mei",
      "Jun",
      "Jul",
      "Agt",
      "Sep",
      "Okt",
      "Nov",
      "Des",
    ];
    return "${dt.day} ${bulan[dt.month - 1]} ${dt.year}";
  }

  String _formatTanggalJam(DateTime dt) {
    final jam = dt.hour.toString().padLeft(2, '0');
    final menit = dt.minute.toString().padLeft(2, '0');
    return "${_formatTanggal(dt)} - $jam:$menit";
  }
}

class HeaderCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 20);
    final controlPoint = Offset(size.width / 2, size.height + 15);
    final endPoint = Offset(size.width, size.height - 20);

    path.quadraticBezierTo(
      controlPoint.dx,
      controlPoint.dy,
      endPoint.dx,
      endPoint.dy,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
