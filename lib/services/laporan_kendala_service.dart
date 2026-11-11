import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Status laporan kendala yang disimpan pada Firestore.
class StatusLaporanKendala {
  static const menungguReview = 'menunggu_review';
  static const dalamPenanganan = 'dalam_penanganan';
  static const menungguKonfirmasi = 'menunggu_konfirmasi';
  static const selesai = 'selesai';
  static const ditolak = 'ditolak';

  static const aktif = <String>{
    menungguReview,
    dalamPenanganan,
    menungguKonfirmasi,
  };

  static String label(String status) {
    switch (status) {
      case menungguReview:
        return 'Menunggu Review';
      case dalamPenanganan:
        return 'Dalam Penanganan';
      case menungguKonfirmasi:
        return 'Menunggu Konfirmasi';
      case selesai:
        return 'Selesai';
      case ditolak:
        return 'Ditolak';
      default:
        return status;
    }
  }
}

/// Layanan Firestore untuk laporan kendala SIMTAS.
///
/// Catatan:
/// - Hak akses harus ditegakkan juga pada Firestore Security Rules.
/// - Hanya satu laporan aktif diizinkan untuk setiap penugasan.
/// - Field kendala_aktif_id menjadi pengunci laporan aktif.
/// - Bukti diunggah menggunakan SupabaseStorageService.
/// - Simpan path relatif bucket pada bukti_path.
class LaporanKendalaService {
  LaporanKendalaService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _laporan =>
      _firestore.collection('laporan_kendala');

  CollectionReference<Map<String, dynamic>> get _penugasan =>
      _firestore.collection('penugasan');

  String get _uid {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Sesi login tidak ditemukan. Silakan login kembali.');
    }

    return user.uid;
  }

  /// Status penugasan setelah kendala selesai/ditolak: kembali ke status
  /// sebelum terkendala (revisi tetap revisi), default berlangsung.
  String _statusSetelahKendala(Map<String, dynamic> penugasan) {
    final sebelum = (penugasan['status_sebelum_kendala'] ?? '').toString();
    return sebelum == 'revisi' ? 'revisi' : 'berlangsung';
  }

  Future<void> _pastikanAdmin(String uid) async {
    final user = await _firestore.collection('users').doc(uid).get();

    if ((user.data()?['role'] ?? '').toString().toLowerCase() != 'admin') {
      throw StateError('Hanya admin/atasan yang boleh menangani laporan.');
    }
  }

  String _wajibIsi(String value, String nama) {
    final clean = value.trim();

    if (clean.isEmpty) {
      throw ArgumentError('$nama tidak boleh kosong.');
    }

    return clean;
  }

  /// Stream seluruh laporan untuk admin.
  /// Sorting dapat dilakukan pada halaman UI.
  Stream<QuerySnapshot<Map<String, dynamic>>> streamSemuaLaporan() {
    return _laporan.snapshots();
  }

  /// Stream laporan milik staff yang sedang login.
  Stream<QuerySnapshot<Map<String, dynamic>>> streamLaporanSaya() {
    return _laporan.where('pelapor_id', isEqualTo: _uid).snapshots();
  }

  /// Stream laporan berdasarkan penugasan.
  Stream<QuerySnapshot<Map<String, dynamic>>> streamLaporanPenugasan(
    String penugasanId,
  ) {
    return _laporan.where('penugasan_id', isEqualTo: penugasanId).snapshots();
  }

  /// Stream detail satu laporan secara real-time.
  Stream<DocumentSnapshot<Map<String, dynamic>>> streamDetail(
    String laporanId,
  ) {
    return _laporan.doc(laporanId).snapshots();
  }

  /// Staff membuat laporan kendala.
  ///
  /// Setelah laporan berhasil disimpan,
  /// status penugasan otomatis menjadi terkendala.
  Future<String> buatLaporan({
    required String penugasanId,
    required String tugasId,
    required String jenisKendala,
    required String deskripsi,
    required String dampak,
    required String prioritas,
    String buktiPath = '',
    String buktiProvider = '',
    String buktiUrl = '',
  }) async {
    final uid = _uid;

    final idPenugasan = _wajibIsi(penugasanId, 'ID penugasan');

    final idTugas = _wajibIsi(tugasId, 'ID tugas');

    final jenis = _wajibIsi(jenisKendala, 'Jenis kendala');

    final uraian = _wajibIsi(deskripsi, 'Deskripsi');

    final nilaiDampak = _wajibIsi(dampak, 'Dampak');

    final nilaiPrioritas = _wajibIsi(prioritas, 'Prioritas');

    final tugasRef = _penugasan.doc(idPenugasan);
    final laporanRef = _laporan.doc();

    await _firestore.runTransaction((tx) async {
      final tugasSnap = await tx.get(tugasRef);

      if (!tugasSnap.exists) {
        throw StateError('Penugasan tidak ditemukan.');
      }

      final tugas = tugasSnap.data()!;

      final staffId = (tugas['staff_id'] ?? '').toString();

      if (staffId != uid) {
        throw StateError('Hanya staff yang ditugaskan dapat membuat laporan.');
      }

      if ((tugas['tugas_id'] ?? '').toString() != idTugas) {
        throw StateError('ID tugas tidak sesuai dengan penugasan.');
      }

      final statusSaatIni = (tugas['status'] ?? 'pending').toString();
      if (statusSaatIni != 'berlangsung' && statusSaatIni != 'revisi') {
        throw StateError(
          'Laporan baru hanya dapat dibuat saat tugas berlangsung atau revisi.',
        );
      }

      final laporanAktif = (tugas['kendala_aktif_id'] ?? '').toString();

      if (laporanAktif.isNotEmpty) {
        throw StateError('Masih ada laporan kendala aktif pada penugasan ini.');
      }

      tx.set(laporanRef, {
        'penugasan_id': idPenugasan,
        'tugas_id': idTugas,
        'pelapor_id': uid,
        'jenis_kendala': jenis,
        'deskripsi': uraian,
        'dampak': nilaiDampak,
        'prioritas': nilaiPrioritas,
        'bukti_path': buktiPath.trim(),
        'bukti_provider': buktiProvider.trim(),
        'bukti_url': buktiUrl.trim(),
        'status': StatusLaporanKendala.menungguReview,
        'solusi': '',
        'ditangani_oleh': '',
        'alasan_penolakan': '',
        'created_at': FieldValue.serverTimestamp(),
        'tanggal_laporan': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'resolved_at': null,
        'konfirmasi_staff_at': null,
      });

      tx.update(tugasRef, {
        'status': 'terkendala',
        'kendala_aktif_id': laporanRef.id,
        'updated_at': FieldValue.serverTimestamp(),
      });
    });

    return laporanRef.id;
  }

  /// Admin menerima laporan yang menunggu review.
  Future<void> mulaiPenanganan(String laporanId) {
    return _ubahOlehAdmin(
      laporanId: laporanId,
      dari: {StatusLaporanKendala.menungguReview},
      ke: StatusLaporanKendala.dalamPenanganan,
    );
  }

  /// Admin mengirim solusi kepada staff.
  /// Status laporan menjadi menunggu konfirmasi.
  Future<void> kirimSolusi({
    required String laporanId,
    required String solusi,
    String filePath = '',
    String fileNama = '',
  }) {
    return _ubahOlehAdmin(
      laporanId: laporanId,
      dari: {StatusLaporanKendala.dalamPenanganan},
      ke: StatusLaporanKendala.menungguKonfirmasi,
      solusi: _wajibIsi(solusi, 'Solusi'),
      filePath: filePath,
      fileNama: fileNama,
    );
  }

  /// Admin dapat memperbaiki solusi sebelum staff mengonfirmasi.
  Future<void> editSolusi({
    required String laporanId,
    required String solusi,
    String? filePath,
    String? fileNama,
  }) async {
    final uid = _uid;
    await _pastikanAdmin(uid);
    final ref = _laporan.doc(laporanId);
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists ||
          snap.data()?['status'] != StatusLaporanKendala.menungguKonfirmasi) {
        throw StateError('Solusi hanya dapat diedit sebelum konfirmasi Staff.');
      }
      tx.update(ref, {
        'solusi': _wajibIsi(solusi, 'Solusi'),
        if (filePath != null) 'solusi_file_path': filePath,
        if (fileNama != null) 'solusi_file_nama': fileNama,
        'ditangani_oleh': uid,
        'updated_at': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Admin menolak laporan beserta alasannya.
  /// Penugasan kembali berlangsung.
  Future<void> tolakLaporan({
    required String laporanId,
    required String alasan,
  }) {
    return _ubahOlehAdmin(
      laporanId: laporanId,
      dari: {
        StatusLaporanKendala.menungguReview,
        StatusLaporanKendala.dalamPenanganan,
      },
      ke: StatusLaporanKendala.ditolak,
      alasan: _wajibIsi(alasan, 'Alasan penolakan'),
    );
  }

  /// Proses perubahan status oleh admin.
  Future<void> _ubahOlehAdmin({
    required String laporanId,
    required Set<String> dari,
    required String ke,
    String? solusi,
    String? alasan,
    String? filePath,
    String? fileNama,
  }) async {
    final uid = _uid;
    await _pastikanAdmin(uid);
    final laporanRef = _laporan.doc(_wajibIsi(laporanId, 'ID laporan'));

    // Migrasi aman untuk laporan lama yang belum memiliki kendala_aktif_id.
    // Hanya mengklaim penugasan yang benar-benar masih terkendala.
    await _firestore.runTransaction((tx) async {
      final laporan = await tx.get(laporanRef);
      if (!laporan.exists) throw StateError('Laporan tidak ditemukan.');
      final data = laporan.data()!;
      final penugasanRef = _penugasan.doc(
        (data['penugasan_id'] ?? '').toString(),
      );
      final penugasan = await tx.get(penugasanRef);
      if (!penugasan.exists) throw StateError('Penugasan tidak ditemukan.');
      final tugas = penugasan.data()!;
      if ((tugas['status'] ?? '') != 'terkendala') {
        throw StateError('Penugasan sudah tidak terkendala.');
      }
      final aktif = (tugas['kendala_aktif_id'] ?? '').toString();
      if (aktif.isNotEmpty && aktif != laporanRef.id) {
        throw StateError('Penugasan mempunyai laporan aktif lainnya.');
      }
      if (aktif.isEmpty && dari.contains((data['status'] ?? '').toString())) {
        tx.update(penugasanRef, {
          'kendala_aktif_id': laporanRef.id,
          'updated_at': FieldValue.serverTimestamp(),
        });
      }
    });

    await _firestore.runTransaction((tx) async {
      final laporanSnap = await tx.get(laporanRef);

      if (!laporanSnap.exists) {
        throw StateError('Laporan tidak ditemukan.');
      }

      final laporan = laporanSnap.data()!;

      final penugasanRef = _penugasan.doc(
        _wajibIsi((laporan['penugasan_id'] ?? '').toString(), 'ID penugasan'),
      );

      final penugasanSnap = await tx.get(penugasanRef);

      if (!penugasanSnap.exists) {
        throw StateError('Penugasan tidak ditemukan.');
      }

      final tugas = penugasanSnap.data()!;

      final statusLaporan = (laporan['status'] ?? '').toString();

      if (!dari.contains(statusLaporan)) {
        throw StateError('Status laporan sudah berubah. Muat ulang halaman.');
      }

      if ((tugas['status'] ?? '').toString() != 'terkendala') {
        throw StateError('Status penugasan tidak lagi terkendala.');
      }

      // Kompatibilitas laporan lama.
      // Laporan lama mungkin belum menyimpan kendala_aktif_id.
      final aktifId = (tugas['kendala_aktif_id'] ?? '').toString();

      if (aktifId.isNotEmpty && aktifId != laporanRef.id) {
        throw StateError('Laporan ini bukan laporan aktif penugasan.');
      }

      tx.update(laporanRef, {
        'status': ke,
        'ditangani_oleh': uid,
        'updated_at': FieldValue.serverTimestamp(),
        if (solusi != null) 'solusi': solusi,
        if (solusi != null) 'solusi_file_path': filePath ?? '',
        if (solusi != null) 'solusi_file_nama': fileNama ?? '',
        if (alasan != null) 'alasan_penolakan': alasan,
        if (ke == StatusLaporanKendala.ditolak)
          'rejected_at': FieldValue.serverTimestamp(),
      });

      if (ke == StatusLaporanKendala.ditolak) {
        tx.update(penugasanRef, {
          'status': _statusSetelahKendala(tugas),
          'status_sebelum_kendala': FieldValue.delete(),
          'kendala_aktif_id': FieldValue.delete(),
          'updated_at': FieldValue.serverTimestamp(),
        });
      } else if (aktifId.isEmpty) {
        tx.update(penugasanRef, {
          'kendala_aktif_id': laporanRef.id,
          'updated_at': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  /// Staff mengonfirmasi kendala sudah teratasi.
  Future<void> konfirmasiSelesai(String laporanId) {
    return _konfirmasiStaff(laporanId, selesai: true);
  }

  /// Staff menyatakan solusi belum berhasil.
  /// Laporan kembali dalam penanganan.
  Future<void> belumTeratasi(String laporanId) {
    return _konfirmasiStaff(laporanId, selesai: false);
  }

  /// Proses konfirmasi oleh staff.
  Future<void> _konfirmasiStaff(
    String laporanId, {
    required bool selesai,
  }) async {
    final uid = _uid;

    final laporanRef = _laporan.doc(_wajibIsi(laporanId, 'ID laporan'));

    await _firestore.runTransaction((tx) async {
      final laporanSnap = await tx.get(laporanRef);

      if (!laporanSnap.exists) {
        throw StateError('Laporan tidak ditemukan.');
      }

      final laporan = laporanSnap.data()!;

      if ((laporan['pelapor_id'] ?? '').toString() != uid) {
        throw StateError('Hanya pelapor yang boleh mengonfirmasi solusi.');
      }

      if ((laporan['status'] ?? '').toString() !=
          StatusLaporanKendala.menungguKonfirmasi) {
        throw StateError('Laporan belum menunggu konfirmasi staff.');
      }

      final penugasanRef = _penugasan.doc(
        _wajibIsi((laporan['penugasan_id'] ?? '').toString(), 'ID penugasan'),
      );

      final penugasanSnap = await tx.get(penugasanRef);

      if (!penugasanSnap.exists) {
        throw StateError('Penugasan tidak ditemukan.');
      }

      final tugas = penugasanSnap.data()!;

      if ((tugas['staff_id'] ?? '').toString() != uid ||
          (tugas['status'] ?? '').toString() != 'terkendala' ||
          (tugas['kendala_aktif_id'] ?? '').toString() != laporanRef.id) {
        throw StateError('Status atau pemilik penugasan tidak sesuai.');
      }

      tx.update(laporanRef, {
        'status': selesai
            ? StatusLaporanKendala.selesai
            : StatusLaporanKendala.dalamPenanganan,
        'updated_at': FieldValue.serverTimestamp(),
        'konfirmasi_staff_at': FieldValue.serverTimestamp(),
        if (selesai) 'resolved_at': FieldValue.serverTimestamp(),
      });

      if (selesai) {
        tx.update(penugasanRef, {
          'status': 'berlangsung',
          'kendala_aktif_id': FieldValue.delete(),
          'updated_at': FieldValue.serverTimestamp(),
        });
      }
    });
  }
}
