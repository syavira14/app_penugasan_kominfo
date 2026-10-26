import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import '../../widgets/app_layout.dart';

const Color kBiruTua = Color(0xFF1A1464);
const Color kBiruSedang = Color(0xFF1D5FA0);
const Color kBiruMuda = Color(0xFF4FA6DE);
const Color kBgLight = Color(0xFFF7F9FB);

class _DetailTugasModel {
  final String idTugas;
  final String penugasanId;
  String judulTugas;
  String deskripsiTugas;
  String lokasi;
  DateTime tanggalDiberikan;
  DateTime tanggalMulai;
  DateTime batasWaktu;
  String prioritasTugas;
  String namaAtasan;
  String statusTugas;
  String? fileHasil;
  String? keteranganHasil;
  String? catatanRevisi;
  String? deskripsiKendala;
  String? dampakKendala;
  String? jenisKendala;
  String? fileKendala;
  String? statusKendala;

  _DetailTugasModel({
    required this.idTugas,
    required this.penugasanId,
    required this.judulTugas,
    required this.deskripsiTugas,
    required this.lokasi,
    required this.tanggalDiberikan,
    required this.tanggalMulai,
    required this.batasWaktu,
    required this.prioritasTugas,
    required this.namaAtasan,
    required this.statusTugas,
    this.fileHasil,
    this.keteranganHasil,
    this.catatanRevisi,
    this.deskripsiKendala,
    this.dampakKendala,
    this.jenisKendala,
    this.fileKendala,
    this.statusKendala,
  });
}

class TugasDetailPage extends StatefulWidget {
  final String penugasanId;

  const TugasDetailPage({super.key, required this.penugasanId});

  @override
  State<TugasDetailPage> createState() => _TugasDetailPageState();
}

class _TugasDetailPageState extends State<TugasDetailPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  _DetailTugasModel? _detailTugas;

  late String _statusTerpilih;
  late TextEditingController _keteranganController;

  String? _namaFileDipilih;
  String? _fileHasilUrl;

  PlatformFile? _selectedFile;

  bool _loading = true;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _statusTerpilih = "Pending";
    _keteranganController = TextEditingController();
    _loadDetail();
  }

  @override
  void dispose() {
    _keteranganController.dispose();
    super.dispose();
  }

  DateTime _asDate(dynamic value, [DateTime? fallback]) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return fallback ?? DateTime.now();
  }

  String _statusUi(dynamic status) {
    switch ((status ?? 'pending').toString().toLowerCase()) {
      case 'berlangsung':
        return 'Berlangsung';
      case 'dikumpulkan':
        return 'Menunggu Disetujui';
      case 'revisi':
        return 'Revisi';
      case 'disetujui':
        return 'Selesai';
      case 'terkendala':
        return 'Terkendala';
      default:
        return 'Pending';
    }
  }

  Future<void> _loadDetail() async {
    try {
      final assignmentDoc = await _firestore
          .collection('penugasan')
          .doc(widget.penugasanId)
          .get();

      if (!assignmentDoc.exists) {
        throw Exception('Data penugasan tidak ditemukan.');
      }

      final assignment = assignmentDoc.data()!;
      final taskId = (assignment['tugas_id'] ?? '').toString();

      if (taskId.isEmpty) {
        throw Exception('ID tugas tidak ditemukan.');
      }

      final taskDoc = await _firestore.collection('tugas').doc(taskId).get();
      if (!taskDoc.exists) {
        throw Exception('Data tugas tidak ditemukan.');
      }

      final task = taskDoc.data()!;
      final adminId = (task['dibuat_oleh'] ?? '').toString();

      Map<String, dynamic> admin = {};
      if (adminId.isNotEmpty) {
        admin =
            (await _firestore.collection('users').doc(adminId).get()).data() ??
            {};
      }

      final currentStatus = _statusUi(assignment['status']);

      final model = _DetailTugasModel(
        idTugas: taskId,
        penugasanId: assignmentDoc.id,
        judulTugas: (task['judul'] ?? '-').toString(),
        deskripsiTugas: (task['deskripsi'] ?? '-').toString(),
        lokasi: (task['tempat_tugas'] ?? '-').toString(),
        tanggalDiberikan: _asDate(task['tanggal_tugas_diberikan']),
        tanggalMulai: _asDate(task['tanggal_mulai_tugas']),
        batasWaktu: _asDate(task['tanggal_selesai_tugas']),
        prioritasTugas: _capitalize((task['prioritas'] ?? 'sedang').toString()),
        namaAtasan: (admin['nama'] ?? 'Atasan').toString(),
        statusTugas: currentStatus,
        fileHasil: (assignment['file_hasil_nama'] ?? '').toString().isEmpty
            ? null
            : assignment['file_hasil_nama'].toString(),
        keteranganHasil: (assignment['catatan_staff'] ?? '').toString().isEmpty
            ? null
            : assignment['catatan_staff'].toString(),
        catatanRevisi: (assignment['catatan_revisi'] ?? '').toString().isEmpty
            ? null
            : assignment['catatan_revisi'].toString(),
      );

      if (!mounted) return;

      setState(() {
        _detailTugas = model;
        _statusTerpilih = currentStatus;
        _keteranganController.text = model.keteranganHasil ?? '';
        _namaFileDipilih = model.fileHasil;
        _fileHasilUrl = (assignment['file_hasil_url'] ?? '').toString().isEmpty
            ? null
            : assignment['file_hasil_url'].toString();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal memuat detail tugas: $e')));
    }
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1).toLowerCase();
  }

  Future<void> _mulaiKerjakan() async {
    try {
      await _firestore.collection('penugasan').doc(widget.penugasanId).update({
        'status': 'berlangsung',
        'updated_at': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      setState(() {
        _statusTerpilih = 'Berlangsung';
        _detailTugas?.statusTugas = 'Berlangsung';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tugas dimulai! Status diubah menjadi Berlangsung.'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal memulai tugas: $e')));
    }
  }

  Future<void> _kirimHasilPekerjaan() async {
    if (_selectedFile == null &&
        _keteranganController.text.trim().isEmpty &&
        _fileHasilUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Harap isi keterangan atau unggah file bukti hasil!'),
        ),
      );
      return;
    }

    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sesi login tidak ditemukan.')),
      );
      return;
    }

    final statusSebelum = _statusTerpilih;
    setState(() {
      _uploading = true;
    });

    try {
      String? fileUrl = _fileHasilUrl;
      String? fileName = _namaFileDipilih;

      if (_selectedFile != null) {
        final bytes = await _selectedFile!.readAsBytes();
        final ref = FirebaseStorage.instance.ref().child(
          'tugas/${_detailTugas!.idTugas}/${user.uid}/${DateTime.now().millisecondsSinceEpoch}_${_selectedFile!.name}',
        );

        final upload = await ref.putData(
          bytes,
          SettableMetadata(contentType: _contentType(_selectedFile!.extension)),
        );

        fileUrl = await upload.ref.getDownloadURL();
        fileName = _selectedFile!.name;
      }

      await _firestore.collection('penugasan').doc(widget.penugasanId).update({
        'status': 'dikumpulkan',
        'file_hasil_url': fileUrl ?? '',
        'file_hasil_nama': fileName ?? '',
        'catatan_staff': _keteranganController.text.trim(),
        'tanggal_dikumpulkan': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      setState(() {
        _statusTerpilih = 'Menunggu Disetujui';
        _detailTugas?.statusTugas = 'Menunggu Disetujui';
        _detailTugas?.keteranganHasil = _keteranganController.text;
        _detailTugas?.fileHasil = fileName;
        _namaFileDipilih = fileName;
        _fileHasilUrl = fileUrl;
        _selectedFile = null;
        _uploading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            statusSebelum == 'Revisi'
                ? 'Hasil revisi berhasil dikirim ke atasan!'
                : 'Hasil pekerjaan berhasil dikirim ke atasan!',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _uploading = false;
        });
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal mengirim hasil: $e')));
    }
  }

  Future<void> _lanjutkanPekerjaan() async {
    try {
      await _firestore.collection('penugasan').doc(widget.penugasanId).update({
        'status': 'berlangsung',
        'updated_at': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      setState(() {
        _statusTerpilih = 'Berlangsung';
        _detailTugas?.statusTugas = 'Berlangsung';
        _detailTugas?.statusKendala = 'Selesai/Dibatalkan';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kendala diselesaikan, tugas kembali Berlangsung.'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal melanjutkan tugas: $e')));
    }
  }

  String _contentType(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      default:
        return 'application/octet-stream';
    }
  }

  void _bukaFormKendala() {
    final deskripsi = TextEditingController(
      text: _detailTugas!.deskripsiKendala ?? "",
    );
    final dampak = TextEditingController(
      text: _detailTugas!.dampakKendala ?? "",
    );
    String jenis = _detailTugas!.jenisKendala ?? "Internal";
    String? lampiranKendala = _detailTugas!.fileKendala;
    String? lampiranKendalaUrl;

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
                              _detailTugas!.judulTugas,
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
                            onTap: () async {
                              final file = await FilePicker.pickFile(
                                type: FileType.any,
                              );
                              if (file == null) return;

                              try {
                                final user = _auth.currentUser;
                                if (user == null) {
                                  throw Exception(
                                    'Sesi login tidak ditemukan.',
                                  );
                                }

                                final laporanRef = _firestore
                                    .collection('laporan_kendala')
                                    .doc();

                                final storageRef = FirebaseStorage.instance
                                    .ref()
                                    .child(
                                      'laporan/${laporanRef.id}/${DateTime.now().millisecondsSinceEpoch}_${file.name}',
                                    );

                                final bytes = await file.readAsBytes();
                                final upload = await storageRef.putData(
                                  bytes,
                                  SettableMetadata(
                                    contentType: _contentType(file.extension),
                                  ),
                                );

                                final url = await upload.ref.getDownloadURL();
                                if (!modalContext.mounted) return;

                                setModalState(() {
                                  lampiranKendala = file.name;
                                  lampiranKendalaUrl = url;
                                });
                              } catch (e) {
                                if (!modalContext.mounted) return;
                                ScaffoldMessenger.of(modalContext).showSnackBar(
                                  SnackBar(
                                    content: Text('Gagal mengunggah bukti: $e'),
                                  ),
                                );
                              }
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
                                          lampiranKendalaUrl = null;
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
                              onPressed: () async {
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

                                final user = _auth.currentUser;
                                if (user == null) return;

                                try {
                                  final ref = _firestore
                                      .collection('laporan_kendala')
                                      .doc();

                                  await ref.set({
                                    'tugas_id': _detailTugas!.idTugas,
                                    'penugasan_id': widget.penugasanId,
                                    'pelapor_id': user.uid,
                                    'jenis_kendala': jenis.toLowerCase(),
                                    'deskripsi': deskripsi.text.trim(),
                                    'dampak': dampak.text.trim(),
                                    'bukti_url': lampiranKendalaUrl ?? '',
                                    'prioritas': 'sedang',
                                    'status': 'menunggu_review',
                                    'solusi': '',
                                    'ditangani_oleh': '',
                                    'tanggal_laporan':
                                        FieldValue.serverTimestamp(),
                                    'created_at': FieldValue.serverTimestamp(),
                                    'updated_at': FieldValue.serverTimestamp(),
                                  });

                                  if (!modalContext.mounted) return;
                                  Navigator.pop(modalContext);

                                  if (mounted) {
                                    setState(() {
                                      _detailTugas!.statusTugas = 'Terkendala';
                                      _statusTerpilih = 'Terkendala';
                                      _detailTugas!.jenisKendala = jenis;
                                      _detailTugas!.deskripsiKendala = deskripsi
                                          .text
                                          .trim();
                                      _detailTugas!.dampakKendala = dampak.text
                                          .trim();
                                      _detailTugas!.fileKendala =
                                          lampiranKendala;
                                      _detailTugas!.statusKendala =
                                          'Menunggu Atasan';
                                    });

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Kendala berhasil dilaporkan kepada atasan',
                                        ),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (!modalContext.mounted) return;
                                  ScaffoldMessenger.of(
                                    modalContext,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Gagal mengirim laporan: $e',
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
    final double width = MediaQuery.of(context).size.width;
    final double scale = (width / 375).clamp(0.85, 1.25);

    if (_loading || _detailTugas == null) {
      return const Scaffold(
        backgroundColor: kBgLight,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final tugas = _detailTugas!;
    final bool isRevisi = _statusTerpilih == "Revisi";

    return Scaffold(
      backgroundColor: kBgLight,
      body: Column(
        children: [
          // HEADER GRADIENT FLAT / LURUS
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
          ),

          // CONTENT LIST
          Expanded(
            child: ResponsiveContent(
              child: Padding(
                padding: EdgeInsets.fromLTRB(0, 16 * scale, 0, 12 * scale),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                      SizedBox(height: 14 * scale),
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
                                tugas.catatanRevisi ??
                                    'Tidak ada catatan revisi.',
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

                      // ==== FORM PENGERJAAN ====
                      _sectionLabel("Pengerjaan Tugas", scale),
                      SizedBox(height: 14 * scale),
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
                                  borderRadius: BorderRadius.circular(
                                    14 * scale,
                                  ),
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
                              onTap: () async {
                                final file = await FilePicker.pickFile(
                                  type: FileType.any,
                                );
                                if (file == null) return;
                                setState(() {
                                  _selectedFile = file;
                                  _namaFileDipilih = file.name;
                                });
                              },
                              borderRadius: BorderRadius.circular(14 * scale),
                              child: Container(
                                padding: EdgeInsets.all(14 * scale),
                                decoration: BoxDecoration(
                                  color: kBiruMuda.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(
                                    14 * scale,
                                  ),
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
                                onPressed: _uploading
                                    ? null
                                    : _kirimHasilPekerjaan,
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
                                  minimumSize: Size(
                                    double.infinity,
                                    48 * scale,
                                  ),
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
                                  borderRadius: BorderRadius.circular(
                                    14 * scale,
                                  ),
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
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, double scale) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 17 * scale,
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
