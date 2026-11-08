import 'dart:ui' as ui;
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../widgets/pdf_iframe_stub.dart'
    if (dart.library.js_interop) '../../widgets/pdf_iframe_web.dart';
import 'dart:typed_data';
import 'package:url_launcher/url_launcher.dart';
import '../../services/penugasan_workflow.dart';
import '../../services/laporan_kendala_service.dart';
import '../../services/pengiriman_hasil_service.dart';
import 'riwayat_tugas.dart' show RiwayatTugasPage;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/supabase_storage_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

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
  double? latitude;
  double? longitude;
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
    this.latitude,
    this.longitude,
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
  final SupabaseStorageService _storageService = SupabaseStorageService();
  final LaporanKendalaService _kendalaService = LaporanKendalaService();

  _DetailTugasModel? _detailTugas;

  Map<String, dynamic>? _assignmentData;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;
  bool _changingStatus = false;

  late String _statusTerpilih;
  late TextEditingController _keteranganController;

  String? _namaFileDipilih;
  String? _fileHasilUrl;
  String? _fileHasilPath;

  PlatformFile? _selectedFile;

  bool _loading = true;
  String? _loadError;
  int _loadVersion = 0;
  bool _uploading = false;
  String _submissionStage = '';
  PlatformFile? _uploadedFile;

  @override
  void initState() {
    super.initState();

    _statusTerpilih = "Pending";
    _keteranganController = TextEditingController();

    _subscription = _firestore
        .collection('penugasan')
        .doc(widget.penugasanId)
        .snapshots()
        .listen(
          (doc) => _loadDetail(doc),
          onError: (Object error) {
            if (!mounted) return;
            setState(() {
              _loading = false;
              _loadError = 'Gagal memuat penugasan: $error';
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Gagal memuat penugasan: $error')),
            );
          },
        );
  }

  @override
  void dispose() {
    _subscription?.cancel();
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
        return 'Dikumpulkan';

      case 'revisi':
        return 'Revisi';

      case 'disetujui':
        return 'Selesai';

      case 'terkendala':
        return 'Terkendala';

      case 'dihentikan':
        return 'Dihentikan';

      default:
        return 'Pending';
    }
  }

  Future<void> _loadDetail(
    DocumentSnapshot<Map<String, dynamic>> assignmentDoc,
  ) async {
    final version = ++_loadVersion;
    try {
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
        latitude: (task['latitude'] as num?)?.toDouble(),
        longitude: (task['longitude'] as num?)?.toDouble(),
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

      if (!mounted || version != _loadVersion) return;

      final previousStatus = _detailTugas?.statusTugas;
      final refreshForm =
          previousStatus == null || previousStatus != currentStatus;
      setState(() {
        _loadError = null;
        _assignmentData = {'id': assignmentDoc.id, ...assignment};

        _detailTugas = model;

        _statusTerpilih = currentStatus;

        if (refreshForm) {
          _selectedFile = null;
          _keteranganController.text = currentStatus == 'Revisi' ? '' : (model.keteranganHasil ?? '');

          _namaFileDipilih = currentStatus == 'Revisi' ? null : model.fileHasil;

          _fileHasilUrl = currentStatus == 'Revisi' ? null :
              (assignment['file_hasil_url'] ?? '').toString().isEmpty
              ? null
              : assignment['file_hasil_url'].toString();
          _fileHasilPath = currentStatus == 'Revisi' ? null :
              (assignment['file_hasil_path'] ?? '').toString().isEmpty
              ? null
              : assignment['file_hasil_path'].toString();
        }
        _loading = false;
      });
      if (currentStatus == 'Selesai' &&
          previousStatus != null &&
          previousStatus != 'Selesai') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const RiwayatTugasPage()),
        );
      }
    } catch (e) {
      if (!mounted || version != _loadVersion) return;

      setState(() {
        _loading = false;
        _loadError = 'Gagal memuat detail tugas: $e';
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal memuat detail tugas: $e')));
    }
  }

  String _capitalize(String value) {
    if (value.isEmpty) {
      return value;
    }

    return value[0].toUpperCase() + value.substring(1).toLowerCase();
  }

  Future<void> _mulaiKerjakan() async {
    if (_changingStatus || _statusTerpilih != 'Pending') return;
    setState(() => _changingStatus = true);
    try {
      await transitionAssignment(_firestore, widget.penugasanId, 'berlangsung');

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
    } finally {
      if (mounted) setState(() => _changingStatus = false);
    }
  }

  void _setSubmissionStage(String stage) {
    if (mounted) setState(() => _submissionStage = stage);
  }

  Future<void> _kirimHasilPekerjaan() async {
    if (_uploading) return;
    if (!['Berlangsung', 'Revisi'].contains(_statusTerpilih)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tugas hanya dapat dikirim saat berlangsung atau revisi.',
          ),
        ),
      );
      return;
    }
    if (_keteranganController.text.trim().isEmpty || _selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Harap isi keterangan dan unggah file hasil pekerjaan!',
          ),
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
    // Periksa sebelum upload agar file tidak terunggah sia-sia jika revisi
    // tidak memiliki pasangan riwayat yang sah.
    if (_statusTerpilih == 'Revisi') {
      try {
        final assignment = await _firestore
            .collection('penugasan').doc(widget.penugasanId).get();
        final data = assignment.data();
        final revisionId = (data?['revisi_aktif_id'] ?? '').toString();
        if (data?['status'] != 'revisi' || revisionId.isEmpty) {
          throw StateError(
            'Instruksi revisi belum terhubung. Minta Atasan mengirim ulang '
            'instruksi revisi sebelum mengumpulkan hasil.');
        }
        final revision = await assignment.reference
            .collection('riwayat_revisi').doc(revisionId).get();
        if (!revision.exists ||
            revision.data()?['status'] != 'menunggu_perbaikan') {
          throw StateError(
            'Riwayat revisi aktif tidak ditemukan atau sudah selesai. '
            'Hubungi Atasan untuk memperbarui instruksi revisi.');
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(duration: const Duration(seconds: 8),
              content: Text('Tidak dapat mengirim revisi: $e')),
        );
        return;
      }
    }

    final statusSebelum = _statusTerpilih;
    final revisionBefore = _assignmentData?['tanggal_revisi'];
    final submittedNotes = _keteranganController.text.trim();
    final selectedFile = _selectedFile;
    String? fileUrl = _fileHasilUrl;
    String? filePath = _fileHasilPath;
    String? fileName = _namaFileDipilih;
    setState(() => _uploading = true);
    try {
      if (selectedFile != null && !identical(selectedFile, _uploadedFile)) {
        _setSubmissionStage('Membaca file');
        final bytes = await runSubmissionStep(
          () => selectedFile.readAsBytes(),
          timeout: const Duration(seconds: 20),
          timeoutMessage:
              'File tidak selesai dibaca. Pilih ulang file dari perangkat.',
        );
        if (bytes.isEmpty)
          throw StateError('File kosong. Pilih file hasil yang valid.');
        _setSubmissionStage('Mengunggah file');
        if (bytes.length > 10 * 1024 * 1024) {
          throw StateError('Ukuran file maksimal 10 MB.');
        }
        final uploaded = await runSubmissionStep(
          () => _storageService.uploadHasilTugas(
            tugasId: _detailTugas!.idTugas,
            namaFile: selectedFile.name,
            bytes: bytes,
            contentType: _contentType(selectedFile.extension),
          ),
          timeout: const Duration(seconds: 90),
          timeoutMessage:
              'Upload Supabase terlalu lama. Periksa koneksi internet.',
        );
        filePath = uploaded.path;
        fileUrl = null; // URL lama tidak digunakan untuk upload baru.
        fileName = selectedFile.name;
        // Jika penyimpanan Firestore gagal, percobaan berikutnya memakai file
        // yang sudah diunggah selama pilihan file belum berubah.
        if (mounted) {
          _fileHasilUrl = fileUrl;
          _fileHasilPath = filePath;
          _uploadedFile = selectedFile;
        }
      }
      _setSubmissionStage('Menyimpan hasil');
      await runSubmissionStep(
        () => _simpanPengumpulanDenganRiwayat(
          statusSebelum: statusSebelum,
          catatan: submittedNotes,
          filePath: filePath ?? '',
          fileUrl: fileUrl ?? '',
          fileName: fileName ?? '',
        ),
        timeout: const Duration(seconds: 35),
        timeoutMessage: 'Penyimpanan hasil belum mendapat konfirmasi. Periksa koneksi dan status tugas sebelum mencoba lagi.',
      );
      if (!mounted) return;
      // Tampilkan status yang telah dikonfirmasi Firestore segera, tanpa
      // menunggu pembacaan ulang tugas dan profil atasan di listener.
      final latestStatus = (_assignmentData?['status'] ?? '').toString();
      final receivedNewRevision =
          latestStatus == 'revisi' &&
          (statusSebelum != 'Revisi' ||
              _assignmentData?['tanggal_revisi'] != revisionBefore);
      if (latestStatus != 'disetujui' && !receivedNewRevision) {
        setState(() {
          _statusTerpilih = 'Dikumpulkan';
          _detailTugas?.statusTugas = 'Dikumpulkan';
          _detailTugas?.keteranganHasil = submittedNotes;
          _detailTugas?.fileHasil = fileName;
          _namaFileDipilih = fileName;
          _fileHasilUrl = fileUrl;
          _fileHasilPath = filePath;
          _selectedFile = null;
          _uploadedFile = null;
        });
      }
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
      if (!mounted) return;
      final message = e is TimeoutException
          ? e.message ?? 'Waktu pengiriman habis.'
          : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          content: Text('Gagal pada tahap $_submissionStage: $message'),
        ),
      );
    } finally {
      if (mounted)
        setState(() {
          _uploading = false;
          _submissionStage = '';
        });
    }
  }


  Future<void> _simpanPengumpulanDenganRiwayat({
    required String statusSebelum,
    required String catatan,
    required String filePath,
    required String fileUrl,
    required String fileName,
  }) async {
    final ref = _firestore.collection('penugasan').doc(widget.penugasanId);
    final riwayat = ref.collection('riwayat_pengumpulan').doc();
    await _firestore.runTransaction((tx) async {
      final snapshot = await tx.get(ref);
      final current = (snapshot.data()?['status'] ?? '').toString();
      if (current != (statusSebelum == 'Revisi' ? 'revisi' : 'berlangsung')) {
        throw StateError('Status berubah. Muat ulang tugas sebelum mengirim.');
      }
      if ((snapshot.data()?['kendala_aktif_id'] ?? '').toString().isNotEmpty) {
        throw StateError('Selesaikan laporan kendala terlebih dahulu.');
      }
      final revisiId = statusSebelum == 'Revisi'
          ? (snapshot.data()?['revisi_aktif_id'] ?? '').toString()
          : '';
      if (statusSebelum == 'Revisi' && revisiId.isEmpty) {
        throw StateError('ID revisi aktif kosong. Hubungi Atasan untuk '
            'mengirim ulang instruksi revisi.');
      }
      if (revisiId.isNotEmpty) {
        final revision = await tx.get(
            ref.collection('riwayat_revisi').doc(revisiId));
        if (!revision.exists ||
            revision.data()?['status'] != 'menunggu_perbaikan') {
          throw StateError('Instruksi revisi sudah berubah atau tidak tersedia.');
        }
      }
      tx.set(riwayat, {
        'penugasan_id': widget.penugasanId,
        'staff_id': _auth.currentUser!.uid,
        'jenis': statusSebelum == 'Revisi' ? 'revisi' : 'awal',
        'revisi_id': revisiId,
        'keterangan': catatan,
        'file_path': filePath,
        'file_url': fileUrl,
        'file_nama': fileName,
        'created_at': FieldValue.serverTimestamp(),
      });
      if (revisiId.isNotEmpty) {
        tx.update(ref.collection('riwayat_revisi').doc(revisiId), {
          'hasil_pengumpulan_id': riwayat.id,
          'status': 'selesai',
          'tanggal_diperbaiki': FieldValue.serverTimestamp(),
        });
      }
      tx.update(ref, {
        'status': 'dikumpulkan',
        'revisi_aktif_id': '',
        'file_hasil_url': fileUrl,
        'file_hasil_path': filePath,
        'file_hasil_provider': filePath.isNotEmpty ? 'supabase' : 'firebase',
        'file_hasil_nama': fileName,
        'catatan_staff': catatan,
        'updated_at': FieldValue.serverTimestamp(),
        'tanggal_dikumpulkan': FieldValue.serverTimestamp(),
      });
    });
  }

  Widget _riwayatPanel({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(.20)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.035), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(width: 9),
          Expanded(child: Text(title, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 10),
        child,
      ]),
    );
  }

  Widget _riwayatBaris(String label, dynamic value, {bool emphasize = false}) {
    final content = (value ?? '').toString().trim();
    if (content.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade600, fontWeight: FontWeight.w600)),
        const SizedBox(height: 3),
        Text(content, style: TextStyle(fontSize: 13, height: 1.4, color: kBiruTua, fontWeight: emphasize ? FontWeight.w600 : FontWeight.normal)),
      ]),
    );
  }

  Widget _riwayatPengumpulan() {
    final ref = _firestore.collection('penugasan').doc(widget.penugasanId);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: ref.collection('riwayat_pengumpulan').orderBy('created_at').snapshots(),
      builder: (context, hasilSnap) {
        if (hasilSnap.hasError) {
          return _riwayatPanel(title: 'Riwayat Pengerjaan dan Revisi', icon: Icons.history, color: kBiruSedang,
            child: Text('Riwayat hasil belum dapat dimuat: ${hasilSnap.error}', style: const TextStyle(fontSize: 12)));
        }
        final hasil = hasilSnap.data?.docs ?? [];
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: ref.collection('riwayat_revisi').orderBy('created_at').snapshots(),
          builder: (context, revisiSnap) {
            if (revisiSnap.hasError) {
              return _riwayatPanel(title: 'Riwayat Pengerjaan dan Revisi', icon: Icons.history, color: kBiruSedang,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Riwayat revisi belum dapat diakses. Pastikan aturan Firestore untuk riwayat_revisi sudah dipublikasikan.', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 5),
                  Text('${revisiSnap.error}', style: const TextStyle(fontSize: 11, color: Colors.redAccent)),
                ]));
            }
            final revisi = revisiSnap.data?.docs ?? [];
            if (hasil.isEmpty && revisi.isEmpty) return const SizedBox.shrink();
            final awal = hasil.where((d) => (d.data()['revisi_id'] ?? '').toString().isEmpty).toList();
            final terkait = <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
            for (final d in hasil) {
              final id = (d.data()['revisi_id'] ?? '').toString();
              if (id.isNotEmpty) terkait.putIfAbsent(id, () => []).add(d);
            }
            Widget hasilTile(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
              final d = doc.data();
              final name = (d['file_nama'] ?? 'Lampiran hasil').toString();
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _riwayatBaris('Keterangan Staff', d['keterangan']),
                OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      final url = await _storageService.ambilLinkRiwayat(widget.penugasanId, doc.id);
                      await _bukaFile(url, namaFile: name);
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('Gagal membuka hasil: $e')));
                    }
                  },
                  icon: const Icon(Icons.attach_file, size: 17),
                  label: Text(name, overflow: TextOverflow.ellipsis),
                ),
              ]);
            }
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(padding: EdgeInsets.only(bottom: 10),
                child: Text('Riwayat Pengerjaan dan Revisi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kBiruTua))),
              for (final doc in awal)
                _riwayatPanel(title: 'Pengumpulan Hasil Pertama', icon: Icons.upload_file, color: kBiruSedang, child: hasilTile(doc)),
              for (var i = 0; i < revisi.length; i++)
                _riwayatPanel(title: 'Revisi ke-${i + 1}', icon: Icons.edit_note, color: Colors.deepOrange.shade700,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _riwayatBaris('Instruksi Atasan', revisi[i].data()['catatan_atasan']),
                    if ((revisi[i].data()['file_revisi_nama'] ?? '').toString().isNotEmpty)
                      _riwayatBaris('Lampiran Instruksi', revisi[i].data()['file_revisi_nama']),
                    const Divider(height: 22),
                    Row(children: [
                      Icon(Icons.task_alt, size: 17, color: Colors.green.shade700),
                      const SizedBox(width: 6),
                      const Expanded(child: Text('Hasil Perbaikan Staff', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                    ]),
                    const SizedBox(height: 9),
                    if ((terkait[revisi[i].id] ?? []).isEmpty)
                      const Text('Menunggu hasil perbaikan Staff', style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
                    for (final hasilDoc in terkait[revisi[i].id] ?? []) hasilTile(hasilDoc),
                  ])),
              for (final doc in hasil.where((d) =>
                  (d.data()['revisi_id'] ?? '').toString().isNotEmpty &&
                  !revisi.any((r) => r.id == d.data()['revisi_id'])))
                _riwayatPanel(title: 'Hasil Revisi Lama (belum terhubung)', icon: Icons.history, color: Colors.blueGrey,
                  child: hasilTile(doc)),
              const SizedBox(height: 8),
            ]);
          },
        );
      },
    );
  }

  Widget _semuaRiwayatKendala() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection('laporan_kendala')
          .where('penugasan_id', isEqualTo: widget.penugasanId)
          .where('pelapor_id', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _riwayatPanel(title: 'Seluruh Riwayat Kendala', icon: Icons.report_problem_outlined,
            color: kBiruSedang, child: Text('Riwayat kendala gagal dimuat: ${snapshot.error}', style: const TextStyle(fontSize: 12)));
        }
        final reports = [...?snapshot.data?.docs];
        if (reports.isEmpty) return const SizedBox.shrink();
        reports.sort((a, b) {
          final ta = a.data()['created_at'];
          final tb = b.data()['created_at'];
          if (ta is Timestamp && tb is Timestamp) return ta.compareTo(tb);
          return 0;
        });
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(padding: EdgeInsets.only(bottom: 10),
            child: Text('Seluruh Riwayat Kendala', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kBiruTua))),
          for (var i = 0; i < reports.length; i++)
            _riwayatPanel(title: 'Laporan Kendala ${i + 1}', icon: Icons.report_problem_outlined, color: Colors.deepOrange.shade700,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _riwayatBaris('Laporan', reports[i].data()['deskripsi']),
                _riwayatBaris('Dampak', reports[i].data()['dampak']),
                _riwayatBaris('Solusi Terakhir', reports[i].data()['solusi']),
                _riwayatBaris('Status', reports[i].data()['status'], emphasize: true),
                _riwayatKendala(reports[i].id),
              ])),
          const SizedBox(height: 8),
        ]);
      },
    );
  }

  Widget _riwayatKendala(String laporanId) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection('laporan_kendala').doc(laporanId)
          .collection('riwayat').orderBy('created_at').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Text('Riwayat kendala gagal dimuat: ${snapshot.error}', style: const TextStyle(fontSize: 12));
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 10),
          const Divider(height: 16),
          const Text('Riwayat Laporan dan Solusi Sebelumnya', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: kBiruTua)),
          const SizedBox(height: 8),
          ...docs.asMap().entries.map((entry) {
            final d = entry.value.data();
            final stamp = d['created_at'];
            final tanggal = stamp is Timestamp ? stamp.toDate().toLocal().toString().substring(0, 16) : '-';
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 9),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF5F7FC), borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE1E7F0))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Putaran ${entry.key + 1} • $tanggal', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: kBiruTua)),
                const SizedBox(height: 9),
                _riwayatBaris('Kendala', d['deskripsi_sebelumnya']),
                _riwayatBaris('Dampak', d['dampak_sebelumnya']),
                _riwayatBaris('Solusi Atasan', d['solusi_sebelumnya']),
                _riwayatBaris('Tanggapan Staff', d['feedback']),
                if ((d['solusi_file_path'] ?? '').toString().isNotEmpty)
                  const Text('Lampiran solusi sebelumnya tercatat dalam riwayat.', style: TextStyle(fontSize: 11, color: Colors.blueGrey)),
              ]),
            );
          }),
        ]);
      },
    );
  }

  Widget _solusiKendala() {
    final id = (_assignmentData?['kendala_aktif_id'] ?? '').toString();
    if (id.isEmpty) return const Text('Laporan kendala sedang disinkronkan.');
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection('laporan_kendala').doc(id).snapshots(),
      builder: (context, snapshot) {
        final d = snapshot.data?.data();
        if (d == null) return const CircularProgressIndicator();
        final status = (d['status'] ?? '').toString();
        if (status != StatusLaporanKendala.menungguKonfirmasi) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Laporan sedang ditinjau Atasan.'),
            _riwayatKendala(id),
            if (status == StatusLaporanKendala.menungguReview)
              OutlinedButton.icon(onPressed: _bukaFormKendala, icon: const Icon(Icons.edit), label: const Text('Edit Laporan Kendala')),
          ]);
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _riwayatKendala(id),
          const Text('Solusi dari Atasan', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text((d['solusi'] ?? '').toString()),
          if ((d['solusi_file_path'] ?? '').toString().isNotEmpty)
            TextButton.icon(onPressed: () async {
              try { await _bukaFile(
                  await _storageService.ambilLinkSolusi(id),
                  namaFile: (d['solusi_file_nama'] ?? d['solusi_file_path'] ?? 'Lampiran Solusi').toString().split('/').last,
                ); }
              catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal membuka solusi: $e'))); }
            }, icon: const Icon(Icons.attach_file), label: const Text('Lihat Lampiran Solusi')),
          const SizedBox(height: 10),
          ElevatedButton.icon(onPressed: _lanjutkanPekerjaan, icon: const Icon(Icons.check_circle), label: const Text('Kendala Teratasi, Lanjutkan Tugas')),
          OutlinedButton.icon(onPressed: () => _bukaFormKendala(lanjutan: true), icon: const Icon(Icons.report_problem), label: const Text('Kendala Belum Teratasi')),
        ]);
      },
    );
  }

  Future<void> _bukaNavigasi() async {
    final tugas = await _firestore.collection('tugas').doc(_detailTugas!.idTugas).get();
    final lat = (tugas.data()?['latitude'] as num?)?.toDouble();
    final lng = (tugas.data()?['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Koordinat lokasi belum tersedia.')));
      return;
    }
    final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  Future<void> _lanjutkanPekerjaan() async {
    try {
      final penugasan = await _firestore.collection('penugasan')
          .doc(widget.penugasanId).get();
      final aktifId = (penugasan.data()?['kendala_aktif_id'] ?? '').toString();
      if (aktifId.isEmpty) {
        throw StateError(
          'Laporan kendala lama belum tersinkronisasi. '
          'Hubungi Atasan untuk memproses laporan terlebih dahulu.',
        );
      }
      final laporan = await _firestore.collection('laporan_kendala')
          .doc(aktifId).get();
      final status = (laporan.data()?['status'] ?? '').toString();
      if (status == StatusLaporanKendala.menungguKonfirmasi) {
        await _kendalaService.konfirmasiSelesai(aktifId);
      } else {
        throw StateError(
          'Belum dapat melanjutkan. Tunggu solusi Atasan dan konfirmasi '
          'bahwa kendala telah teratasi.',
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kendala dikonfirmasi selesai. Tugas kembali berlangsung.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal melanjutkan tugas: $e')),
      );
    }
  }

  // Buka lampiran solusi dan riwayat di dalam SIMTAS, bukan tab browser.
  Future<void> _bukaFile(String url, {String? namaFile}) async {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null || !uri.hasScheme ||
          (uri.scheme != 'https' && uri.scheme != 'http')) {
        throw StateError('URL file tidak valid.');
      }
      final pathName = uri.pathSegments.isEmpty
          ? 'Lampiran'
          : Uri.decodeComponent(uri.pathSegments.last);
      var name = (namaFile?.trim().isNotEmpty ?? false)
          ? namaFile!.trim()
          : pathName;
      // File Supabase kadang memiliki awalan timestamp, tetapi ekstensi tetap utuh.
      final lower = name.toLowerCase();
      final pdf = lower.endsWith('.pdf');
      final image = lower.endsWith('.png') ||
          lower.endsWith('.jpg') || lower.endsWith('.jpeg');
      Uint8List bytes = Uint8List(0);
      if (!kIsWeb || !pdf) {
        final response = await http.get(uri);
        if (response.statusCode != 200) {
          throw StateError('Gagal mengambil file (HTTP ${response.statusCode}).');
        }
        bytes = response.bodyBytes;
        // Untuk file dengan nama tanpa ekstensi, deteksi dari MIME response.
        if (!pdf && !image && !name.contains('.')) {
          final mime = (response.headers['content-type'] ?? '').toLowerCase();
          if (mime.contains('application/pdf')) name += '.pdf';
          if (mime.contains('image/png')) name += '.png';
          if (mime.contains('image/jpeg')) name += '.jpg';
        }
      }
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _SimtasFilePreviewPage(
            namaFile: name,
            bytes: bytes,
            externalUrl: url,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuka preview: $e')),
      );
    }
  }

  bool _openingPreview = false;

  Future<void> _bukaFileHasil() async {
    if (_openingPreview) return;
    final path = _fileHasilPath?.trim() ?? '';
    final oldUrl = _fileHasilUrl?.trim() ?? '';
    final name = _detailTugas?.fileHasil ?? _namaFileDipilih ?? 'Dokumen';

    setState(() => _openingPreview = true);
    try {
      Uint8List data;
      String? externalUrl;
      if (path.isNotEmpty) {
        var cleanPath = path.replaceFirst(RegExp(r'^/+'), '');
        if (cleanPath.startsWith('file-tugas/')) {
          cleanPath = cleanPath.substring('file-tugas/'.length);
        }
        final uid = _auth.currentUser?.uid;
        if (uid == null || !cleanPath.startsWith('$uid/')) {
          throw StateError('File bukan milik akun yang sedang login.');
        }
        // Di Flutter Web PDF dirender langsung lewat viewer browser di dalam
        // aplikasi; tidak perlu mengunduh bytes untuk SfPdfViewer.memory.
        externalUrl = await _storageService.buatLinkSementara(cleanPath);
        if (kIsWeb && name.toLowerCase().endsWith('.pdf')) {
          data = Uint8List(0);
        } else {
          data = await Supabase.instance.client.storage
              .from('file-tugas')
              .download(cleanPath);
        }
      } else if (oldUrl.isNotEmpty) {
        externalUrl = oldUrl;
        if (kIsWeb && name.toLowerCase().endsWith('.pdf')) {
          data = Uint8List(0);
        } else {
          final response = await http.get(Uri.parse(oldUrl));
          if (response.statusCode != 200) {
            throw StateError('Unduhan gagal (HTTP ${response.statusCode}).');
          }
          data = response.bodyBytes;
        }
      } else {
        throw StateError('File hasil pekerjaan belum tersedia.');
      }

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _SimtasFilePreviewPage(
            namaFile: name,
            bytes: data,
            externalUrl: externalUrl,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal membuka preview: $e')));
    } finally {
      if (mounted) setState(() => _openingPreview = false);
    }
  }

  bool _isPreviewableFile(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.pdf') ||
        lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg');
  }

  Future<void> _bukaFileRevisi() async {
    try {
      final path = (_assignmentData?['file_revisi_path'] ?? '').toString();
      final oldUrl = (_assignmentData?['file_revisi_url'] ?? '').toString();
      final name = (_assignmentData?['file_revisi_nama'] ?? 'Lampiran revisi')
          .toString();
      String url;
      if (path.isNotEmpty) {
        final user = _auth.currentUser;
        if (user == null) {
          throw StateError(
            'Sesi login tidak ditemukan. Silakan login kembali.',
          );
        }
        final token = await user.getIdToken();
        if (token == null || token.isEmpty) {
          throw StateError('Token Firebase tidak tersedia.');
        }
        final response = await http.post(
          Uri.parse(
            'https://uxdloenucntsmcviskfo.supabase.co/functions/v1/get-assignment-file-url',
          ),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'assignmentId': widget.penugasanId,
            'kind': 'revisi',
          }),
        );
        final decoded = jsonDecode(response.body);
        if (decoded is! Map) {
          throw StateError('Respons backend tidak valid.');
        }
        final result = Map<String, dynamic>.from(decoded);
        if (response.statusCode != 200) {
          throw StateError(
            'Supabase HTTP ${response.statusCode}: '
            '${result['error'] ?? result['message'] ?? 'Gagal mengambil URL'}',
          );
        }
        url = (result['url'] ?? '').toString();
        if (url.isEmpty) {
          throw StateError('Backend tidak mengirim URL lampiran revisi.');
        }
      } else if (oldUrl.isNotEmpty) {
        url = oldUrl;
      } else {
        throw StateError('Lampiran revisi tidak tersedia.');
      }
      Uint8List bytes = Uint8List(0);
      if (!kIsWeb || !name.toLowerCase().endsWith('.pdf')) {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode != 200) {
          throw StateError(
            'Gagal mengambil lampiran (HTTP ${response.statusCode}).',
          );
        }
        bytes = response.bodyBytes;
      }
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => _SimtasFilePreviewPage(
            namaFile: name,
            bytes: bytes,
            externalUrl: url,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuka lampiran revisi: $e')),
      );
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

  Future<void> _bukaFormKendala({bool lanjutan = false}) async {
    final userAwal = _auth.currentUser;
    if (userAwal == null || _detailTugas == null) return;

    // Hanya edit laporan yang sudah ada ketika penugasan sedang terkendala.
    final sedangEdit = _statusTerpilih.toLowerCase() == 'terkendala';
    QueryDocumentSnapshot<Map<String, dynamic>>? laporanLama;
    try {
      if (sedangEdit) {
        final snapshot = await _firestore
            .collection('laporan_kendala')
            .where('penugasan_id', isEqualTo: widget.penugasanId)
            .where('pelapor_id', isEqualTo: userAwal.uid)
            .get();
        if (snapshot.docs.isNotEmpty) {
          // Jika pernah ada laporan duplikat, gunakan yang paling baru.
          final daftar = snapshot.docs.toList();
          daftar.sort((a, b) {
            final waktuA = a.data()['created_at'] as Timestamp?;
            final waktuB = b.data()['created_at'] as Timestamp?;
            return (waktuB?.millisecondsSinceEpoch ?? 0).compareTo(
              waktuA?.millisecondsSinceEpoch ?? 0,
            );
          });
          final aktifId = (_assignmentData?['kendala_aktif_id'] ?? '').toString();
          final matches = daftar.where((d) => d.id == aktifId);
          if (matches.isEmpty) throw StateError('Laporan aktif tidak ditemukan.');
          laporanLama = matches.first;
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Laporan kendala lama tidak ditemukan.'),
            ),
          );
          return;
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat laporan kendala: $e')),
      );
      return;
    }

    if (!mounted) return;
    final dataLama = laporanLama?.data();
    final deskripsi = TextEditingController(
      text: (dataLama?['deskripsi'] ?? _detailTugas!.deskripsiKendala ?? '')
          .toString(),
    );
    final dampak = TextEditingController(
      text: (dataLama?['dampak'] ?? _detailTugas!.dampakKendala ?? '')
          .toString(),
    );
    final jenisAwal =
        (dataLama?['jenis_kendala'] ?? _detailTugas!.jenisKendala ?? 'Internal')
            .toString()
            .toLowerCase();
    String jenis = jenisAwal == 'eksternal' ? 'Eksternal' : 'Internal';
    String? lampiranKendala = _detailTugas!.fileKendala;
    String? lampiranKendalaUrl = dataLama?['bukti_url']?.toString();
    String? lampiranKendalaPath = dataLama?['bukti_path']?.toString();
    if (lampiranKendalaPath != null &&
        lampiranKendalaPath.isNotEmpty &&
        (lampiranKendala == null || lampiranKendala.isEmpty)) {
      lampiranKendala = lampiranKendalaPath.split('/').last;
    }

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
                              if (_uploading) return;

                              final file = await FilePicker.pickFile(
                                type: FileType.custom,

                                allowedExtensions: const [
                                  'pdf',

                                  'jpg',

                                  'jpeg',

                                  'png',

                                  'docx',
                                ],
                              );

                              if (file == null) {
                                return;
                              }

                              try {
                                final user = _auth.currentUser;

                                if (user == null) {
                                  throw Exception(
                                    'Sesi login tidak ditemukan.',
                                  );
                                }

                                final bytes = await file.readAsBytes();

                                final uploaded = await _storageService
                                    .uploadHasilTugas(
                                      tugasId: 'kendala_${widget.penugasanId}',

                                      namaFile: file.name,

                                      bytes: bytes,

                                      contentType: _contentType(file.extension),
                                    );

                                if (!modalContext.mounted) {
                                  return;
                                }

                                setModalState(() {
                                  lampiranKendala = file.name;

                                  lampiranKendalaUrl = null;

                                  lampiranKendalaPath = uploaded.path;
                                });
                              } catch (e) {
                                if (!modalContext.mounted) {
                                  return;
                                }

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

                                          lampiranKendalaPath = null;
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

                                if (user == null) {
                                  return;
                                }

                                try {
                                  final laporanRef =
                                      laporanLama?.reference ??
                                      _firestore
                                          .collection('laporan_kendala')
                                          .doc();

                                  // Cegah status yang berubah di perangkat lain tertimpa saat menyimpan.
                                  await _firestore.runTransaction((
                                    transaction,
                                  ) async {
                                    final penugasanRef = _firestore
                                        .collection('penugasan')
                                        .doc(widget.penugasanId);
                                    final penugasanSnapshot = await transaction
                                        .get(penugasanRef);
                                    if (!penugasanSnapshot.exists) {
                                      throw StateError(
                                        'Penugasan tidak ditemukan.',
                                      );
                                    }
                                    final dataPenugasan = penugasanSnapshot
                                        .data()!;
                                    if (dataPenugasan['staff_id'] != user.uid) {
                                      throw StateError(
                                        'Penugasan bukan milik akun ini.',
                                      );
                                    }
                                    final statusSaatIni =
                                        (dataPenugasan['status'] ?? '')
                                            .toString();
                                    if (sedangEdit &&
                                        statusSaatIni != 'terkendala') {
                                      throw StateError(
                                        'Status tugas sudah berubah. Muat ulang halaman.',
                                      );
                                    }
                                    if (!sedangEdit &&
                                        statusSaatIni != 'berlangsung') {
                                      throw StateError(
                                        'Laporan baru hanya dapat dibuat saat berlangsung.',
                                      );
                                    }

                                    final dataLaporan = <String, dynamic>{
                                      'jenis_kendala': jenis.toLowerCase(),
                                      'deskripsi': deskripsi.text.trim(),
                                      'dampak': dampak.text.trim(),
                                      'bukti_url': lampiranKendalaUrl ?? '',
                                      'bukti_path': lampiranKendalaPath ?? '',
                                      'bukti_provider':
                                          (lampiranKendalaPath ?? '').isNotEmpty
                                          ? 'supabase'
                                          : '',
                                      'updated_at':
                                          FieldValue.serverTimestamp(),
                                    };

                                    if (sedangEdit) {
                                      final lama = await transaction.get(laporanRef);
                                      final statusLaporanLama = (lama.data()?['status'] ?? '').toString();
                                      final statusDiharapkan = lanjutan
                                          ? 'menunggu_konfirmasi'
                                          : 'menunggu_review';
                                      if (!lama.exists || statusLaporanLama != statusDiharapkan) {
                                        throw StateError('Laporan hanya dapat diedit saat menunggu review.');
                                      }
                                      if (lanjutan) {
                                        final previous = lama.data()!;
                                        final historyRef = laporanRef.collection('riwayat').doc();
                                        transaction.set(historyRef, {
                                          'laporan_id': laporanRef.id,
                                          'pelapor_id': user.uid,
                                          'deskripsi_sebelumnya': previous['deskripsi'] ?? '',
                                          'dampak_sebelumnya': previous['dampak'] ?? '',
                                          'solusi_sebelumnya': previous['solusi'] ?? '',
                                          'solusi_file_path': previous['solusi_file_path'] ?? '',
                                          'bukti_path': previous['bukti_path'] ?? '',
                                          'feedback': deskripsi.text.trim(),
                                          'created_at': FieldValue.serverTimestamp(),
                                        });
                                      }
                                      transaction.update(
                                        laporanRef,
                                        {...dataLaporan, if (lanjutan) 'status': 'menunggu_review', if (lanjutan) 'konfirmasi_staff_at': FieldValue.serverTimestamp()},
                                      );
                                    } else {
                                      transaction.set(laporanRef, {
                                        ...dataLaporan,
                                        'tugas_id': _detailTugas!.idTugas,
                                        'penugasan_id': widget.penugasanId,
                                        'pelapor_id': user.uid,
                                        'prioritas': 'sedang',
                                        'status': 'menunggu_review',
                                        'solusi': '',
                                        'ditangani_oleh': '',
                                        'tanggal_laporan':
                                            FieldValue.serverTimestamp(),
                                        'created_at':
                                            FieldValue.serverTimestamp(),
                                      });
                                      transaction.update(penugasanRef, {
                                        'kendala_aktif_id': laporanRef.id,
                                        'status': 'terkendala',
                                        'updated_at':
                                            FieldValue.serverTimestamp(),
                                      });
                                    }
                                  });

                                  if (!modalContext.mounted) {
                                    return;
                                  }

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
                                      SnackBar(
                                        content: Text(
                                          sedangEdit
                                              ? lanjutan ? 'Laporan lanjutan dikirim kepada Atasan' : 'Laporan kendala berhasil diperbarui'
                                              : 'Kendala berhasil dilaporkan kepada atasan',
                                        ),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (!modalContext.mounted) {
                                    return;
                                  }

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

                              child: Text(
                                sedangEdit
                                    ? "SIMPAN PERUBAHAN LAPORAN"
                                    : "KIRIM LAPORAN KENDALA",

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
    if (!_loading && _detailTugas == null) {
      return Scaffold(
        backgroundColor: kBgLight,
        appBar: AppBar(),
        body: Center(child: Text(_loadError ?? 'Data tugas tidak ditemukan.')),
      );
    }
    if (_loading || _detailTugas == null) {
      return const Scaffold(
        backgroundColor: kBgLight,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final tugas = _detailTugas!;
    final bool isRevisi = _statusTerpilih == "Revisi";

    debugPrint('STATUS UI: $_statusTerpilih');
    debugPrint('STATUS FIRESTORE: ${_assignmentData?['status']}');
    debugPrint('IS REVISI: $isRevisi');

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
                        if (tugas.latitude != null && tugas.longitude != null) ...[
                          const SizedBox(height: 10),
                          SizedBox(height: 190, child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: FlutterMap(
                              options: MapOptions(initialCenter: LatLng(tugas.latitude!, tugas.longitude!), initialZoom: 15),
                              children: [
                                TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  userAgentPackageName: 'app_penugasan_kominfo'),
                                MarkerLayer(markers: [Marker(point: LatLng(tugas.latitude!, tugas.longitude!),
                                  width: 40, height: 40, child: const Icon(Icons.location_pin, color: Colors.red, size: 38))]),
                              ],
                            ),
                          )),
                        ],
                        TextButton.icon(onPressed: _bukaNavigasi, icon: const Icon(Icons.navigation), label: const Text('Petunjuk Arah (Google Maps)')),
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
                            if ((_assignmentData?['file_revisi_url'] ?? '')
                                    .toString()
                                    .isNotEmpty ||
                                (_assignmentData?['file_revisi_path'] ?? '')
                                    .toString()
                                    .isNotEmpty)
                              TextButton.icon(
                                onPressed: _bukaFileRevisi,
                                icon: const Icon(Icons.attach_file),
                                label: Text(
                                  (_assignmentData?['file_revisi_nama'] ??
                                          'File pendukung revisi')
                                      .toString(),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],

                    SizedBox(height: 22 * scale),

                    _riwayatPengumpulan(),
                    _semuaRiwayatKendala(),
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
                            enabled: !_uploading,
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
                            onTap: () async {
                              if (_uploading) return;
                              final file = await FilePicker.pickFile(
                                type: FileType.custom,
                                allowedExtensions: const [
                                  'pdf',
                                  'jpg',
                                  'jpeg',
                                  'png',
                                  'docx',
                                ],
                              );

                              if (file == null) {
                                return;
                              }

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
                                _uploading
                                    ? '${_submissionStage.toUpperCase()}...'
                                    : isRevisi
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
                          _solusiKendala(),
                          SizedBox(height: 12 * scale),
                        ],
                        if (_statusTerpilih == 'Dihentikan') ...[
                          const Text('Penugasan dihentikan oleh Atasan. Pengumpulan hasil dinonaktifkan.'),
                          Text('Alasan: ${_assignmentData?['alasan_penghentian'] ?? '-'}'),
                        ],

                        // --- KONDISI 4: MENUNGGU DISETUJUI / SELESAI ---
                        if (_statusTerpilih == "Dikumpulkan" ||
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
                            InkWell(
                              onTap:
                                  (_fileHasilUrl == null &&
                                      _fileHasilPath == null)
                                  ? null
                                  : _bukaFileHasil,
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.attach_file,
                                    size: 16,
                                    color: kBiruTua,
                                  ),
                                  SizedBox(width: 4 * scale),
                                  Expanded(
                                    child: Text(
                                      _namaFileDipilih!,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12 * scale,
                                        color: kBiruTua,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
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

      case "Dikumpulkan":
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

    if (!jam) {
      return tgl;
    }

    final j = dt.hour.toString().padLeft(2, '0');

    final m = dt.minute.toString().padLeft(2, '0');

    return "$tgl - $j:$m";
  }
}

class HeaderCurveClipper extends CustomClipper<ui.Path> {
  @override
  ui.Path getClip(Size size) {
    final path = ui.Path();

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
  bool shouldReclip(CustomClipper<ui.Path> oldClipper) {
    return false;
  }
}

/// Halaman tambahan; tidak mengubah widget desain Detail Tugas.
class _SimtasFilePreviewPage extends StatefulWidget {
  final String namaFile;
  final Uint8List bytes;
  final String? externalUrl;

  const _SimtasFilePreviewPage({
    required this.namaFile,
    required this.bytes,
    this.externalUrl,
  });

  @override
  State<_SimtasFilePreviewPage> createState() => _SimtasFilePreviewPageState();
}

class _SimtasFilePreviewPageState extends State<_SimtasFilePreviewPage> {
  String? _pdfError;
  bool _pdfLoaded = false;

  bool get _pdfHeaderValid {
    final bytes = widget.bytes;
    if (bytes.length < 5) return false;
    // Toleransi BOM/whitespace sebelum header PDF.
    final prefix = String.fromCharCodes(bytes.take(32));
    return prefix.contains('%PDF-');
  }

  Future<void> _openExternal() async {
    final url = widget.externalUrl;
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link file tidak tersedia.')),
      );
      return;
    }
    try {
      final success = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!success) throw StateError('File tidak dapat dibuka.');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal membuka file: $e')));
    }
  }

  Widget _errorView(String message) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.picture_as_pdf_outlined,
              size: 64,
              color: kBiruSedang,
            ),
            const SizedBox(height: 16),
            const Text(
              'Preview PDF belum dapat ditampilkan',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            if (widget.externalUrl != null)
              ElevatedButton.icon(
                onPressed: _openExternal,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Buka di browser'),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lower = widget.namaFile.toLowerCase();
    final isPdf = lower.endsWith('.pdf');
    final isImage =
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png');

    return Scaffold(
      backgroundColor: kBgLight,
      appBar: AppBar(
        backgroundColor: kBiruTua,
        foregroundColor: Colors.white,
        title: Text(
          widget.namaFile,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (widget.externalUrl != null)
            IconButton(
              tooltip: 'Buka dengan aplikasi lain',
              icon: const Icon(Icons.open_in_new),
              onPressed: _openExternal,
            ),
        ],
      ),
      body: isPdf && kIsWeb && widget.externalUrl != null
          ? SimtasPdfWebView(url: widget.externalUrl!)
          : isPdf
          ? !_pdfHeaderValid
                ? _errorView(
                    'Data yang diterima bukan PDF valid. '
                    'Periksa file asli di Supabase Storage.',
                  )
                : _pdfError != null
                ? _errorView(_pdfError!)
                : Stack(
                    children: [
                      SfPdfViewer.memory(
                        widget.bytes,
                        onDocumentLoaded: (_) {
                          if (mounted) setState(() => _pdfLoaded = true);
                        },
                        onDocumentLoadFailed: (details) {
                          if (mounted) {
                            setState(() {
                              _pdfError =
                                  '${details.error}: '
                                  '${details.description}';
                            });
                          }
                        },
                      ),
                      if (!_pdfLoaded)
                        const Center(child: CircularProgressIndicator()),
                    ],
                  )
          : isImage
          ? Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 5,
                child: Image.memory(
                  widget.bytes,
                  fit: BoxFit.contain,
                  errorBuilder: (_, error, __) =>
                      _errorView('Gambar tidak dapat ditampilkan: $error'),
                ),
              ),
            )
          : _errorView('Format ini belum mendukung preview internal.'),
    );
  }
}
