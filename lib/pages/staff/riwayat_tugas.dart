import 'package:flutter/material.dart';

// Definisi warna sesuai tema aplikasi kamu
const Color kBiruTua = Color(0xFF0D47A1);
const Color kBiruSedang = Color(0xFF1976D2);
const Color kBiruMuda = Color(0xFF42A5F5);
const Color kBgLight = Color(0xFFF4F6F9);

// Model Data Tugas
class TugasModel {
  String id;
  String judulTugas;
  String deskripsiTugas;
  String namaAtasan;
  String statusTugas; // "Pending", "Berlangsung", "Selesai"
  String statusValidasi; // "Belum Diverifikasi", "Diterima", "Ditolak"
  String prioritasTugas; // "Rendah", "Sedang", "Tinggi"
  DateTime tanggalMulai;
  DateTime batasWaktu;
  String? keteranganHasil;
  String? fileHasil;

  TugasModel({
    required this.id,
    required this.judulTugas,
    required this.deskripsiTugas,
    required this.namaAtasan,
    required this.statusTugas,
    required this.statusValidasi,
    required this.prioritasTugas,
    required this.tanggalMulai,
    required this.batasWaktu,
    this.keteranganHasil,
    this.fileHasil,
  });
}

class RiwayatTugasPage extends StatefulWidget {
  const RiwayatTugasPage({super.key});

  @override
  State<RiwayatTugasPage> createState() => _RiwayatTugasPageState();
}

class _RiwayatTugasPageState extends State<RiwayatTugasPage> {
  // Dummy Data Riwayat
  final List<TugasModel> _daftarRiwayat = [
    TugasModel(
      id: "1",
      judulTugas: "Laporan Keuangan Bulanan",
      deskripsiTugas:
          "Menyusun dan menyajikan laporan rekonsiliasi kas bulan ini.",
      namaAtasan: "Budi Santoso",
      statusTugas: "Selesai",
      statusValidasi: "Diterima",
      prioritasTugas: "Tinggi",
      tanggalMulai: DateTime.now().subtract(const Duration(days: 5)),
      batasWaktu: DateTime.now().subtract(const Duration(days: 1)),
      keteranganHasil:
          "Laporan sudah selesai dikerjakan dan diverifikasi tim audit.",
      fileHasil: "laporan_keuangan_final.pdf",
    ),
    TugasModel(
      id: "2",
      judulTugas: "Update Design Banner Website",
      deskripsiTugas: "Membuat banner promo utama untuk halaman beranda.",
      namaAtasan: "Siti Rahma",
      statusTugas: "Selesai",
      statusValidasi: "Belum Diverifikasi",
      prioritasTugas: "Sedang",
      tanggalMulai: DateTime.now().subtract(const Duration(days: 3)),
      batasWaktu: DateTime.now().add(const Duration(days: 1)),
      keteranganHasil: "Desain versi 1 sudah diunggah.",
      fileHasil: "banner_v1.png",
    ),
  ];

  // ==== POP-UP DETAIL RIWAYAT ====
  void _tampilkanPopUpDetail(BuildContext context, TugasModel tugas) {
    showDialog(
      context: context,
      barrierDismissible: true, // Bisa ditutup saat klik luar area pop-up
      barrierColor: Colors.black.withOpacity(0.6), // Layar luar redup
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.80,
            ),
            decoration: BoxDecoration(
              color: kBgLight,
              borderRadius: BorderRadius.circular(24),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header Pop-up
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [kBiruMuda, kBiruSedang, kBiruTua],
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        tooltip: "Kembali",
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        "Detail Riwayat Tugas",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),

                // Content Pop-up
                Flexible(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    shrinkWrap: true,
                    children: [
                      Row(
                        children: [
                          _badgePrioritas(tugas.prioritasTugas),
                          const SizedBox(width: 8),
                          _badgeStatusValidasi(tugas.statusValidasi),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        tugas.judulTugas,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: kBiruTua,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        tugas.deskripsiTugas,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.grey[700],
                          height: 1.35,
                        ),
                      ),
                      const Divider(height: 24),
                      _barisInfo(
                        Icons.person_outline,
                        "Atasan: ${tugas.namaAtasan}",
                      ),
                      const SizedBox(height: 6),
                      _barisInfo(
                        Icons.play_circle_outline,
                        "Mulai: ${_formatTanggal(tugas.tanggalMulai)}",
                      ),
                      const SizedBox(height: 6),
                      _barisInfo(
                        Icons.flag_outlined,
                        "Batas Waktu: ${_formatTanggal(tugas.batasWaktu, jam: true)}",
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Catatan Hasil Pengerjaan",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: kBiruTua,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          (tugas.keteranganHasil != null &&
                                  tugas.keteranganHasil!.isNotEmpty)
                              ? tugas.keteranganHasil!
                              : "Tidak ada catatan.",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[800],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (tugas.fileHasil != null) ...[
                        const Text(
                          "Lampiran File Hasil",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: kBiruTua,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: kBiruMuda.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.insert_drive_file,
                                color: kBiruSedang,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  tugas.fileHasil!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: kBiruTua,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
              // HEADER DI-SAMAKAN DENGAN HEADER CURVE DARI STAFF TUGAS
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
                              "Riwayat Tugas",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18 * scale,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 24 * scale), // Penyeimbang posisi title
                      ],
                    ),
                  ),
                ),
              ),

              // DAFTAR CARD RIWAYAT TUGAS
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    16 * scale,
                    10 * scale,
                    16 * scale,
                    20 * scale,
                  ),
                  itemCount: _daftarRiwayat.length,
                  itemBuilder: (context, index) {
                    final tugas = _daftarRiwayat[index];
                    return Card(
                      margin: EdgeInsets.only(bottom: 12 * scale),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16 * scale),
                      ),
                      elevation: 2,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16 * scale),
                        onTap: () {
                          _tampilkanPopUpDetail(context, tugas);
                        },
                        child: Padding(
                          padding: EdgeInsets.all(14 * scale),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  _badgePrioritas(tugas.prioritasTugas),
                                  _badgeStatusValidasi(tugas.statusValidasi),
                                ],
                              ),
                              SizedBox(height: 10 * scale),
                              Text(
                                tugas.judulTugas,
                                style: TextStyle(
                                  fontSize: 15 * scale,
                                  fontWeight: FontWeight.bold,
                                  color: kBiruTua,
                                ),
                              ),
                              SizedBox(height: 4 * scale),
                              Text(
                                tugas.deskripsiTugas,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12 * scale,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Divider(height: 20 * scale),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Batas: ${_formatTanggal(tugas.batasWaktu)}",
                                    style: TextStyle(
                                      fontSize: 11 * scale,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        "Lihat Detail",
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
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // WIDGET HELPER
  Widget _barisInfo(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 15, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, color: Colors.grey[800]),
          ),
        ),
      ],
    );
  }

  Widget _badgePrioritas(String prioritas) {
    Color warna = prioritas == "Tinggi"
        ? Colors.red
        : (prioritas == "Sedang" ? Colors.orange : Colors.blueGrey);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: warna.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        "Prioritas $prioritas",
        style: TextStyle(
          color: warna,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _badgeStatusValidasi(String status) {
    Color warna = status == "Diterima"
        ? Colors.green
        : (status == "Ditolak" ? Colors.red : kBiruSedang);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: warna.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        "Validasi: $status",
        style: TextStyle(
          color: warna,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _formatTanggal(DateTime dt, {bool jam = false}) {
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
    final tgl = "${dt.day} ${bulan[dt.month - 1]} ${dt.year}";
    if (!jam) return tgl;
    return "$tgl, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }
}

// CLIPPER UNTUK HEADER CURVE GRADIENT
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
