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
  final DateTime tanggalMulai;
  final DateTime batasWaktu;
  final String prioritasTugas;
  String statusTugas; // "Pending" | "Berlangsung" | "Selesai"
  String? fileHasil;
  String? keteranganHasil;
  final String statusValidasi;
  final String namaAtasan;

  TugasModel({
    required this.idTugas,
    required this.idAtasan,
    required this.idStaff,
    required this.judulTugas,
    required this.deskripsiTugas,
    required this.tanggalMulai,
    required this.batasWaktu,
    required this.prioritasTugas,
    required this.statusTugas,
    this.fileHasil,
    this.keteranganHasil,
    required this.statusValidasi,
    required this.namaAtasan,
  });

  double get progress {
    switch (statusTugas) {
      case "Selesai":
        return 100;
      case "Berlangsung":
        return 50;
      case "Pending":
      default:
        return 0;
    }
  }
}

List<TugasModel> dummyTugasStaff() {
  return [
    TugasModel(
      idTugas: 1,
      idAtasan: 101,
      idStaff: 55,
      judulTugas: "Penyusunan Laporan TIK",
      deskripsiTugas:
          "Susun laporan bulanan penggunaan infrastruktur TIK untuk diserahkan ke bagian evaluasi.",
      tanggalMulai: DateTime(2026, 8, 28),
      batasWaktu: DateTime(2026, 9, 3, 12, 45),
      prioritasTugas: "Tinggi",
      statusTugas: "Berlangsung",
      fileHasil: null,
      keteranganHasil: null,
      statusValidasi: "Menunggu",
      namaAtasan: "Saad Ibn Sayeed",
    ),
    TugasModel(
      idTugas: 2,
      idAtasan: 102,
      idStaff: 55,
      judulTugas: "Maintenance Server",
      deskripsiTugas:
          "Lakukan pemeliharaan rutin server utama dan backup data mingguan.",
      tanggalMulai: DateTime(2026, 8, 30),
      batasWaktu: DateTime(2026, 9, 2, 15, 0),
      prioritasTugas: "Sedang",
      statusTugas: "Selesai",
      fileHasil: "laporan_maintenance.pdf",
      keteranganHasil: "Semua server sudah dicek, backup berhasil.",
      statusValidasi: "Diterima",
      namaAtasan: "Jonathan Eve",
    ),
    TugasModel(
      idTugas: 3,
      idAtasan: 103,
      idStaff: 55,
      judulTugas: "Desain Banner Kominfo",
      deskripsiTugas:
          "Buat desain banner sosialisasi untuk kegiatan Kominfo bulan depan.",
      tanggalMulai: DateTime(2026, 9, 1),
      batasWaktu: DateTime(2026, 9, 22, 9, 0),
      prioritasTugas: "Rendah",
      statusTugas: "Pending",
      fileHasil: null,
      keteranganHasil: null,
      statusValidasi: "Menunggu",
      namaAtasan: "Marques Browney",
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

  List<TugasModel> get _tugasTerfilter {
    if (_filterAktif == "Semua") return _semuaTugas;
    return _semuaTugas.where((t) => t.statusTugas == _filterAktif).toList();
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
              // ---- HEADER GRADASI DENGAN LENGKUNGAN KE BAWAH (TIPIS) ----
              ClipPath(
                clipper: HeaderCurveClipper(),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(
                    20 * scale,
                    16 * scale,
                    20 * scale,
                    35 * scale, // Extra padding bawah untuk area lengkungan
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
                            // ---- TOMBOL BACK POLOS (TANPA CIRCLE BACKGROUND) ----
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
                            SizedBox(
                              width: 24 * scale,
                            ), // Penyeimbang tombol back
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
                        "Semua Tugas",
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

  Widget _buildFilterTabs(double scale) {
    final tabs = ["Semua", "Pending", "Berlangsung", "Selesai"];
    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: tabs.map((tab) {
            final bool aktif = tab == _filterAktif;
            return Padding(
              padding: EdgeInsets.only(right: 22 * scale),
              child: InkWell(
                borderRadius: BorderRadius.circular(15 * scale),
                onTap: () => setState(() => _filterAktif = tab),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: aktif ? 18 * scale : 4 * scale,
                    vertical: 9 * scale,
                  ),
                  decoration: BoxDecoration(
                    color: aktif ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(15 * scale),
                  ),
                  child: Text(
                    tab,
                    style: TextStyle(
                      color: aktif ? kBiruTua : Colors.white.withOpacity(0.75),
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

  Widget _buildTaskCard(BuildContext context, TugasModel tugas, double scale) {
    final statusColor = _warnaStatus(tugas.statusTugas);

    return InkWell(
      borderRadius: BorderRadius.circular(24 * scale),
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
        padding: EdgeInsets.all(18 * scale),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24 * scale),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tag, size: 13 * scale, color: Colors.grey[400]),
                Text(
                  "TGS-${tugas.idTugas.toString().padLeft(4, '0')}",
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 11.5 * scale,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.access_time,
                  size: 13 * scale,
                  color: Colors.grey[400],
                ),
                SizedBox(width: 4 * scale),
                Text(
                  _formatBatasWaktu(tugas.batasWaktu),
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 11 * scale,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8 * scale),
            Text(
              tugas.judulTugas,
              style: TextStyle(
                fontSize: 15.5 * scale,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10 * scale),
            Row(
              children: [
                CircleAvatar(
                  radius: 12 * scale,
                  backgroundColor: kBiruMuda.withOpacity(0.15),
                  child: Text(
                    tugas.namaAtasan.isNotEmpty
                        ? tugas.namaAtasan[0].toUpperCase()
                        : "?",
                    style: TextStyle(
                      color: kBiruTua,
                      fontWeight: FontWeight.bold,
                      fontSize: 11 * scale,
                    ),
                  ),
                ),
                SizedBox(width: 8 * scale),
                Expanded(
                  child: Text(
                    "Dari: ${tugas.namaAtasan}",
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 11.5 * scale,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12 * scale,
                    vertical: 6 * scale,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12 * scale),
                  ),
                  child: Text(
                    tugas.statusTugas.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 9.5 * scale,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _warnaStatus(String status) {
    switch (status) {
      case "Selesai":
        return Colors.green;
      case "Berlangsung":
        return Colors.orange;
      case "Pending":
      default:
        return Colors.blueGrey;
    }
  }

  String _formatBatasWaktu(DateTime dt) {
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
    final jam = dt.hour.toString().padLeft(2, '0');
    final menit = dt.minute.toString().padLeft(2, '0');
    return "${dt.day} ${bulan[dt.month - 1]} - $jam:$menit";
  }
}

/// Custom Clipper untuk membuat kurva lengkungan tipis mengarah ke bawah
class HeaderCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 20); // Titik awal lengkungan di kiri

    // Membuat lengkungan halus menunjul ke bawah di tengah
    final controlPoint = Offset(size.width / 2, size.height + 15);
    final endPoint = Offset(size.width, size.height - 20);

    path.quadraticBezierTo(
      controlPoint.dx,
      controlPoint.dy,
      endPoint.dx,
      endPoint.dy,
    );

    path.lineTo(size.width, 0); // Naik ke pojok kanan atas
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
