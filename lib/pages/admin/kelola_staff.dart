import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'package:image_picker/image_picker.dart';
import '/widgets/admin_header.dart';
import 'admin_sidebar.dart';
import 'status_staff.dart';

class KelolaStaffPage extends StatefulWidget {
  const KelolaStaffPage({super.key});

  @override
  State<KelolaStaffPage> createState() => _KelolaStaffPageState();
}

class _KelolaStaffPageState extends State<KelolaStaffPage> {
  static const Color _biruTua = AppPalette.navy;
  static const Color _biru = AppPalette.blue;
  static const Color _biruMuda = AppPalette.sky;
  static const Color _bg = AppPalette.background;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream dibuat sekali supaya tidak berkedip saat mengetik di kolom cari.
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _usersStream =
      _firestore.collection('users').snapshots();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _assignmentsStream =
      _firestore.collection('penugasan').snapshots();

  // Sama dengan halaman Status Staff: tugas aktif >= 5 berarti Sibuk.
  static const int _maksTugasAktif = 5;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Paging: maksimal 10 staf per halaman.
  static const int _perPage = 10;
  int _page = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ===== HELPER =====
  // Nomor HP bisa tersimpan di beberapa nama field
  // (admin: 'wa', profil staf: 'no_hp', dll). Ambil yang pertama terisi.
  String _phoneOf(Map<String, dynamic>? data) {
    if (data == null) return '';
    for (final key in [
      'wa',
      'no_hp',
      'noHp',
      'nomor_hp',
      'no_telp',
      'telepon',
    ]) {
      final v = (data[key] ?? '').toString().trim();
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  // Email kontak staf. Pakai email_kontak; kalau kosong, pakai field email
  // lama selama bukan email bayangan NIP (@simtas.internal).
  String _kontakEmailOf(Map<String, dynamic>? data) {
    if (data == null) return '';
    final kontak = _str(data['email_kontak']);
    if (kontak.isNotEmpty) return kontak;
    final lama = _str(data['email']);
    if (lama.isNotEmpty && !lama.toLowerCase().endsWith('@simtas.internal')) {
      return lama;
    }
    return '';
  }

  // Tugas dianggap aktif jika belum selesai/disetujui dan bukan antrean
  // (aturan yang sama dengan halaman Status Staff).
  bool _isActiveStatus(dynamic value) {
    final v = (value ?? 'pending').toString().toLowerCase();
    return !const [
      'disetujui',
      'selesai',
      'antrean',
      'menunggu giliran',
    ].contains(v);
  }

  // Hitung tugas aktif milik satu staf. Pencocokan lewat UID, nama, atau NIP,
  // sama seperti halaman Status Staff.
  int _countActive(
    String uid,
    Map<String, dynamic> staff,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> assignments,
  ) {
    final name = _str(staff['nama']).toLowerCase();
    final nip = _str(staff['nip']);
    int n = 0;
    for (final d in assignments) {
      final a = d.data();
      final aUid = _str(
        a['staff_uid'] ?? a['staff_id'] ?? a['uid_staff'] ?? a['user_id'],
      );
      final aName = _str(a['staff_nama'] ?? a['nama_staff']).toLowerCase();
      final aNip = _str(a['staff_nip'] ?? a['nip_staff']);
      final cocok =
          (aUid.isNotEmpty && aUid == uid) ||
          (name.isNotEmpty && aName == name) ||
          (nip.isNotEmpty && aNip == nip);
      if (cocok && _isActiveStatus(a['status'])) n++;
    }
    return n;
  }

  // Ubah nilai apa pun dari Firestore menjadi String. Ini yang mencegah error
  // "type 'int' is not a subtype of type 'String'" kalau ada field (mis. NIP)
  // yang tersimpan sebagai angka.
  String _str(dynamic v, [String fallback = '']) {
    if (v == null) return fallback;
    final t = v.toString().trim();
    return t.isEmpty ? fallback : t;
  }

  ImageProvider? _decodeFoto(dynamic value) {
    final base64 = _str(value);
    if (base64.isEmpty) return null;
    try {
      return MemoryImage(base64Decode(base64));
    } catch (_) {
      return null;
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  // ===== AUTH SEKUNDER =====
  // Dipakai untuk membuat akun staf tanpa mengeluarkan (logout) admin.
  Future<FirebaseAuth> _secondaryAuth() async {
    FirebaseApp app;
    try {
      app = Firebase.app('staffCreator');
    } catch (_) {
      app = await Firebase.initializeApp(
        name: 'staffCreator',
        options: Firebase.app().options,
      );
    }
    return FirebaseAuth.instanceFor(app: app);
  }

  // Ubah password akun staf lewat Cloud Function (butuh Admin SDK).
  Future<void> _setStaffPassword(String uid, String password) async {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'adminSetPassword',
    );
    await callable.call({'uid': uid, 'password': password});
  }

  // Ubah NIP (= email login NIP@simtas.internal) lewat Cloud Function.
  // Fungsi ini juga ikut memperbarui field nip & email di dokumen users.
  // Mengembalikan email login yang baru.
  Future<String> _setStaffNip(String uid, String nip) async {
    final callable = FirebaseFunctions.instance.httpsCallable('adminSetNip');
    final result = await callable.call({'uid': uid, 'nip': nip});
    final data = result.data;
    if (data is Map && data['email'] != null) return data['email'].toString();
    return '$nip@simtas.internal';
  }

  // Hapus akun login (Firebase Authentication) staf lewat Cloud Function.
  Future<void> _deleteStaffAuth(String uid) async {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'adminDeleteStaff',
    );
    await callable.call({'uid': uid});
  }

  String _errorMessage(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'email-already-in-use':
          return 'NIP ini sudah punya akun login. Gunakan NIP lain, atau hapus akun lamanya lewat tombol hapus staf.';
        case 'weak-password':
          return 'Password terlalu lemah, minimal 6 karakter.';
        default:
          return e.message ?? e.code;
      }
    }
    if (e is FirebaseFunctionsException) {
      switch (e.code) {
        case 'not-found':
        case 'unimplemented':
          return 'Fungsi di server belum di-deploy (adminSetPassword / adminSetNip / adminDeleteStaff). Jalankan: firebase deploy --only functions';
        case 'permission-denied':
          return e.message ?? 'Hanya admin yang boleh melakukan ini.';
        case 'unauthenticated':
          return 'Sesi login habis. Silakan login ulang.';
        default:
          return e.message ?? e.code;
      }
    }
    if (e is FirebaseException) {
      if (e.code == 'permission-denied') {
        return 'Ditolak aturan Firestore. Pastikan akun yang login adalah admin dan firestore.rules terbaru sudah dipublish.';
      }
      return e.message ?? e.code;
    }
    return e.toString().replaceFirst('Exception: ', '');
  }

  // ===== POP-UP TAMBAH & EDIT STAF =====
  void _showStaffModal({Map<String, dynamic>? staffDoc}) {
    final isEdit = staffDoc != null;
    final String? docId = staffDoc?['id'];

    final String oldNip = _str(staffDoc?['nip']);

    final namaC = TextEditingController(text: _str(staffDoc?['nama']));
    final nipC = TextEditingController(text: oldNip);
    final jabatanC = TextEditingController(text: _str(staffDoc?['jabatan']));
    final emailC = TextEditingController(text: _kontakEmailOf(staffDoc));
    final waC = TextEditingController(text: _phoneOf(staffDoc));
    final passC = TextEditingController();

    String? fotoBase64 = _str(staffDoc?['foto_base64']);
    bool saving = false;
    bool obscure = true;
    String? errorText;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            Future<void> pickImage(ImageSource source) async {
              final image = await ImagePicker().pickImage(
                source: source,
                imageQuality: 70,
                maxWidth: 512,
                maxHeight: 512,
              );
              if (image == null) return;
              final bytes = await image.readAsBytes();
              if (!modalContext.mounted) return;
              setModalState(() => fotoBase64 = base64Encode(bytes));
            }

            void showPhotoOptions() {
              showDialog(
                context: modalContext,
                builder: (photoContext) => SimpleDialog(
                  title: const Text('Foto staf'),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  children: [
                    SimpleDialogOption(
                      onPressed: () {
                        Navigator.pop(photoContext);
                        pickImage(ImageSource.gallery);
                      },
                      child: const Row(
                        children: [
                          Icon(Icons.photo_library_rounded, color: _biru),
                          SizedBox(width: 12),
                          Text('Pilih dari galeri'),
                        ],
                      ),
                    ),
                    SimpleDialogOption(
                      onPressed: () {
                        Navigator.pop(photoContext);
                        pickImage(ImageSource.camera);
                      },
                      child: const Row(
                        children: [
                          Icon(Icons.camera_alt_rounded, color: _biru),
                          SizedBox(width: 12),
                          Text('Ambil foto'),
                        ],
                      ),
                    ),
                    if (fotoBase64 != null && fotoBase64!.isNotEmpty)
                      SimpleDialogOption(
                        onPressed: () {
                          Navigator.pop(photoContext);
                          setModalState(() => fotoBase64 = null);
                        },
                        child: const Row(
                          children: [
                            Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.redAccent,
                            ),
                            SizedBox(width: 12),
                            Text('Hapus foto'),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            }

            bool nipBerubahSekarang() => nipC.text.trim() != oldNip;

            // Reset langsung (tanpa menekan Simpan): password staf menjadi NIP.
            Future<void> resetKeNip() async {
              final konfirmasi = await showDialog<bool>(
                context: modalContext,
                builder: (c) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  title: const Text('Reset password?'),
                  content: Text(
                    'Password ${_str(namaC.text, 'staf ini')} akan diubah menjadi NIP ($oldNip). Password lama tidak berlaku lagi.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Batal'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              );
              if (konfirmasi != true || docId == null) return;
              if (!modalContext.mounted) return;
              setModalState(() {
                errorText = null;
                saving = true;
              });
              try {
                await _setStaffPassword(docId, oldNip);
                if (modalContext.mounted) {
                  setModalState(() {
                    saving = false;
                    passC.clear();
                  });
                }
                _snack('Password berhasil direset. Staf login dengan NIP.');
              } catch (e) {
                if (modalContext.mounted) {
                  setModalState(() {
                    saving = false;
                    errorText = _errorMessage(e);
                  });
                }
              }
            }

            Future<void> save() async {
              final nama = namaC.text.trim();
              final nip = nipC.text.trim();
              final jabatan = jabatanC.text.trim();
              final wa = waC.text.trim();
              final emailKontak = emailC.text.trim();
              final pass = passC.text;
              final bool nipBerubah = isEdit && nip != oldNip;

              if (nama.isEmpty || nip.isEmpty || jabatan.isEmpty) {
                setModalState(
                  () => errorText = 'Nama, NIP, dan jabatan harus diisi.',
                );
                return;
              }
              if ((!isEdit || nipBerubah) &&
                  !RegExp(r'^[0-9]{6,30}$').hasMatch(nip)) {
                setModalState(
                  () => errorText = 'NIP harus angka, 6 sampai 30 digit.',
                );
                return;
              }
              if (wa.length > 30) {
                setModalState(
                  () => errorText = 'Nomor WhatsApp maksimal 30 karakter.',
                );
                return;
              }
              if (emailKontak.isNotEmpty &&
                  !RegExp(
                    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                  ).hasMatch(emailKontak)) {
                setModalState(() => errorText = 'Format email tidak valid.');
                return;
              }
              if (!isEdit && pass.length < 6) {
                setModalState(
                  () => errorText = 'Password wajib diisi, minimal 6 karakter.',
                );
                return;
              }
              if (isEdit && pass.isNotEmpty && pass.length < 6) {
                setModalState(
                  () => errorText = 'Password baru minimal 6 karakter.',
                );
                return;
              }

              setModalState(() {
                errorText = null;
                saving = true;
              });

              try {
                if (isEdit && docId != null) {
                  // 1. Ubah NIP (sekaligus akun login) jika berubah.
                  //    Fungsi server juga memperbarui nip & email di Firestore.
                  String? emailLoginBaru;
                  if (nipBerubah) {
                    emailLoginBaru = await _setStaffNip(docId, nip);
                  }

                  // 2. Simpan data profil
                  await _firestore.collection('users').doc(docId).update({
                    'nama': nama,
                    'nip': nip,
                    if (emailLoginBaru != null) 'email': emailLoginBaru,
                    'email_kontak': emailKontak,
                    'jabatan': jabatan,
                    'no_hp': wa,
                    'foto_base64': fotoBase64 ?? '',
                    'updated_at': FieldValue.serverTimestamp(),
                  });

                  // 3. Ubah password (jika diisi). Dilakukan terakhir supaya
                  //    kalau gagal, data profil sudah aman tersimpan.
                  if (pass.isNotEmpty) {
                    try {
                      await _setStaffPassword(docId, pass);
                    } catch (e) {
                      throw Exception(
                        'Data tersimpan, tetapi password gagal diubah: ${_errorMessage(e)}',
                      );
                    }
                  }
                } else {
                  final email = "$nip@simtas.internal";
                  final auth = await _secondaryAuth();
                  UserCredential? cred;
                  try {
                    cred = await auth.createUserWithEmailAndPassword(
                      email: email,
                      password: pass,
                    );
                    final String newUid = cred.user!.uid;

                    // Ditulis dengan sesi admin (bukan sesi staf baru)
                    await _firestore.collection('users').doc(newUid).set({
                      'uid': newUid,
                      'email': email,
                      'nama': nama,
                      'nip': nip,
                      'email_kontak': emailKontak,
                      'jabatan': jabatan,
                      'no_hp': wa,
                      'role': 'staff',
                      'status_pekerjaan': 'tersedia',
                      'foto_base64': fotoBase64 ?? '',
                      'is_first_login': true,
                      'created_at': FieldValue.serverTimestamp(),
                      'updated_at': FieldValue.serverTimestamp(),
                    });
                  } catch (e) {
                    // Batalkan akun login jika data gagal disimpan
                    try {
                      await cred?.user?.delete();
                    } catch (_) {}
                    rethrow;
                  } finally {
                    await auth.signOut();
                  }
                }

                if (dialogContext.mounted) Navigator.pop(dialogContext);
                _snack(
                  isEdit
                      ? (pass.isNotEmpty
                            ? 'Data dan password staf berhasil diperbarui'
                            : 'Data staf berhasil diperbarui')
                      : 'Staf baru ditambahkan. Login dengan NIP dan password yang dibuat.',
                );
              } catch (e) {
                if (modalContext.mounted) {
                  setModalState(() {
                    saving = false;
                    errorText = _errorMessage(e);
                  });
                }
              }
            }

            final foto = _decodeFoto(fotoBase64);

            return Dialog(
              backgroundColor: Colors.white,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEdit
                                      ? 'Edit Data Staf'
                                      : 'Tambah Staf Baru',
                                  style: const TextStyle(
                                    fontSize: AppTypography.subtitle,
                                    fontWeight: FontWeight.bold,
                                    color: _biruTua,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isEdit
                                      ? 'Perbarui data atau reset password staf'
                                      : 'Isi data untuk membuat akun staf',
                                  style: TextStyle(
                                    fontSize: AppTypography.small,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: saving
                                ? null
                                : () => Navigator.pop(dialogContext),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Avatar
                      Center(
                        child: GestureDetector(
                          onTap: showPhotoOptions,
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 40,
                                backgroundColor: AppPalette.blue.withOpacity(
                                  0.1,
                                ),
                                backgroundImage: foto,
                                child: foto == null
                                    ? const Icon(
                                        Icons.person_rounded,
                                        size: 40,
                                        color: _biru,
                                      )
                                    : null,
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: _biru,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt_rounded,
                                    size: 15,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      _buildModalTextField(
                        'Nama Lengkap',
                        namaC,
                        Icons.person_outline_rounded,
                        hint: 'Masukkan nama lengkap',
                        textCapitalization: TextCapitalization.words,
                      ),
                      _buildModalTextField(
                        'NIP',
                        nipC,
                        Icons.badge_outlined,
                        hint: 'Masukkan NIP',
                        helperText: isEdit
                            ? 'NIP dipakai untuk login. Mengubahnya ikut mengubah akun login staf.'
                            : 'NIP dipakai staf untuk login.',
                        keyboardType: TextInputType.number,
                      ),
                      _buildModalTextField(
                        'Jabatan',
                        jabatanC,
                        Icons.work_outline_rounded,
                        hint: 'Masukkan jabatan',
                        textCapitalization: TextCapitalization.words,
                      ),
                      _buildModalTextField(
                        'Email (opsional)',
                        emailC,
                        Icons.email_outlined,
                        hint: 'Masukkan email staf',
                        keyboardType: TextInputType.emailAddress,
                      ),
                      _buildModalTextField(
                        'No. WhatsApp (opsional)',
                        waC,
                        Icons.phone_outlined,
                        hint: 'Contoh: 08123456789',
                        helperText:
                            'Boleh kosong, staf bisa mengisi sendiri di profilnya.',
                        keyboardType: TextInputType.phone,
                      ),
                      _buildModalTextField(
                        isEdit ? 'Kata Sandi Baru (opsional)' : 'Kata Sandi',
                        passC,
                        Icons.lock_outline_rounded,
                        hint: 'Masukkan kata sandi',
                        obscureText: obscure,
                        helperText: isEdit
                            ? 'Kosongkan jika kata sandi tidak diubah.'
                            : 'Minimal 6 karakter. Beritahukan ke staf.',
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 20,
                          ),
                          onPressed: () =>
                              setModalState(() => obscure = !obscure),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: saving
                              ? null
                              : () {
                                  final nipSekarang = nipC.text.trim();
                                  if (nipSekarang.length < 6) {
                                    setModalState(
                                      () => errorText =
                                          'Isi NIP dulu (minimal 6 karakter).',
                                    );
                                    return;
                                  }
                                  if (!isEdit) {
                                    // Staf baru: cukup isi kolom password.
                                    setModalState(() {
                                      passC.text = nipSekarang;
                                      obscure = false;
                                      errorText = null;
                                    });
                                    return;
                                  }
                                  if (nipBerubahSekarang()) {
                                    setModalState(
                                      () => errorText =
                                          'NIP diubah dulu. Simpan perubahan NIP, lalu reset password.',
                                    );
                                    return;
                                  }
                                  resetKeNip();
                                },
                          icon: const Icon(Icons.restart_alt_rounded, size: 18),
                          label: Text(
                            isEdit
                                ? 'Reset password ke NIP sekarang'
                                : 'Isi password sama dengan NIP',
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: _biru,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                        ),
                      ),

                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _biruMuda.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              size: 18,
                              color: _biru,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isEdit
                                    ? 'Staf lupa password? Tekan "Reset password ke NIP sekarang" (langsung tersimpan), atau isi password baru lalu Simpan.'
                                    : 'Staf login memakai NIP dan password yang Anda buat di sini.',
                                style: TextStyle(
                                  fontSize: AppTypography.small,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (errorText != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            errorText!,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: AppTypography.small,
                            ),
                          ),
                        ),

                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: OutlinedButton(
                                onPressed: saving
                                    ? null
                                    : () => Navigator.pop(dialogContext),
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text('Batal'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppPalette.blue,
                                  disabledBackgroundColor: _biru.withOpacity(
                                    0.6,
                                  ),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: saving ? null : save,
                                child: saving
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : Text(
                                        isEdit
                                            ? 'Simpan Perubahan'
                                            : 'Simpan Data Staf',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: AppTypography.body,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Gaya input mengikuti form login: label di atas, field berlatar abu muda
  // dengan border tipis, ikon di kiri, dan hint di dalam field.
  Widget _buildModalTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    String? hint,
    bool enabled = true,
    bool obscureText = false,
    Widget? suffixIcon,
    String? helperText,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    const Color borderColor = Color(0xFFE2E8F0);
    const Color fillColor = AppPalette.background;

    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: c, width: w),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: AppTypography.body,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            enabled: enabled,
            obscureText: obscureText,
            keyboardType: keyboardType,
            textCapitalization: textCapitalization,
            style: const TextStyle(
              fontSize: AppTypography.body,
              color: Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: AppTypography.body,
              ),
              prefixIcon: Icon(icon, size: 22, color: const Color(0xFF64748B)),
              suffixIcon: suffixIcon,
              filled: true,
              fillColor: enabled ? fillColor : Colors.grey.shade200,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 16,
              ),
              enabledBorder: border(borderColor),
              disabledBorder: border(borderColor),
              border: border(borderColor),
              focusedBorder: border(_biru, 1.5),
            ),
          ),
          if (helperText != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(
                helperText,
                style: const TextStyle(
                  fontSize: AppTypography.small,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ===== HAPUS STAF =====
  void _deleteStaff(String docId, String namaStaff) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.delete_outline_rounded,
            color: Colors.redAccent,
            size: 28,
          ),
        ),
        title: const Text('Hapus Staf'),
        content: Text(
          'Yakin ingin menghapus $namaStaff dari daftar staf?',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                // 1. Hapus data profil (dicek aturan Firestore: hanya admin).
                await _firestore.collection('users').doc(docId).delete();
                // 2. Hapus akun login agar NIP yang sama bisa dipakai lagi.
                String? peringatan;
                try {
                  await _deleteStaffAuth(docId);
                } catch (e) {
                  peringatan = _errorMessage(e);
                }
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                _snack(
                  peringatan == null
                      ? '$namaStaff berhasil dihapus'
                      : '$namaStaff dihapus dari daftar, tetapi akun login belum terhapus: $peringatan',
                );
              } catch (e) {
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                _snack('Gagal menghapus staf: ${_errorMessage(e)}');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ===== KOMPONEN UI =====
  Widget _buildSearchBar() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() {
          _searchQuery = v;
          _page = 0;
        }),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Cari nama, NIP, jabatan, atau email...',
          hintStyle: TextStyle(
            color: Colors.grey.shade500,
            fontSize: AppTypography.body,
          ),
          prefixIcon: const Icon(Icons.search_rounded, color: _biru),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                      _page = 0;
                    });
                  },
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  // Tombol tambah staf untuk layar lebar (di samping kolom pencarian).
  Widget _buildAddButton() {
    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        onPressed: () => _showStaffModal(),
        icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
        label: const Text('Tambah Staff'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppPalette.blue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: AppTypography.small,
          ),
        ),
      ),
    );
  }

  // Navigasi halaman: tampilan sama dengan halaman Status Staff.
  Widget _buildPager(int pg, int pages) => Container(
    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Halaman sebelumnya',
          onPressed: pg > 0 ? () => setState(() => _page = pg - 1) : null,
          icon: const Icon(Icons.chevron_left),
          color: Colors.grey.shade700,
          disabledColor: Colors.grey.shade300,
          visualDensity: VisualDensity.compact,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            '${pg + 1} / $pages',
            style: const TextStyle(
              fontSize: AppTypography.body,
              fontWeight: FontWeight.w500,
              color: _biruTua,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Halaman berikutnya',
          onPressed: pg < pages - 1
              ? () => setState(() => _page = pg + 1)
              : null,
          icon: const Icon(Icons.chevron_right),
          color: Colors.grey.shade700,
          disabledColor: Colors.grey.shade300,
          visualDensity: VisualDensity.compact,
        ),
      ],
    ),
  );

  Widget _buildStat(String label, int value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '$value',
                      style: TextStyle(
                        fontSize: AppTypography.section,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Label boleh turun ke baris kedua, tidak dipotong.
            Text(
              label,
              maxLines: 2,
              softWrap: true,
              style: TextStyle(
                fontSize: AppTypography.caption,
                height: 1.2,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade500),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: AppTypography.small,
                color: Colors.grey.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(IconData icon, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _biru.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44, color: _biru),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: AppTypography.section,
                fontWeight: FontWeight.bold,
                color: _biruTua,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: AppTypography.body,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffCard(
    String docId,
    Map<String, dynamic> staff,
    String status,
  ) {
    final String nama = _str(staff['nama'], _str(staff['email'], 'Staf'));
    final String nip = _str(staff['nip'], '-');
    final String jabatan = _str(staff['jabatan'], '-');
    final String emailKontak = _kontakEmailOf(staff);
    final String wa = _phoneOf(staff).isEmpty ? 'Belum diisi' : _phoneOf(staff);
    final bool isTersedia = status.toLowerCase() == 'tersedia';
    final Color statusColor = isTersedia
        ? Colors.green.shade700
        : Colors.orange.shade800;
    final foto = _decodeFoto(staff['foto_base64']);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
            child: Column(
              children: [
                // Avatar + titik status
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: AppPalette.blue,
                      backgroundImage: foto,
                      child: foto == null
                          ? const Icon(
                              Icons.person_rounded,
                              color: Colors.white,
                              size: 34,
                            )
                          : null,
                    ),
                    Positioned(
                      right: 2,
                      bottom: 2,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: isTersedia ? Colors.green : Colors.orange,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  nama,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: AppTypography.body,
                    color: _biruTua,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  jabatan,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: AppTypography.small,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 6),
                _buildInfoRow(Icons.badge_outlined, nip),
                _buildInfoRow(
                  Icons.email_outlined,
                  emailKontak.isEmpty ? 'Belum diisi' : emailKontak,
                ),
                _buildInfoRow(Icons.phone_outlined, wa),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const StatusStaffPage()),
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: AppTypography.small,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Menu Edit / Hapus
          Positioned(
            top: 2,
            right: 2,
            child: PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert_rounded,
                size: 20,
                color: Colors.grey.shade600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onSelected: (value) {
                if (value == 'edit') {
                  _showStaffModal(staffDoc: {'id': docId, ...staff});
                } else {
                  _deleteStaff(docId, nama);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_rounded, size: 18, color: Colors.amber),
                      SizedBox(width: 10),
                      Text('Edit'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'hapus',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_rounded,
                        size: 18,
                        color: Colors.redAccent,
                      ),
                      SizedBox(width: 10),
                      Text('Hapus'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(bool wide) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _usersStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildMessage(
            Icons.error_outline_rounded,
            'Gagal memuat staf',
            '${snapshot.error}',
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _assignmentsStream,
          builder: (context, assignSnap) {
            final assignDocs = assignSnap.data?.docs ?? [];

            final allStaff = (snapshot.data?.docs ?? []).where((doc) {
              final role = (doc.data()['role'] ?? 'staff')
                  .toString()
                  .toLowerCase();
              return role != 'admin';
            }).toList();

            // Status otomatis: tugas aktif >= 5 => Sibuk, selain itu Tersedia.
            final Map<String, String> statusById = {
              for (final d in allStaff)
                d.id:
                    _countActive(d.id, d.data(), assignDocs) >= _maksTugasAktif
                    ? 'Sibuk'
                    : 'Tersedia',
            };

            final total = allStaff.length;
            final tersedia = statusById.values
                .where((st) => st == 'Tersedia')
                .length;

            final query = _searchQuery.trim().toLowerCase();
            final filtered = allStaff.where((doc) {
              final data = doc.data();
              final nama = (data['nama'] ?? '').toString().toLowerCase();
              final nip = (data['nip'] ?? '').toString().toLowerCase();
              final jabatan = (data['jabatan'] ?? '').toString().toLowerCase();
              final email = _kontakEmailOf(data).toLowerCase();
              return query.isEmpty ||
                  nama.contains(query) ||
                  nip.contains(query) ||
                  jabatan.contains(query) ||
                  email.contains(query);
            }).toList();

            // Urutkan nama A-Z (tidak peka huruf besar/kecil). Staf tanpa nama
            // ditaruh paling akhir.
            filtered.sort((a, b) {
              final na = _str(a.data()['nama']).toLowerCase();
              final nb = _str(b.data()['nama']).toLowerCase();
              if (na.isEmpty && nb.isEmpty) return 0;
              if (na.isEmpty) return 1;
              if (nb.isEmpty) return -1;
              return na.compareTo(nb);
            });

            final int totalPages = filtered.isEmpty
                ? 1
                : (filtered.length / _perPage).ceil();
            final int pg = _page.clamp(0, totalPages - 1);
            final shown = filtered.skip(pg * _perPage).take(_perPage).toList();

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Column(
                      children: [
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildStat(
                                'Total Staf',
                                total,
                                Icons.groups_rounded,
                                _biru,
                              ),
                              const SizedBox(width: 10),
                              _buildStat(
                                'Tersedia',
                                tersedia,
                                Icons.check_circle_rounded,
                                Colors.green.shade700,
                              ),
                              const SizedBox(width: 10),
                              _buildStat(
                                'Sibuk',
                                total - tersedia,
                                Icons.timelapse_rounded,
                                Colors.orange.shade800,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        wide
                            ? Row(
                                children: [
                                  Expanded(child: _buildSearchBar()),
                                  const SizedBox(width: 12),
                                  _buildAddButton(),
                                ],
                              )
                            : _buildSearchBar(),
                      ],
                    ),
                  ),
                ),
                if (filtered.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildMessage(
                      query.isEmpty
                          ? Icons.group_off_rounded
                          : Icons.search_off_rounded,
                      query.isEmpty ? 'Belum ada staf' : 'Staf tidak ditemukan',
                      query.isEmpty
                          ? 'Tekan tombol "Tambah Staff" untuk menambahkan.'
                          : 'Coba kata kunci lain.',
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 240,
                            mainAxisExtent: 276,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final doc = shown[index];
                        return _buildStaffCard(
                          doc.id,
                          doc.data(),
                          statusById[doc.id] ?? 'Tersedia',
                        );
                      }, childCount: shown.length),
                    ),
                  ),
                if (filtered.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      // Ruang bawah di HP supaya tidak tertutup tombol melayang.
                      padding: EdgeInsets.fromLTRB(16, 8, 16, wide ? 24 : 96),
                      child: Center(child: _buildPager(pg, totalPages)),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool wide = constraints.maxWidth >= 900;
        return Scaffold(
          backgroundColor: _bg,
          drawer: wide
              ? null
              : const AdminSidebar(currentIndex: 1, isDrawer: true),
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (wide) const AdminSidebar(currentIndex: 1),
              Expanded(
                child: Column(
                  children: [
                    AdminHeader(title: 'Kelola Staff', showSidebar: wide),
                    Expanded(child: _buildContent(wide)),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: wide
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => _showStaffModal(),
                  backgroundColor: AppPalette.blue,
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  icon: const Icon(
                    Icons.person_add_alt_1_rounded,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Tambah Staff',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        );
      },
    );
  }
}
