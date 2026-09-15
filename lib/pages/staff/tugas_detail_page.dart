import 'package:flutter/material.dart';
import 'tugas_staff_page.dart'
    show TugasModel, kBiruTua, kBiruSedang, kBiruMuda, kBgLight;

class TugasDetailPage extends StatefulWidget {
  final TugasModel tugas;
  const TugasDetailPage({super.key, required this.tugas});

  @override
  State<TugasDetailPage> createState() => _TugasDetailPageState();
}

class _TugasDetailPageState extends State<TugasDetailPage> {
  late String _statusTerpilih;
  late TextEditingController _keteranganController;
  String? _namaFileDipilih;

  @override
  void initState() {
    super.initState();
    _statusTerpilih = widget.tugas.statusTugas;
    _keteranganController = TextEditingController(
      text: widget.tugas.keteranganHasil ?? "",
    );
    _namaFileDipilih = widget.tugas.fileHasil;
  }

  @override
  void dispose() {
    _keteranganController.dispose();
    super.dispose();
  }

  void _simpanUpdate() {
    setState(() {
      widget.tugas.statusTugas = _statusTerpilih;
      widget.tugas.keteranganHasil = _keteranganController.text;
      widget.tugas.fileHasil = _namaFileDipilih;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Riwayat pengerjaan berhasil disimpan")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tugas = widget.tugas;

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
                              "Detail Tugas",
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

              // ---- KONTEN UTAMA ----
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    20 * scale,
                    15 * scale,
                    20 * scale,
                    30 * scale,
                  ),
                  children: [
                    // ==== BAGIAN 1: INFORMASI DARI ATASAN ====
                    _sectionLabel("Informasi Tugas (dari atasan)", scale),
                    SizedBox(height: 10 * scale),
                    _infoCard(
                      scale,
                      children: [
                        Row(
                          children: [
                            _badgePrioritas(tugas.prioritasTugas, scale),
                            SizedBox(width: 8 * scale),
                            _badgeStatusTugas(tugas.statusTugas, scale),
                          ],
                        ),
                        SizedBox(height: 14 * scale),
                        Text(
                          tugas.judulTugas,
                          style: TextStyle(
                            fontSize: 17 * scale,
                            fontWeight: FontWeight.bold,
                            color: kBiruTua,
                          ),
                        ),
                        SizedBox(height: 8 * scale),
                        Text(
                          tugas.deskripsiTugas,
                          style: TextStyle(
                            fontSize: 13 * scale,
                            color: Colors.grey[700],
                            height: 1.4,
                          ),
                        ),
                        SizedBox(height: 16 * scale),
                        _baris(
                          Icons.location_on_outlined,
                          "Lokasi: ${tugas.lokasi}",
                          scale,
                        ),
                        SizedBox(height: 8 * scale),
                        _baris(
                          Icons.person_outline,
                          "Diberikan oleh: ${tugas.namaAtasan}",
                          scale,
                        ),
                        SizedBox(height: 8 * scale),
                        _baris(
                          Icons.event_available,
                          "Diberikan: ${_formatTanggal(tugas.tanggalDiberikan)}",
                          scale,
                        ),
                        SizedBox(height: 8 * scale),
                        _baris(
                          Icons.play_circle_outline,
                          "Mulai: ${_formatTanggal(tugas.tanggalMulai)}",
                          scale,
                        ),
                        SizedBox(height: 8 * scale),
                        _baris(
                          Icons.timer_outlined,
                          "Deadline: ${_formatTanggal(tugas.batasWaktu, jam: true)}",
                          scale,
                          isHighlight: true,
                        ),
                      ],
                    ),

                    SizedBox(height: 22 * scale),

                    // ==== BAGIAN 2: UPDATE RIWAYAT PENGERJAAN ====
                    _sectionLabel("Update Riwayat Pengerjaan (Anda)", scale),
                    SizedBox(height: 10 * scale),
                    _infoCard(
                      scale,
                      children: [
                        Text(
                          "Status Pengerjaan",
                          style: TextStyle(
                            fontSize: 12.5 * scale,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                        SizedBox(height: 8 * scale),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 14 * scale),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(14 * scale),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _statusTerpilih,
                              isExpanded: true,
                              items:
                                  const [
                                        "Pending",
                                        "Berlangsung",
                                        "Menunggu Disetujui",
                                        "Revisi",
                                      ]
                                      .map(
                                        (s) => DropdownMenuItem(
                                          value: s,
                                          child: Text(s),
                                        ),
                                      )
                                      .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _statusTerpilih = val);
                                }
                              },
                            ),
                          ),
                        ),
                        SizedBox(height: 16 * scale),
                        Text(
                          "Keterangan Hasil",
                          style: TextStyle(
                            fontSize: 12.5 * scale,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                        SizedBox(height: 8 * scale),
                        TextField(
                          controller: _keteranganController,
                          maxLines: 4,
                          style: TextStyle(fontSize: 13 * scale),
                          decoration: InputDecoration(
                            hintText:
                                "Tulis catatan hasil pengerjaan tugas ini...",
                            hintStyle: TextStyle(fontSize: 12.5 * scale),
                            contentPadding: EdgeInsets.all(12 * scale),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14 * scale),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 16 * scale),
                        Text(
                          "File Hasil",
                          style: TextStyle(
                            fontSize: 12.5 * scale,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                        SizedBox(height: 8 * scale),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _namaFileDipilih = "dokumen_hasil_kerja.pdf";
                            });
                          },
                          borderRadius: BorderRadius.circular(14 * scale),
                          child: Container(
                            padding: EdgeInsets.all(14 * scale),
                            decoration: BoxDecoration(
                              color: kBiruMuda.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(14 * scale),
                              border: Border.all(
                                color: kBiruMuda.withOpacity(0.4),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.upload_file,
                                  color: kBiruSedang,
                                  size: 18 * scale,
                                ),
                                SizedBox(width: 10 * scale),
                                Expanded(
                                  child: Text(
                                    _namaFileDipilih ??
                                        "Pilih file untuk diunggah",
                                    style: TextStyle(
                                      fontSize: 12.5 * scale,
                                      color: kBiruTua,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 20 * scale),
                        SizedBox(
                          width: double.infinity,
                          height: 50 * scale,
                          child: ElevatedButton(
                            onPressed: _simpanUpdate,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14 * scale),
                              ),
                            ),
                            child: Ink(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [kBiruMuda, kBiruSedang],
                                ),
                                borderRadius: BorderRadius.circular(14 * scale),
                              ),
                              child: Container(
                                alignment: Alignment.center,
                                child: Text(
                                  "SIMPAN UPDATE",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5 * scale,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 8 * scale),
                        Text(
                          "Status ACC/Selesai resmi hanya dapat diberikan oleh atasan.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10.5 * scale,
                            color: Colors.grey[500],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionLabel(String text, double scale) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13.5 * scale,
        fontWeight: FontWeight.bold,
        color: kBiruTua,
      ),
    );
  }

  Widget _infoCard(double scale, {required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22 * scale),
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
        children: children,
      ),
    );
  }

  Widget _baris(
    IconData icon,
    String text,
    double scale, {
    bool isHighlight = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 15 * scale,
          color: isHighlight ? Colors.redAccent : Colors.grey[500],
        ),
        SizedBox(width: 8 * scale),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12.5 * scale,
              color: isHighlight ? Colors.redAccent : Colors.grey[700],
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  Widget _badgePrioritas(String prioritas, double scale) {
    Color warna;
    switch (prioritas) {
      case "Tinggi":
        warna = Colors.red;
        break;
      case "Sedang":
        warna = Colors.orange;
        break;
      default:
        warna = Colors.green;
    }
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 10 * scale,
        vertical: 5 * scale,
      ),
      decoration: BoxDecoration(
        color: warna.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10 * scale),
      ),
      child: Text(
        "Prioritas $prioritas",
        style: TextStyle(
          color: warna,
          fontSize: 10 * scale,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _badgeStatusTugas(String status, double scale) {
    Color warna;
    switch (status) {
      case "Berlangsung":
        warna = Colors.orange.shade800;
        break;
      case "Menunggu Disetujui":
        warna = Colors.blue.shade700;
        break;
      case "Revisi":
        warna = Colors.purple.shade700;
        break;
      case "Pending":
      default:
        warna = Colors.blueGrey;
    }
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 10 * scale,
        vertical: 5 * scale,
      ),
      decoration: BoxDecoration(
        color: warna.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10 * scale),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: warna,
          fontSize: 10 * scale,
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
    final j = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return "$tgl - $j:$m";
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
