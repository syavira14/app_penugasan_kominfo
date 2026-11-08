import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../services/supabase_storage_service.dart';
import '../widgets/simtas_file_preview_page.dart';
import '../services/penugasan_workflow.dart';
import '../pages/admin/riwayat_tugas_staff.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../pages/admin/admin_sidebar.dart';
import '../widgets/admin_header.dart';
import 'location_picker_page.dart';
import 'tugas_staff_data.dart';

class DetailTugasAdminPage extends StatefulWidget {
  final String? tugasId;
  final bool modeLihat;
  const DetailTugasAdminPage({super.key, this.tugasId, this.modeLihat = false});
  @override
  State<DetailTugasAdminPage> createState() => _DetailTugasAdminPageState();
}

class _DetailTugasAdminPageState extends State<DetailTugasAdminPage> {
  static const Color biruTua = AppPalette.navy;
  static const Color biruSedang = AppPalette.blue;
  static const Color cyan = AppPalette.sky;
  static const Color latarAbu = AppPalette.background;
  static const int _sidebarIndex = 2; // posisi menu Kelola Tugas di sidebar
  static const Color abuBorder = Color(0xFFE1E5F0);
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SupabaseStorageService _storage = SupabaseStorageService();
  final _formKey = GlobalKey<FormState>();
  final _judulController = TextEditingController();
  final _deskripsiController = TextEditingController();
  final _tempatController = TextEditingController();
  final _staffSearchController = TextEditingController();

  DateTime? _tanggalMulai;
  TimeOfDay? _jamMulai;
  DateTime? _tanggalSelesai;
  TimeOfDay? _jamSelesai;
  double? _latitude;
  double? _longitude;
  String _prioritas = 'sedang';

  List<Map<String, dynamic>> _daftarStaff = [];
  final Set<String> _stafDipilih = {};
  final Map<String, String> _namaStaff = {};

  bool _loading = true;
  bool _saving = false;

  final Set<String> _reviewing = {};

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _assignmentSubscription;

  bool _sedangMengambilLokasi = false;

  Map<String, dynamic>? _tugasData;

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _penugasan = [];

  @override
  void initState() {
    super.initState();

    _loadPage();
  }

  @override
  void dispose() {
    _assignmentSubscription?.cancel();

    _judulController.dispose();

    _deskripsiController.dispose();

    _tempatController.dispose();

    _staffSearchController.dispose();

    super.dispose();
  }

  Future<void> _loadPage() async {
    try {
      await _loadStaff();

      if (widget.tugasId != null) {
        await _loadTugas();

        if (!mounted) return;

        _assignmentSubscription = _firestore
            .collection('penugasan')
            .where('tugas_id', isEqualTo: widget.tugasId)
            .snapshots()
            .listen(
              (snapshot) {
                if (!mounted) return;

                setState(() {
                  _penugasan = snapshot.docs;

                  if (widget.modeLihat) {
                    _stafDipilih
                      ..clear()
                      ..addAll(
                        snapshot.docs
                            .map(
                              (doc) =>
                                  (doc.data()['staff_id'] ?? '').toString(),
                            )
                            .where((id) => id.isNotEmpty),
                      );
                  }
                });
              },

              onError: (Object error) =>
                  _message('Gagal memperbarui status: $error', error: true),
            );
      }
    } catch (e) {
      if (mounted) {
        _message('Gagal memuat data: $e', error: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadStaff() async {
    // Role lama menggunakan "Staff" dan sebagian akun tidak memiliki

    // status_akun. Nama tetap dimuat untuk staf lama yang sudah nonaktif.

    final snapshot = await _firestore.collection('users').get();

    _namaStaff.clear();

    _daftarStaff = [];

    for (final doc in snapshot.docs) {
      final staff = staffFromDocument(doc.id, doc.data());

      final nama = staffDisplayName(staff);

      _namaStaff[doc.id] = nama;

      _namaStaff[staff['id'].toString()] = nama;

      if (isSelectableStaff(staff)) {
        _daftarStaff.add(staff);
      }
    }

    _daftarStaff.sort(
      (a, b) =>
          (a['nama'] ?? '').toString().compareTo((b['nama'] ?? '').toString()),
    );
  }

  Future<void> _loadTugas() async {
    final doc = await _firestore.collection('tugas').doc(widget.tugasId).get();

    if (!doc.exists) {
      throw Exception('Data tugas tidak ditemukan.');
    }

    final data = doc.data()!;

    _tugasData = data;

    _judulController.text = (data['judul'] ?? '').toString();

    _deskripsiController.text = (data['deskripsi'] ?? '').toString();

    _tempatController.text = (data['tempat_tugas'] ?? '').toString();

    _latitude = (data['latitude'] as num?)?.toDouble();

    _longitude = (data['longitude'] as num?)?.toDouble();

    _prioritas = (data['prioritas'] ?? 'sedang').toString().toLowerCase();

    final start = _asDate(data['tanggal_mulai_tugas']);

    final end = _asDate(data['tanggal_selesai_tugas']);

    _tanggalMulai = start == null
        ? null
        : DateTime(start.year, start.month, start.day);

    _jamMulai = start == null
        ? null
        : TimeOfDay(hour: start.hour, minute: start.minute);

    _tanggalSelesai = end == null
        ? null
        : DateTime(end.year, end.month, end.day);

    _jamSelesai = end == null
        ? null
        : TimeOfDay(hour: end.hour, minute: end.minute);

    final assignmentSnapshot = await _firestore
        .collection('penugasan')
        .where('tugas_id', isEqualTo: widget.tugasId)
        .get();

    _penugasan = assignmentSnapshot.docs;

    _stafDipilih.clear();

    for (final assignment in assignmentSnapshot.docs) {
      final staffId = (assignment.data()['staff_id'] ?? '').toString();

      if (staffId.isNotEmpty) {
        _stafDipilih.add(staffId);

        final savedName = (assignment.data()['staff_nama'] ?? '')
            .toString()
            .trim();

        if (!_namaStaff.containsKey(staffId) && savedName.isNotEmpty) {
          _namaStaff[staffId] = savedName;
        }
      }
    }
  }

  DateTime? _asDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    return null;
  }

  Future<void> _pilihTanggalMulai() async {
    final result = await showDatePicker(
      context: context,

      initialDate: _tanggalMulai ?? DateTime.now(),

      firstDate: DateTime(1900),

      lastDate: DateTime(2100, 12, 31),
    );

    if (result != null) {
      setState(() {
        _tanggalMulai = result;
      });
    }
  }

  Future<void> _pilihJamMulai() async {
    final result = await showTimePicker(
      context: context,

      initialTime: _jamMulai ?? TimeOfDay.now(),
    );

    if (result != null) {
      setState(() {
        _jamMulai = result;
      });
    }
  }

  Future<void> _pilihTanggalSelesai() async {
    final firstDate = _tanggalMulai ?? DateUtils.dateOnly(DateTime.now());

    final previousDate = _tanggalSelesai ?? firstDate;

    final result = await showDatePicker(
      context: context,

      initialDate: previousDate.isBefore(firstDate) ? firstDate : previousDate,

      firstDate: firstDate,

      lastDate: DateTime(2100, 12, 31),
    );

    if (result != null) {
      setState(() {
        _tanggalSelesai = result;
      });
    }
  }

  Future<void> _pilihJamSelesai() async {
    final result = await showTimePicker(
      context: context,

      initialTime: _jamSelesai ?? TimeOfDay.now(),
    );

    if (result != null) {
      setState(() {
        _jamSelesai = result;
      });
    }
  }

  Future<void> _ambilLokasiSaatIni() async {
    setState(() {
      _sedangMengambilLokasi = true;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        _message('Layanan lokasi (GPS) sedang nonaktif.', error: true);

        return;
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _message('Izin lokasi ditolak.', error: true);

        return;
      }

      if (permission == LocationPermission.deniedForever) {
        _message('Izin lokasi ditolak permanen.', error: true);

        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      setState(() {
        _latitude = position.latitude;

        _longitude = position.longitude;

        if (_tempatController.text.trim().isEmpty) {
          _tempatController.text =
              'Lat: ${position.latitude.toStringAsFixed(6)}, '
              'Lng: ${position.longitude.toStringAsFixed(6)}';
        }
      });

      _message('Lokasi berhasil diambil');
    } catch (e) {
      _message('Gagal mengambil lokasi.', error: true);
    } finally {
      if (mounted) {
        setState(() {
          _sedangMengambilLokasi = false;
        });
      }
    }
  }

  Future<void> _pilihLokasiDariPeta() async {
    final hasil = await Navigator.push<LocationPickResult>(
      context,

      MaterialPageRoute(
        builder: (_) => LocationPickerPage(
          initialTempat: _tempatController.text.trim(),

          initialLatitude: _latitude,

          initialLongitude: _longitude,
        ),
      ),
    );

    if (hasil == null) {
      return;
    }

    setState(() {
      _tempatController.text = hasil.tempat;

      _latitude = hasil.latitude;

      _longitude = hasil.longitude;
    });
  }

  Future<void> _bukaMaps() async {
    if (_latitude == null || _longitude == null) {
      return;
    }

    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=$_latitude,$_longitude'
      '&travelmode=driving',
    );

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  DateTime _gabungkanTanggalDanJam(DateTime tanggal, TimeOfDay jam) {
    return DateTime(
      tanggal.year,

      tanggal.month,

      tanggal.day,

      jam.hour,

      jam.minute,
    );
  }

  Future<void> _simpanTugas() async {
    if (widget.modeLihat) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_tanggalMulai == null || _jamMulai == null) {
      _message('Tanggal dan jam mulai wajib dipilih.', error: true);

      return;
    }

    if (_tanggalSelesai == null || _jamSelesai == null) {
      _message('Tanggal dan jam selesai wajib dipilih.', error: true);

      return;
    }

    if (_stafDipilih.isEmpty) {
      _message('Pilih minimal 1 staf.', error: true);

      return;
    }

    final mulai = _gabungkanTanggalDanJam(_tanggalMulai!, _jamMulai!);

    final selesai = _gabungkanTanggalDanJam(_tanggalSelesai!, _jamSelesai!);

    if (!selesai.isAfter(mulai)) {
      _message('Waktu selesai harus setelah waktu mulai.', error: true);

      return;
    }

    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      _message('Sesi admin tidak ditemukan.', error: true);

      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final tugasRef = widget.tugasId == null
          ? _firestore.collection('tugas').doc()
          : _firestore.collection('tugas').doc(widget.tugasId);

      final data = <String, dynamic>{
        'judul': _judulController.text.trim(),

        'deskripsi': _deskripsiController.text.trim(),

        'dibuat_oleh': widget.tugasId == null
            ? currentUser.uid
            : (_tugasData?['dibuat_oleh'] ?? currentUser.uid),

        'tanggal_mulai_tugas': Timestamp.fromDate(mulai),

        'tanggal_selesai_tugas': Timestamp.fromDate(selesai),

        'tempat_tugas': _tempatController.text.trim(),

        'latitude': _latitude,

        'longitude': _longitude,

        'prioritas': _prioritas.toLowerCase(),
        'staff_ids': _stafDipilih.toList()..sort(),

        'updated_at': FieldValue.serverTimestamp(),
      };

      if (widget.tugasId == null) {
        data['tanggal_tugas_diberikan'] = FieldValue.serverTimestamp();

        data['created_at'] = FieldValue.serverTimestamp();
      }

      final oldAssignments = await _firestore
          .collection('penugasan')
          .where('tugas_id', isEqualTo: tugasRef.id)
          .get();

      final oldByStaff =
          <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};

      for (final doc in oldAssignments.docs) {
        final staffId = (doc.data()['staff_id'] ?? '').toString();

        if (staffId.isNotEmpty) {
          oldByStaff[staffId] = doc;
        }
      }

      final batch = _firestore.batch();

      batch.set(tugasRef, data, SetOptions(merge: true));

      for (final staffId in _stafDipilih) {
        final existing = oldByStaff[staffId];

        final ref =
            existing?.reference ?? _firestore.collection('penugasan').doc();

        if (existing == null) {
          batch.set(ref, {
            'tugas_id': tugasRef.id,

            'staff_id': staffId,

            'staff_nama': _staffName(staffId),

            'status': 'pending',

            'file_hasil_url': '',

            'file_hasil_nama': '',

            'catatan_staff': '',

            'catatan_revisi': '',

            'created_at': FieldValue.serverTimestamp(),

            'updated_at': FieldValue.serverTimestamp(),
          });
        } else {
          batch.update(ref, {
            'staff_nama': _staffName(staffId),

            'updated_at': FieldValue.serverTimestamp(),
          });
        }
      }

      for (final old in oldAssignments.docs) {
        final staffId = (old.data()['staff_id'] ?? '').toString();

        if (!_stafDipilih.contains(staffId)) {
          batch.delete(old.reference);
        }
      }

      await batch.commit();

      if (!mounted) return;

      _message(
        widget.tugasId == null
            ? 'Tugas berhasil ditambahkan.'
            : 'Tugas berhasil diperbarui.',
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        _message('Gagal menyimpan tugas: $e', error: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _bukaFile(String url) async {
    try {
      if (!await launchUrl(
        Uri.parse(url),

        mode: LaunchMode.externalApplication,
      )) {
        throw StateError('File tidak dapat dibuka.');
      }
    } catch (e) {
      _message('Gagal membuka file: $e', error: true);
    }
  }

  // Signed URL diberikan oleh backend setelah memverifikasi role admin,

  // pemilik tugas, dan ID penugasan. Tidak memakai service_role di Flutter.

  /// Meminta signed URL dari backend gratis Supabase Edge Functions.
  /// Backend memverifikasi Firebase ID token dan hak akses penugasan.
  Future<String> _ambilUrlFileDariEdgeFunction(
    String assignmentId, {
    required String kind,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Silakan login kembali.');
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
      body: jsonEncode({'assignmentId': assignmentId, 'kind': kind}),
    );

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw StateError('Respons backend tidak valid.');
    }
    final result = Map<String, dynamic>.from(decoded);
    if (response.statusCode != 200) {
      throw StateError(
        (result['error'] ?? result['message'] ?? 'HTTP ${response.statusCode}')
            .toString(),
      );
    }
    final url = (result['url'] ?? '').toString();
    if (url.isEmpty) {
      throw StateError('Backend tidak mengirim URL file.');
    }
    return url;
  }

  Future<void> _previewHasilStaff(String id, Map<String, dynamic> data) async {
    if (_reviewing.contains(id)) return;

    setState(() => _reviewing.add(id));

    try {
      final path = (data['file_hasil_path'] ?? '').toString().trim();

      final oldUrl = (data['file_hasil_url'] ?? '').toString().trim();

      final name = (data['file_hasil_nama'] ?? 'Dokumen').toString();

      String url;

      if (path.isNotEmpty) {
        url = await _ambilUrlFileDariEdgeFunction(id, kind: 'hasil');
      } else if (oldUrl.isNotEmpty) {
        url = oldUrl;
      } else {
        throw StateError('File hasil pekerjaan belum tersedia.');
      }

      Uint8List bytes = Uint8List(0);

      if (!kIsWeb || !name.toLowerCase().endsWith('.pdf')) {
        final response = await http.get(Uri.parse(url));

        if (response.statusCode != 200) {
          throw StateError('Gagal mengambil file: HTTP ${response.statusCode}');
        }

        bytes = response.bodyBytes;
      }

      if (!mounted) return;

      await Navigator.push(
        context,

        MaterialPageRoute<void>(
          builder: (_) => SimtasFilePreviewPage(
            namaFile: name,

            bytes: bytes,

            externalUrl: url,
          ),
        ),
      );
    } catch (e) {
      _message('Gagal membuka hasil pekerjaan: $e', error: true);
    } finally {
      if (mounted) setState(() => _reviewing.remove(id));
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

      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _editCatatanRevisi(String id, String awal) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _RevisionDialog(catatanAwal: awal, isEdit: true),
    );
    if (result == null || !mounted) return;
    final catatan = (result['catatan'] ?? '').toString().trim();
    if (catatan.isEmpty) return;
    final selected = result['file'] as PlatformFile?;
    try {
      // Upload sebelum transaksi: transaksi Firestore tidak boleh melakukan I/O.
      String? newPath;
      String? newName;
      if (selected != null) {
        final uploaded = await _storage.uploadHasilTugas(
          tugasId: 'revisi_$id',
          namaFile: selected.name,
          bytes: await selected.readAsBytes(),
          contentType: _contentType(selected.extension),
        );
        newPath = uploaded.path;
        newName = uploaded.namaFile;
      }
      await _firestore.runTransaction((tx) async {
        final ref = _firestore.collection('penugasan').doc(id);
        final snap = await tx.get(ref);
        if (snap.data()?['status'] != 'revisi') {
          throw StateError('Revisi sudah ditanggapi Staff atau tidak aktif.');
        }
        final data = snap.data()!;
        final revisiId = (data['revisi_aktif_id'] ?? '').toString();
        final updates = <String, dynamic>{
          'catatan_revisi': catatan,
          'updated_at': FieldValue.serverTimestamp(),
          if (newPath != null) 'file_revisi_path': newPath,
          if (newPath != null) 'file_revisi_url': '',
          if (newPath != null) 'file_revisi_provider': 'supabase',
          if (newName != null) 'file_revisi_nama': newName,
          if (newPath != null) 'file_revisi_uploaded_by': FirebaseAuth.instance.currentUser!.uid,
        };
        tx.update(ref, updates);
        if (revisiId.isNotEmpty) {
          tx.update(ref.collection('riwayat_revisi').doc(revisiId), {
            'catatan_atasan': catatan,
            if (newPath != null) 'file_revisi_path': newPath,
            if (newName != null) 'file_revisi_nama': newName,
            'updated_at': FieldValue.serverTimestamp(),
          });
        }
      });
      _message('Revisi aktif berhasil diperbarui.');
    } catch (e) {
      _message('Gagal mengedit revisi: $e', error: true);
    }
  }

  Future<void> _hentikanPenugasan(String id) async {
    final controller = TextEditingController();
    PlatformFile? file;
    final result = await showDialog<Map<String, dynamic>>(context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, update) => AlertDialog(
        title: const Text('Hentikan Penugasan'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: controller, maxLines: 3, decoration: const InputDecoration(labelText: 'Alasan penghentian (wajib)')),
          OutlinedButton.icon(onPressed: () async {
            final picked = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: const ['pdf','png','jpg','jpeg','docx']);
            if (picked != null) update(() => file = picked);
          }, icon: const Icon(Icons.attach_file), label: Text(file?.name ?? 'Bukti (opsional)')),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(onPressed: () { if (controller.text.trim().isNotEmpty) Navigator.pop(ctx, {'alasan': controller.text.trim(), 'file': file}); }, child: const Text('Hentikan'))],
      )));
    controller.dispose();
    if (result == null) return;
    try {
      String path = '';
      final picked = result['file'] as PlatformFile?;
      if (picked != null) {
        final uploaded = await _storage.uploadHasilTugas(tugasId: 'penghentian_$id', namaFile: picked.name,
          bytes: await picked.readAsBytes(), contentType: _contentType(picked.extension));
        path = uploaded.path;
      }
      await _firestore.runTransaction((tx) async {
        final ref = _firestore.collection('penugasan').doc(id);
        final snap = await tx.get(ref);
        final status = (snap.data()?['status'] ?? '').toString();
        if (status == 'dihentikan' || status == 'disetujui') throw StateError('Penugasan tidak dapat dihentikan.');
        tx.update(ref, {'status': 'dihentikan', 'status_sebelum_dihentikan': status,
          'alasan_penghentian': result['alasan'], 'bukti_penghentian_path': path,
          'tanggal_dihentikan': FieldValue.serverTimestamp(), 'updated_at': FieldValue.serverTimestamp()});
      });
      _message('Penugasan dihentikan.');
      await _loadPage();
    } catch (e) { _message('Gagal menghentikan tugas: $e', error: true); }
  }

  Future<void> _mulaiUlangPenugasan(String id) async {
    // Form edit tugas harus disimpan terlebih dahulu sebelum aktivasi.
    if (widget.tugasId == null) return;
    final disimpan = await Navigator.push<bool>(context,
      MaterialPageRoute(builder: (_) => DetailTugasAdminPage(tugasId: widget.tugasId, modeLihat: false)));
    if (disimpan != true || !mounted) return;
    // Data tugas wajib diperiksa ulang pada form edit sebelum diaktifkan.
    final lanjut = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Mulai Ulang Penugasan'),
      content: const Text('Pastikan data tugas, jadwal, lokasi dan Staff sudah diperbarui pada form edit tugas. Aktifkan kembali dengan status Pending?'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Aktifkan'))],
    ));
    if (lanjut != true) return;
    try {
      await _firestore.runTransaction((tx) async {
        final ref = _firestore.collection('penugasan').doc(id);
        final snap = await tx.get(ref);
        if (snap.data()?['status'] != 'dihentikan') throw StateError('Penugasan tidak dihentikan.');
        final hasKendala = (snap.data()?['kendala_aktif_id'] ?? '').toString().isNotEmpty;
        tx.update(ref, {'status': hasKendala ? 'terkendala' : 'pending',
          'tanggal_diaktifkan_ulang': FieldValue.serverTimestamp(), 'updated_at': FieldValue.serverTimestamp()});
      });
      _message('Penugasan kembali Pending.');
      await _loadPage();
    } catch (e) { _message('Gagal memulai ulang: $e', error: true); }
  }

  // Memulihkan revisi lama yang berstatus revisi tetapi belum punya ID aktif.
  // Tidak mengubah instruksi, file, atau riwayat pengumpulan sebelumnya.
  Future<void> _pulihkanRevisiLama(String id) async {
    if (_reviewing.contains(id)) return;
    final lanjut = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hubungkan Revisi Lama'),
        content: const Text(
          'Sistem akan menghubungkan instruksi revisi yang sudah ada dengan '
          'riwayat revisi, tanpa mengubah catatan atau lampiran. Lanjutkan?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Hubungkan')),
        ],
      ),
    );
    if (lanjut != true || !mounted) return;
    setState(() => _reviewing.add(id));
    try {
      final adminUid = _auth.currentUser?.uid;
      if (adminUid == null) throw StateError('Silakan login ulang sebagai Atasan.');
      final assignmentRef = _firestore.collection('penugasan').doc(id);
      // Ambil kandidat di luar transaksi, lalu verifikasi kembali di dalamnya.
      final history = await assignmentRef.collection('riwayat_revisi').get();
      final pending = history.docs.where((d) =>
          (d.data()['status'] ?? '').toString() == 'menunggu_perbaikan' &&
          (d.data()['hasil_pengumpulan_id'] ?? '').toString().isEmpty).toList();
      if (pending.length > 1) {
        throw StateError('Ada lebih dari satu instruksi revisi yang belum '
            'ditanggapi. Periksa riwayat terlebih dahulu agar tidak salah pasangan.');
      }
      final revisionRef = pending.isEmpty
          ? assignmentRef.collection('riwayat_revisi').doc()
          : pending.single.reference;
      await _firestore.runTransaction((tx) async {
        final assignment = await tx.get(assignmentRef);
        if (!assignment.exists) throw StateError('Penugasan tidak ditemukan.');
        final data = assignment.data()!;
        if (data['status'] != 'revisi') {
          throw StateError('Status tugas bukan revisi. Muat ulang halaman.');
        }
        if ((data['revisi_aktif_id'] ?? '').toString().isNotEmpty) {
          throw StateError('Revisi sudah terhubung. Muat ulang halaman.');
        }
        if ((data['kendala_aktif_id'] ?? '').toString().isNotEmpty) {
          throw StateError('Selesaikan kendala aktif terlebih dahulu.');
        }
        final catatan = (data['catatan_revisi'] ?? '').toString().trim();
        if (catatan.isEmpty) {
          throw StateError('Catatan revisi lama kosong. Periksa data tugas.');
        }
        if (pending.isNotEmpty) {
          final existing = await tx.get(revisionRef);
          if (!existing.exists ||
              existing.data()?['status'] != 'menunggu_perbaikan' ||
              (existing.data()?['hasil_pengumpulan_id'] ?? '').toString().isNotEmpty) {
            throw StateError('Riwayat revisi berubah. Muat ulang halaman.');
          }
        }
        if (pending.isEmpty) {
          tx.set(revisionRef, {
            'penugasan_id': id,
            'atasan_id': adminUid,
            'catatan_atasan': catatan,
            'file_revisi_path': (data['file_revisi_path'] ?? '').toString(),
            'file_revisi_nama': (data['file_revisi_nama'] ?? '').toString(),
            'status': 'menunggu_perbaikan',
            'created_at': FieldValue.serverTimestamp(),
          });
        }
        tx.update(assignmentRef, {
          'revisi_aktif_id': revisionRef.id,
          'updated_at': FieldValue.serverTimestamp(),
        });
      });
      _message('Revisi lama berhasil dihubungkan. Staff dapat mengirim perbaikan.');
    } catch (e) {
      _message('Gagal menghubungkan revisi lama: $e', error: true);
    } finally {
      if (mounted) setState(() => _reviewing.remove(id));
    }
  }

  Future<void> _mintaRevisi(String id) async {
    if (_reviewing.contains(id)) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,

      builder: (_) => const _RevisionDialog(),
    );

    if (!mounted || result == null) return;

    setState(() => _reviewing.add(id));

    try {
      final selected = result['file'] as PlatformFile?;

      String path = '';

      String name = '';

      if (selected != null) {
        final bytes = await selected.readAsBytes();

        final uploaded = await _storage.uploadHasilTugas(
          tugasId: 'revisi_$id',

          namaFile: selected.name,

          bytes: bytes,

          contentType: _contentType(selected.extension),
        );

        path = uploaded.path;

        name = uploaded.namaFile;
      }

      // Satu transaksi: status, instruksi, dan ID revisi selalu konsisten.
      final assignmentRef = _firestore.collection('penugasan').doc(id);
      final revisionRef = assignmentRef.collection('riwayat_revisi').doc();
      final adminUid = _auth.currentUser?.uid;
      if (adminUid == null) {
        throw StateError('Sesi Atasan berakhir. Silakan login kembali.');
      }
      await _firestore.runTransaction((tx) async {
        final current = await tx.get(assignmentRef);
        if (!current.exists) throw StateError('Penugasan tidak ditemukan.');
        final data = current.data()!;
        final status = (data['status'] ?? '').toString();
        final existingId = (data['revisi_aktif_id'] ?? '').toString();
        if (existingId.isNotEmpty) {
          throw StateError('Masih ada revisi aktif. Selesaikan revisi sebelumnya.');
        }
        // Status revisi tanpa ID dari proses lama boleh diperbaiki dengan
        // membuat instruksi baru, tanpa menghapus riwayat yang sudah ada.
        if (status != 'dikumpulkan' && status != 'revisi') {
          throw StateError('Revisi hanya dapat diminta setelah hasil dikumpulkan.');
        }
        if ((data['kendala_aktif_id'] ?? '').toString().isNotEmpty) {
          throw StateError('Selesaikan kendala aktif terlebih dahulu.');
        }
        tx.set(revisionRef, {
          'penugasan_id': id,
          'catatan_atasan': result['catatan'],
          'file_revisi_path': path,
          'file_revisi_nama': name,
          'atasan_id': adminUid,
          'status': 'menunggu_perbaikan',
          'created_at': FieldValue.serverTimestamp(),
        });
        tx.update(assignmentRef, {
          'status': 'revisi',
          'revisi_aktif_id': revisionRef.id,
          'catatan_revisi': result['catatan'],
          'file_revisi_url': '',
          'file_revisi_path': path,
          'file_revisi_provider': path.isEmpty ? '' : 'supabase',
          'file_revisi_nama': name,
          'file_revisi_uploaded_by': path.isEmpty ? '' : adminUid,
          'tanggal_revisi': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });
      });
      _message('Permintaan revisi berhasil dikirim.');
    } catch (e) {
      _message('Gagal mengirim revisi: $e', error: true);
    } finally {
      if (mounted) setState(() => _reviewing.remove(id));
    }
  }

  Future<void> _setujui(String id) async {
    if (_reviewing.contains(id)) return;

    setState(() => _reviewing.add(id));

    try {
      await transitionAssignment(_firestore, id, 'disetujui');

      if (!mounted) return;

      Navigator.pushReplacement(
        context,

        MaterialPageRoute(builder: (_) => const RiwayatTugasStaffPage()),
      );
    } catch (e) {
      _message('Gagal menyetujui tugas: $e', error: true);
    } finally {
      if (mounted) setState(() => _reviewing.remove(id));
    }
  }

  List<Widget> _hasilPenugasan(String id, Map<String, dynamic> data) {
    final status = (data['status'] ?? 'pending').toString();

    final url = (data['file_hasil_url'] ?? '').toString();

    final path = (data['file_hasil_path'] ?? '').toString();

    final revisionUrl = (data['file_revisi_url'] ?? '').toString();

    final revisionPath = (data['file_revisi_path'] ?? '').toString();

    return [
      if (['dikumpulkan', 'revisi', 'disetujui'].contains(status)) ...[
        const SizedBox(height: 10),

        const _LabelForm(label: 'Keterangan Hasil Pekerjaan'),

        Text(
          (data['catatan_staff'] ?? '').toString().isEmpty
              ? '-'
              : data['catatan_staff'].toString(),
        ),

        const SizedBox(height: 10),

        const _LabelForm(label: 'File Hasil Pekerjaan'),

        if (url.isEmpty && path.isEmpty)
          const Text('-')
        else
          TextButton.icon(
            onPressed: () => _previewHasilStaff(id, data),

            icon: const Icon(Icons.attach_file),

            label: Text(
              (data['file_hasil_nama'] ?? 'Buka file hasil').toString(),
            ),
          ),
      ],

      if ((data['catatan_revisi'] ?? '').toString().isNotEmpty) ...[
        const SizedBox(height: 10),

        const _LabelForm(label: 'Catatan Revisi'),

        Text(data['catatan_revisi'].toString()),
        if (status == 'revisi') TextButton.icon(onPressed: () => _editCatatanRevisi(id, data['catatan_revisi'].toString()),
          icon: const Icon(Icons.edit), label: const Text('Edit Keterangan Revisi')),
        if (status == 'revisi' &&
            (data['revisi_aktif_id'] ?? '').toString().isEmpty)
          OutlinedButton.icon(
            onPressed: _reviewing.contains(id) ? null : () => _pulihkanRevisiLama(id),
            icon: const Icon(Icons.link),
            label: const Text('Hubungkan Revisi Lama'),
          ),

        if (revisionUrl.isNotEmpty || revisionPath.isNotEmpty)
          TextButton.icon(
            onPressed: () async {
              try {
                final url = revisionPath.isNotEmpty
                    ? await _storage.buatLinkSementara(revisionPath)
                    : revisionUrl;

                final name = (data['file_revisi_nama'] ?? 'Lampiran revisi')
                    .toString();

                Uint8List bytes = Uint8List(0);

                if (!kIsWeb || !name.toLowerCase().endsWith('.pdf')) {
                  final response = await http.get(Uri.parse(url));

                  if (response.statusCode != 200) {
                    throw StateError('HTTP ${response.statusCode}');
                  }

                  bytes = response.bodyBytes;
                }

                if (!mounted) return;

                await Navigator.push(
                  context,

                  MaterialPageRoute<void>(
                    builder: (_) => SimtasFilePreviewPage(
                      namaFile: name,

                      bytes: bytes,

                      externalUrl: url,
                    ),
                  ),
                );
              } catch (e) {
                _message('Gagal membuka lampiran revisi: $e', error: true);
              }
            },

            icon: const Icon(Icons.attach_file),

            label: Text(
              (data['file_revisi_nama'] ?? 'File pendukung revisi').toString(),
            ),
          ),
      ],

      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore.collection('penugasan').doc(id).collection('riwayat_pengumpulan')
            .orderBy('created_at', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 12),
            const Text('Riwayat Pengumpulan Staff', style: TextStyle(fontWeight: FontWeight.bold)),
            ...snapshot.data!.docs.map((doc) {
              final d = doc.data();
              return ListTile(
                dense: true,
                title: Text('${d['jenis'] ?? 'Pengumpulan'}: ${d['keterangan'] ?? ''}'),
                subtitle: Text((d['file_nama'] ?? 'Lampiran').toString()),
                trailing: const Icon(Icons.open_in_new),
                onTap: () async {
                  try {
                    final url = await _storage.ambilLinkRiwayat(id, doc.id);
                    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                  } catch (e) { _message('Gagal membuka riwayat: $e', error: true); }
                },
              );
            }),
          ]);
        },
      ),

      if (status == 'dikumpulkan') ...[
        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _reviewing.contains(id)
                    ? null
                    : () => _mintaRevisi(id),

                child: const Text('Minta Revisi'),
              ),
            ),

            const SizedBox(width: 8),

            Expanded(
              child: ElevatedButton(
                onPressed: _reviewing.contains(id) ? null : () => _setujui(id),

                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,

                  foregroundColor: Colors.white,
                ),

                child: const Text('Disetujui'),
              ),
            ),
          ],
        ),
      ],
    ];
  }

  void _message(String text, {bool error = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),

        backgroundColor: error ? Colors.red.shade700 : biruTua,

        behavior: SnackBarBehavior.floating,

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null) return '-';

    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }

  String _staffName(String uid) {
    return _namaStaff[uid] ?? 'Staf tidak ditemukan';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'disetujui':
        return AppTaskStatus.color('disetujui');

      case 'dikumpulkan':
        return AppTaskStatus.color('dikumpulkan');

      case 'berlangsung':
        return biruSedang;

      case 'revisi':
        return AppTaskStatus.color('berlangsung');

      default:
        return Colors.grey;
    }
  }

  // ───────────────────────────── Tampilan ─────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bool wide = MediaQuery.of(context).size.width >= 900;
    final String title = widget.modeLihat
        ? 'Detail Tugas'
        : widget.tugasId == null
        ? 'Tambah Tugas'
        : 'Edit Tugas';

    return Scaffold(
      backgroundColor: latarAbu,
      drawer: wide
          ? null
          : const AdminSidebar(currentIndex: _sidebarIndex, isDrawer: true),
      body: Row(
        children: [
          if (wide) const AdminSidebar(currentIndex: _sidebarIndex),
          Expanded(
            child: Column(
              children: [
                AdminHeader(title: title, showSidebar: wide),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : Form(key: _formKey, child: _formBody(wide)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _formBody(bool wide) {
    return LayoutBuilder(
      builder: (context, c) {
        final bool twoCol = c.maxWidth >= 900;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.all(wide ? 24 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton.icon(
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text(
                  'Kembali ke Kelola Tugas',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: TextButton.styleFrom(foregroundColor: biruSedang),
              ),
              const SizedBox(height: 8),
              if (twoCol)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _kartuInfo()),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          _kartuJadwal(),
                          const SizedBox(height: 16),
                          _kartuStaf(),
                        ],
                      ),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    _kartuInfo(),
                    const SizedBox(height: 16),
                    _kartuJadwal(),
                    const SizedBox(height: 16),
                    _kartuStaf(),
                  ],
                ),
              if (widget.modeLihat) ...[
                const SizedBox(height: 16),
                _kartuStatusPenugasan(),
              ],
              if (!widget.modeLihat) ...[
                const SizedBox(height: 20),
                Align(
                  alignment: wide ? Alignment.centerRight : Alignment.center,
                  child: SizedBox(
                    width: wide ? 280 : double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _simpanTugas,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppPalette.blue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              widget.tugasId == null
                                  ? 'SIMPAN TUGAS'
                                  : 'SIMPAN PERUBAHAN',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  /// Kartu putih berjudul, dipakai untuk mengelompokkan isian.
  Widget _kartu({
    required String judul,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: biruTua.withOpacity(.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: biruSedang, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  judul,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: biruTua,
                    fontSize: AppTypography.body,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _kartuInfo() {
    return _kartu(
      judul: 'Informasi Tugas',
      icon: Icons.assignment_rounded,
      children: [
        const _LabelForm(label: 'Judul Tugas'),
        TextFormField(
          controller: _judulController,
          enabled: !widget.modeLihat,
          decoration: _dekorasi(
            hint: 'Contoh: Pemeliharaan Server Data Center',
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Judul tugas wajib diisi';
            }
            return null;
          },
        ),
        const SizedBox(height: 18),

        const _LabelForm(label: 'Deskripsi Tugas'),
        TextFormField(
          controller: _deskripsiController,
          enabled: !widget.modeLihat,
          maxLines: 5,
          decoration: _dekorasi(
            hint: 'Jelaskan rincian pekerjaan yang perlu dilakukan...',
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Deskripsi tugas wajib diisi';
            }
            return null;
          },
        ),
        const SizedBox(height: 18),

        const _LabelForm(label: 'Tempat Tugas'),
        TextFormField(
          controller: _tempatController,
          enabled: !widget.modeLihat,
          decoration: _dekorasi(hint: 'Contoh: Kantor Dinas Kominfo Lt. 2')
              .copyWith(
                suffixIcon: _sedangMengambilLokasi
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : widget.modeLihat
                    ? null
                    : IconButton(
                        tooltip: 'Gunakan lokasi saat ini',
                        onPressed: _ambilLokasiSaatIni,
                        icon: const Icon(Icons.my_location),
                      ),
              ),
        ),
        if (!widget.modeLihat) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _pilihLokasiDariPeta,
              icon: const Icon(Icons.map_outlined),
              label: const Text('Pilih dari Peta'),
              style: OutlinedButton.styleFrom(
                foregroundColor: biruSedang,
                side: const BorderSide(color: biruSedang),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
        if (_latitude != null && _longitude != null) ...[
          const SizedBox(height: 10),
          InkWell(
            onTap: _bukaMaps,
            child: Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: biruSedang),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${_latitude!.toStringAsFixed(6)}, '
                    '${_longitude!.toStringAsFixed(6)} (Buka Maps)',
                    style: const TextStyle(
                      color: biruSedang,
                      fontSize: AppTypography.small,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _kartuJadwal() {
    return _kartu(
      judul: 'Jadwal & Prioritas',
      icon: Icons.calendar_month_rounded,
      children: [
        const _LabelForm(label: 'Jadwal Mulai Tugas'),
        Row(
          children: [
            Expanded(
              child: _TimeBox(
                label: _formatDate(_tanggalMulai),
                icon: Icons.calendar_today,
                onTap: widget.modeLihat ? null : _pilihTanggalMulai,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _TimeBox(
                label: _formatTime(_jamMulai),
                icon: Icons.access_time,
                onTap: widget.modeLihat ? null : _pilihJamMulai,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        const _LabelForm(label: 'Jadwal Selesai Tugas'),
        Row(
          children: [
            Expanded(
              child: _TimeBox(
                label: _formatDate(_tanggalSelesai),
                icon: Icons.calendar_today,
                onTap: widget.modeLihat ? null : _pilihTanggalSelesai,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _TimeBox(
                label: _formatTime(_jamSelesai),
                icon: Icons.access_time,
                onTap: widget.modeLihat ? null : _pilihJamSelesai,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        const _LabelForm(label: 'Prioritas Tugas'),
        DropdownButtonFormField<String>(
          value: _prioritas,
          decoration: _dekorasi(hint: 'Pilih prioritas'),
          items: const [
            DropdownMenuItem(value: 'rendah', child: Text('Rendah')),
            DropdownMenuItem(value: 'sedang', child: Text('Sedang')),
            DropdownMenuItem(value: 'tinggi', child: Text('Tinggi')),
          ],
          onChanged: widget.modeLihat
              ? null
              : (value) {
                  if (value != null) {
                    setState(() {
                      _prioritas = value;
                    });
                  }
                },
        ),
      ],
    );
  }

  Widget _kartuStaf() {
    final tersedia = _daftarStaff.where((staff) {
      return !_stafDipilih.contains(staff['id']) &&
          matchesStaffSearch(staff, _staffSearchController.text);
    }).toList();

    return _kartu(
      judul: 'Staf yang Bertugas',
      icon: Icons.groups_rounded,
      children: [
        if (_stafDipilih.isEmpty)
          Text(
            'Belum ada staf dipilih.',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: AppTypography.small,
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _stafDipilih.map((uid) {
              return Chip(
                backgroundColor: const Color(0xFFEAF3FC),
                side: BorderSide.none,
                label: Text(
                  _staffName(uid),
                  style: const TextStyle(
                    fontSize: AppTypography.small,
                    fontWeight: FontWeight.w600,
                    color: biruTua,
                  ),
                ),
                deleteIcon: widget.modeLihat
                    ? null
                    : const Icon(Icons.close, size: 16),
                onDeleted: widget.modeLihat
                    ? null
                    : () {
                        setState(() {
                          _stafDipilih.remove(uid);
                        });
                      },
              );
            }).toList(),
          ),
        if (!widget.modeLihat) ...[
          const SizedBox(height: 14),
          TextField(
            controller: _staffSearchController,
            onChanged: (_) => setState(() {}),
            decoration: _dekorasi(
              hint: 'Cari nama staf...',
            ).copyWith(prefixIcon: const Icon(Icons.search)),
          ),
          const SizedBox(height: 8),
          if (tersedia.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Tidak ada staf lain yang cocok.',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: AppTypography.small,
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView(
                shrinkWrap: true,
                children: tersedia.map((staff) {
                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE2EFFB),
                      child: Icon(Icons.person, color: biruSedang),
                    ),
                    title: Text(
                      (staff['nama'] ?? '-').toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: AppTypography.body,
                      ),
                    ),
                    subtitle: Text((staff['jabatan'] ?? '').toString()),
                    trailing: const Icon(
                      Icons.add_circle_outline,
                      color: biruSedang,
                    ),
                    onTap: () {
                      setState(() {
                        _stafDipilih.add(staff['id'].toString());
                        _staffSearchController.clear();
                      });
                    },
                  );
                }).toList(),
              ),
            ),
        ],
      ],
    );
  }

  Widget _kartuStatusPenugasan() {
    return _kartu(
      judul: 'Status Penugasan',
      icon: Icons.fact_check_rounded,
      children: [
        if (_penugasan.isEmpty)
          Text(
            'Belum ada penugasan.',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: AppTypography.small,
            ),
          )
        else
          ..._penugasan.map((assignment) {
            final data = assignment.data();
            final staffId = (data['staff_id'] ?? '').toString();
            final status = (data['status'] ?? 'pending').toString();

            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F9FC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: abuBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 14,
                        backgroundColor: Color(0xFFE2EFFB),
                        child: Icon(Icons.person, size: 16, color: biruSedang),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _staffName(staffId),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: biruTua,
                          ),
                        ),
                      ),
                      _Badge(
                        text: status.toUpperCase(),
                        color: _statusColor(status),
                      ),
                    ],
                  ),
                  ..._hasilPenugasan(assignment.id, data),
                  if (status != 'dihentikan' && status != 'disetujui')
                    OutlinedButton.icon(onPressed: () => _hentikanPenugasan(assignment.id),
                      icon: const Icon(Icons.stop_circle_outlined), label: const Text('Hentikan Tugas')),
                  if (status == 'dihentikan') ...[
                    Text('Alasan penghentian: ${data['alasan_penghentian'] ?? '-'}'),
                    TextButton.icon(onPressed: () => _mulaiUlangPenugasan(assignment.id),
                      icon: const Icon(Icons.restart_alt), label: const Text('Mulai Ulang Tugas')),
                  ],
                ],
              ),
            );
          }),
      ],
    );
  }

  InputDecoration _dekorasi({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: Colors.grey.shade500,
        fontSize: AppTypography.body,
      ),
      filled: true,
      fillColor: const Color(0xFFF7F9FC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: abuBorder),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: abuBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: biruSedang, width: 1.5),
      ),
    );
  }
}

class _LabelForm extends StatelessWidget {
  final String label;

  const _LabelForm({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),

      child: Text(
        label,

        style: const TextStyle(
          fontWeight: FontWeight.w700,

          color: Color(0xFF303846),

          fontSize: AppTypography.body,
        ),
      ),
    );
  }
}

class _TimeBox extends StatelessWidget {
  final String label;

  final IconData icon;

  final VoidCallback? onTap;

  const _TimeBox({
    required this.label,

    required this.icon,

    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,

      borderRadius: BorderRadius.circular(12),

      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),

        decoration: BoxDecoration(
          color: const Color(0xFFF7F9FC),

          borderRadius: BorderRadius.circular(12),

          border: Border.all(color: const Color(0xFFE1E5F0)),
        ),

        child: Row(
          children: [
            Icon(icon, size: 18, color: AppPalette.blue),

            const SizedBox(width: 8),

            Expanded(
              child: Text(
                label,

                overflow: TextOverflow.ellipsis,

                style: const TextStyle(fontSize: AppTypography.small),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;

  final Color color;

  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),

      decoration: BoxDecoration(
        color: color.withOpacity(.1),

        borderRadius: BorderRadius.circular(9),
      ),

      child: Text(
        text,

        style: TextStyle(
          color: color,

          fontSize: AppTypography.caption,

          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _RevisionDialog extends StatefulWidget {
  const _RevisionDialog({this.catatanAwal = '', this.isEdit = false});

  final String catatanAwal;
  final bool isEdit;

  @override
  State<_RevisionDialog> createState() => _RevisionDialogState();
}

class _RevisionDialogState extends State<_RevisionDialog> {
  late final TextEditingController _controller;

  PlatformFile? _file;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.catatanAwal);
  }

  @override
  void dispose() {
    _controller.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isEdit ? 'Edit Revisi Aktif' : 'Minta Revisi'),

      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,

          children: [
            TextField(
              controller: _controller,

              maxLines: 4,

              onChanged: (_) => setState(() {}),

              decoration: const InputDecoration(
                hintText: 'Tuliskan catatan revisi...',

                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: () async {
                final selected = await FilePicker.pickFile(
                  type: FileType.custom,

                  allowedExtensions: const [
                    'pdf',

                    'jpg',

                    'jpeg',

                    'png',

                    'docx',
                  ],
                );

                if (selected != null && mounted)
                  setState(() => _file = selected);
              },

              icon: const Icon(Icons.attach_file),

              label: Text(_file?.name ?? 'File pendukung revisi (opsional)'),
            ),

            if (_file != null)
              TextButton(
                onPressed: () => setState(() => _file = null),

                child: const Text('Hapus lampiran'),
              ),
          ],
        ),
      ),

      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),

          child: const Text('Batal'),
        ),

        ElevatedButton(
          onPressed: _controller.text.trim().isEmpty
              ? null
              : () => Navigator.pop(context, {
                  'catatan': _controller.text.trim(),

                  'file': _file,
                }),

          child: Text(widget.isEdit ? 'Simpan Perubahan' : 'Kirim Revisi'),
        ),
      ],
    );
  }
}
