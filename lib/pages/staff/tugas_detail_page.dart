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

  void _mulaiKerjakan() {
    setState(() {
      _statusTerpilih = "Berlangsung";
      widget.tugas.statusTugas = "Berlangsung";
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Tugas dimulai! Status diubah menjadi Berlangsung."),
      ),
    );
  }

  void _kirimHasilPekerjaan() {
    if (_namaFileDipilih == null && _keteranganController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Harap isi keterangan atau unggah file bukti hasil!"),
        ),
      );
      return;
    }

    setState(() {
      _statusTerpilih = "Menunggu Disetujui";
      widget.tugas.statusTugas = "Menunggu Disetujui";
      widget.tugas.keteranganHasil = _keteranganController.text;
      widget.tugas.fileHasil = _namaFileDipilih;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.tugas.statusTugas == "Revisi"
              ? "Hasil revisi berhasil dikirim ke atasan!"
              : "Hasil pekerjaan berhasil dikirim ke atasan!",
        ),
      ),
    );
  }

  void _lanjutkanPekerjaan() {
    setState(() {
      _statusTerpilih = "Berlangsung";
      widget.tugas.statusTugas = "Berlangsung";
      widget.tugas.statusKendala = "Selesai/Dibatalkan";
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Kendala diselesaikan, tugas kembali Berlangsung."),
      ),
    );
  }

  void _bukaFormKendala() {
    final deskripsi = TextEditingController(
      text: widget.tugas.deskripsiKendala ?? "",
    );
    final dampak = TextEditingController(
      text: widget.tugas.dampakKendala ?? "",
    );
    String jenis = widget.tugas.jenisKendala ?? "Internal";
    String? lampiranKendala = widget.tugas.fileKendala;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final scale = (MediaQuery.of(sheetContext).size.width / 375).clamp(
          0.85,
          1.25,
        );
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Container(
              height: MediaQuery.of(modalContext).size.height * .86,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(20 * scale),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.red.shade700,
                            size: 28 * scale,
                          ),
                          SizedBox(width: 10 * scale),
                          Expanded(
                            child: Text(
                              "Laporkan Kendala",
                              style: TextStyle(
                                fontSize: 18 * scale,
                                fontWeight: FontWeight.bold,
                                color: kBiruTua,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(modalContext),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.all(20 * scale),
                        children: [
                          Text(
                            "Tugas",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          SizedBox(height: 7 * scale),
                          Container(
                            padding: EdgeInsets.all(13 * scale),
                            decoration: BoxDecoration(
                              color: kBgLight,
                              borderRadius: BorderRadius.circular(12 * scale),
                            ),
                            child: Text(
                              widget.tugas.judulTugas,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: kBiruTua,
                              ),
                            ),
                          ),
                          SizedBox(height: 18 * scale),
                          Text(
                            "Jenis Kendala",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          SizedBox(height: 8 * scale),
                          Row(
                            children: [
                              Expanded(
                                child: _pilihanKendala(
                                  "Internal",
                                  Icons.person_outline,
                                  jenis == "Internal",
                                  scale,
                                  () => setModalState(() => jenis = "Internal"),
                                ),
                              ),
                              SizedBox(width: 10 * scale),
                              Expanded(
                                child: _pilihanKendala(
                                  "Eksternal",
                                  Icons.public,
                                  jenis == "Eksternal",
                                  scale,
                                  () =>
                                      setModalState(() => jenis = "Eksternal"),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 18 * scale),
                          Text(
                            "Deskripsi Kendala",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          SizedBox(height: 8 * scale),
                          TextField(
                            controller: deskripsi,
                            maxLines: 4,
                            decoration: _inputKendala(
                              "Jelaskan kendala yang dialami...",
                              scale,
                            ),
                          ),
                          SizedBox(height: 16 * scale),
                          Text(
                            "Dampak terhadap Tugas",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          SizedBox(height: 8 * scale),
                          TextField(
                            controller: dampak,
                            maxLines: 3,
                            decoration: _inputKendala(
                              "Jelaskan dampaknya terhadap tugas...",
                              scale,
                            ),
                          ),
                          SizedBox(height: 16 * scale),
                          Text(
                            "Lampiran Bukti (Opsional)",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          SizedBox(height: 8 * scale),
                          InkWell(
                            onTap: () {
                              setModalState(() {
                                lampiranKendala = "bukti_kendala_lapangan.pdf";
                              });
                            },
                            borderRadius: BorderRadius.circular(14 * scale),
                            child: Container(
                              padding: EdgeInsets.all(14 * scale),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(14 * scale),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.attach_file,
                                    color: Colors.red.shade700,
                                    size: 20 * scale,
                                  ),
                                  SizedBox(width: 8 * scale),
                                  Expanded(
                                    child: Text(
                                      lampiranKendala ??
                                          "Upload foto / dokumen pendukung kendala",
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12.5 * scale,
                                        color: lampiranKendala != null
                                            ? kBiruTua
                                            : Colors.grey.shade600,
                                        fontWeight: lampiranKendala != null
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                  if (lampiranKendala != null)
                                    GestureDetector(
                                      onTap: () {
                                        setModalState(() {
                                          lampiranKendala = null;
                                        });
                                      },
                                      child: const Icon(
                                        Icons.cancel,
                                        color: Colors.grey,
                                        size: 18,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: 22 * scale),
                          SizedBox(
                            width: double.infinity,
                            height: 50 * scale,
                            child: ElevatedButton(
                              onPressed: () {
                                if (deskripsi.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(
                                    modalContext,
                                  ).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "Deskripsi kendala wajib diisi",
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                Navigator.pop(modalContext);

                                if (mounted) {
                                  setState(() {
                                    widget.tugas.statusTugas = "Terkendala";
                                    _statusTerpilih = "Terkendala";
                                    widget.tugas.jenisKendala = jenis;
                                    widget.tugas.deskripsiKendala = deskripsi
                                        .text
                                        .trim();
                                    widget.tugas.dampakKendala = dampak.text
                                        .trim();
                                    widget.tugas.fileKendala = lampiranKendala;
                                    widget.tugas.statusKendala =
                                        "Menunggu Atasan";
                                  });

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "Kendala berhasil dilaporkan kepada atasan",
                                      ),
                                    ),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade700,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    14 * scale,
                                  ),
                                ),
                              ),
                              child: const Text(
                                "KIRIM LAPORAN KENDALA",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _pilihanKendala(
    String text,
    IconData icon,
    bool aktif,
    double scale,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13 * scale),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 10 * scale,
          vertical: 12 * scale,
        ),
        decoration: BoxDecoration(
          color: aktif ? Colors.red.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(13 * scale),
          border: Border.all(
            color: aktif ? Colors.red.shade700 : Colors.grey.shade300,
            width: aktif ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              aktif ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 18 * scale,
              color: aktif ? Colors.red.shade700 : Colors.grey.shade500,
            ),
            SizedBox(width: 6 * scale),
            Icon(
              icon,
              size: 17 * scale,
              color: aktif ? Colors.red.shade700 : Colors.grey.shade600,
            ),
            SizedBox(width: 5 * scale),
            Text(
              text,
              style: TextStyle(
                fontSize: 12 * scale,
                fontWeight: aktif ? FontWeight.bold : FontWeight.normal,
                color: aktif ? Colors.red.shade900 : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputKendala(String hint, double scale) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 12.5 * scale, color: Colors.grey.shade500),
      contentPadding: EdgeInsets.all(12 * scale),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14 * scale),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14 * scale),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14 * scale),
        borderSide: BorderSide(color: Colors.red.shade700),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tugas = widget.tugas;
    final bool isRevisi = _statusTerpilih == "Revisi";

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
                    // ==== BANNER KENDALA ====
                    if (tugas.statusTugas == "Terkendala" ||
                        tugas.deskripsiKendala != null) ...[
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(14 * scale),
                        margin: EdgeInsets.only(bottom: 16 * scale),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(16 * scale),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.red.shade700,
                              size: 22 * scale,
                            ),
                            SizedBox(width: 10 * scale),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Laporan Kendala (${tugas.statusKendala ?? 'Menunggu Atasan'})",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red.shade900,
                                      fontSize: 12.5 * scale,
                                    ),
                                  ),
                                  SizedBox(height: 4 * scale),
                                  Text(
                                    tugas.deskripsiKendala ?? "-",
                                    style: TextStyle(
                                      fontSize: 12 * scale,
                                      color: Colors.red.shade800,
                                      height: 1.3,
                                    ),
                                  ),
                                  if (tugas.fileKendala != null) ...[
                                    SizedBox(height: 6 * scale),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.attach_file,
                                          size: 14 * scale,
                                          color: Colors.red.shade700,
                                        ),
                                        SizedBox(width: 4 * scale),
                                        Text(
                                          tugas.fileKendala!,
                                          style: TextStyle(
                                            fontSize: 11 * scale,
                                            color: Colors.red.shade900,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // ==== INFORMASI DARI ATASAN ====
                    _sectionLabel("Informasi Tugas", scale),
                    SizedBox(height: 10 * scale),
                    _infoCard(
                      scale,
                      children: [
                        Row(
                          children: [
                            _badgePrioritas(tugas.prioritasTugas, scale),
                            SizedBox(width: 8 * scale),
                            _badgeStatusTugas(_statusTerpilih, scale),
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

                    // ==== HIGHLIGHT CATATAN REVISI DARI ATASAN ====
                    if (isRevisi) ...[
                      SizedBox(height: 16 * scale),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(16 * scale),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E1),
                          borderRadius: BorderRadius.circular(16 * scale),
                          border: Border.all(
                            color: Colors.amber.shade400,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.rate_review_outlined,
                                  color: Colors.amber.shade900,
                                  size: 20 * scale,
                                ),
                                SizedBox(width: 8 * scale),
                                Text(
                                  "Catatan Revisi dari ${tugas.namaAtasan}",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5 * scale,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8 * scale),
                            Divider(height: 1, color: Colors.amber.shade300),
                            SizedBox(height: 10 * scale),
                            Text(
                              '"Perbaiki format tabel pada lampiran 2 dan atur margin menjadi 2cm."',
                              style: TextStyle(
                                fontSize: 13 * scale,
                                color: Colors.black87,
                                fontStyle: FontStyle.italic,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    SizedBox(height: 22 * scale),

                    // ==== FORM PENGERJAAN & Aksi TERGANTUNG STATUS ====
                    _sectionLabel("Pengerjaan Tugas", scale),
                    SizedBox(height: 10 * scale),
                    _infoCard(
                      scale,
                      children: [
                        // --- KONDISI 1: PENDING ---
                        if (_statusTerpilih == "Pending") ...[
                          Text(
                            "Tugas belum dimulai. Klik tombol di bawah untuk mulai mengerjakannya.",
                            style: TextStyle(
                              fontSize: 13 * scale,
                              color: Colors.grey[600],
                            ),
                          ),
                          SizedBox(height: 16 * scale),
                          SizedBox(
                            width: double.infinity,
                            height: 48 * scale,
                            child: ElevatedButton.icon(
                              onPressed: _mulaiKerjakan,
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: const Text(
                                "MULAI KERJAKAN",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kBiruTua,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    14 * scale,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],

                        // --- KONDISI 2: BERLANGSUNG ATAU REVISI ---
                        if (_statusTerpilih == "Berlangsung" || isRevisi) ...[
                          Text(
                            isRevisi
                                ? "Keterangan Perbaikan"
                                : "Keterangan Hasil Pekerjaan",
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
                              hintText: isRevisi
                                  ? "Tuliskan catatan perbaikan yang telah dilakukan..."
                                  : "Tulis catatan hasil pengerjaan tugas ini...",
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
                            isRevisi
                                ? "File Hasil Perbaikan"
                                : "File Hasil Pekerjaan",
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
                                _namaFileDipilih =
                                    "dokumen_hasil_pekerjaan.pdf";
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
                                          (isRevisi
                                              ? "Pilih file perbaikan baru"
                                              : "Pilih file untuk diunggah"),
                                      style: const TextStyle(
                                        fontSize: 12.5,
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
                            child: ElevatedButton.icon(
                              onPressed: _kirimHasilPekerjaan,
                              icon: Icon(
                                isRevisi
                                    ? Icons.send_rounded
                                    : Icons.check_circle_outline,
                                color: Colors.white,
                              ),
                              label: Text(
                                isRevisi
                                    ? "KIRIM HASIL REVISI"
                                    : "KIRIM HASIL PEKERJAAN",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.5 * scale,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isRevisi
                                    ? Colors.amber.shade800
                                    : kBiruSedang,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    14 * scale,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (!isRevisi) ...[
                            SizedBox(height: 12 * scale),
                            OutlinedButton.icon(
                              onPressed: _bukaFormKendala,
                              icon: Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.red.shade700,
                                size: 18 * scale,
                              ),
                              label: Text(
                                "LAPORKAN KENDALA",
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5 * scale,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                minimumSize: Size(double.infinity, 48 * scale),
                                side: BorderSide(color: Colors.red.shade700),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    14 * scale,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],

                        // --- KONDISI 3: TERKENDALA ---
                        if (_statusTerpilih == "Terkendala") ...[
                          Text(
                            "Status tugas saat ini terkendala. Anda dapat mengedit laporan kendala atau menekan tombol di bawah jika masalah sudah selesai.",
                            style: TextStyle(
                              fontSize: 12.5 * scale,
                              color: Colors.grey[700],
                            ),
                          ),
                          SizedBox(height: 16 * scale),
                          SizedBox(
                            width: double.infinity,
                            height: 48 * scale,
                            child: ElevatedButton.icon(
                              onPressed: _lanjutkanPekerjaan,
                              icon: const Icon(Icons.play_circle_fill),
                              label: const Text(
                                "MASALAH SELESAI, LANJUTKAN",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade700,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    14 * scale,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 12 * scale),
                          OutlinedButton.icon(
                            onPressed: _bukaFormKendala,
                            icon: Icon(
                              Icons.edit,
                              color: Colors.red.shade700,
                              size: 18 * scale,
                            ),
                            label: Text(
                              "EDIT LAPORAN KENDALA",
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5 * scale,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: Size(double.infinity, 48 * scale),
                              side: BorderSide(color: Colors.red.shade700),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14 * scale),
                              ),
                            ),
                          ),
                        ],

                        // --- KONDISI 4: MENUNGGU DISETUJUI / SELESAI ---
                        if (_statusTerpilih == "Menunggu Disetujui" ||
                            _statusTerpilih == "Selesai") ...[
                          Container(
                            padding: EdgeInsets.all(12 * scale),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12 * scale),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _statusTerpilih == "Selesai"
                                      ? Icons.check_circle
                                      : Icons.hourglass_top_rounded,
                                  color: _statusTerpilih == "Selesai"
                                      ? Colors.green.shade700
                                      : Colors.blue.shade700,
                                ),
                                SizedBox(width: 10 * scale),
                                Expanded(
                                  child: Text(
                                    _statusTerpilih == "Selesai"
                                        ? "Tugas telah disetujui dan diselesaikan oleh atasan."
                                        : "Pekerjaan sudah dikirim dan sedang dalam proses peninjauan oleh atasan.",
                                    style: TextStyle(
                                      fontSize: 12 * scale,
                                      color: _statusTerpilih == "Selesai"
                                          ? Colors.green.shade900
                                          : Colors.blue.shade900,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 14 * scale),
                          Text(
                            "Keterangan Terkirim:",
                            style: TextStyle(
                              fontSize: 12 * scale,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                          SizedBox(height: 4 * scale),
                          Text(
                            _keteranganController.text.isEmpty
                                ? "-"
                                : _keteranganController.text,
                            style: TextStyle(
                              fontSize: 12.5 * scale,
                              color: Colors.grey[800],
                            ),
                          ),
                          if (_namaFileDipilih != null) ...[
                            SizedBox(height: 10 * scale),
                            Row(
                              children: [
                                const Icon(
                                  Icons.attach_file,
                                  size: 16,
                                  color: kBiruTua,
                                ),
                                SizedBox(width: 4 * scale),
                                Text(
                                  _namaFileDipilih!,
                                  style: TextStyle(
                                    fontSize: 12 * scale,
                                    color: kBiruTua,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
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
      case "Terkendala":
        warna = Colors.red.shade700;
        break;
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
