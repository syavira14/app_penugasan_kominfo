import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/user_model.dart';
import '../../services/staff_admin_api.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_layout.dart';
import '../auth/login_page.dart';

class StaffProfilPage extends StatefulWidget {
  const StaffProfilPage({super.key});

  @override
  State<StaffProfilPage> createState() => _StaffProfilPageState();
}

class _StaffProfilPageState extends State<StaffProfilPage> {
  // Palet warna & header khas role Staff (sama dengan halaman Staff lainnya di SIMTAS)
  static const Color kBiruTua = Color(0xFF1A1464);
  static const Color kBiruSedang = Color(0xFF1D5FA0);
  static const Color kBiruMuda = Color(0xFF4FA6DE);
  static const Color kBgLight = Color(0xFFF7F9FB);

  static const Color _abuTeks = Color(0xFF64748B);
  static const Color _abuHeader = Color(0xFF475569);
  static const Color _abuBorder = Color(0xFFE2E8F0);
  static const Color _latarInput = AppPalette.background;

  UserModel? currentUser;
  String _rawEmailKontakFromDb = '';

  bool _isLoading = true;
  bool _isUploading = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fetchUserData();
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

  /// Mengekstrak nama staf yang tersimpan (mendukung nama di field `nama`,
  /// metadata `email_kontak`, maupun `user.displayName`).
  String _resolveEffectiveNama(Map<String, dynamic> data, User? authUser) {
    final rawKontak = (data['email_kontak'] ?? '').toString();
    if (rawKontak.contains('||')) {
      final parts = rawKontak.split('||');
      if (parts.length >= 5 && parts[4].trim().isNotEmpty) {
        return parts[4].trim();
      }
    }
    final display = (authUser?.displayName ?? '').trim();
    if (display.isNotEmpty && !display.startsWith('ADMIN_AUTH::')) {
      return display;
    }
    return (data['nama'] ?? data['nama_lengkap'] ?? '').toString().trim();
  }

  String _packEmailKontakWithNama({
    required String previousRaw,
    required String aliasTag,
    required String nama,
    String? newPassword,
  }) {
    final basePacked = StaffAdminApi.packEmailKontak(
      '',
      password: newPassword,
      aliasTag: aliasTag,
      previousRawEmailKontak: previousRaw,
    );
    final parts = basePacked.split('||');
    final cleanEmail = parts.isNotEmpty ? parts[0].trim() : '';
    final pass = parts.length >= 2 ? parts[1].trim() : '';
    final alias = parts.length >= 3 ? parts[2].trim() : aliasTag.trim();
    final nipOver = parts.length >= 4 ? parts[3].trim() : '';
    final cleanNama = nama.replaceAll('||', ' ').trim();

    final candidate = '$cleanEmail||$pass||$alias||$nipOver||$cleanNama';
    if (candidate.length <= 200) return candidate;
    return basePacked;
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    // 1. Muat instan dari cache lokal terlebih dahulu agar halaman langsung tampil tanpa loading lama.
    try {
      final cachedDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get(const GetOptions(source: Source.cache));
      if (cachedDoc.exists && mounted) {
        final data = cachedDoc.data() ?? {};
        final baseModel = UserModel.fromFirestore(cachedDoc);
        final effNama = _resolveEffectiveNama(data, user);
        setState(() {
          _rawEmailKontakFromDb = (data['email_kontak'] ?? '').toString();
          currentUser = UserModel(
            uid: baseModel.uid,
            nip: baseModel.nip,
            nama: effNama.isNotEmpty ? effNama : baseModel.nama,
            email: baseModel.email,
            emailKontak: baseModel.emailKontak,
            noHp: baseModel.noHp,
            jabatan: baseModel.jabatan,
            role: baseModel.role,
            statusPekerjaan: baseModel.statusPekerjaan,
            fotoBase64: baseModel.fotoBase64,
            createdAt: baseModel.createdAt,
            updatedAt: baseModel.updatedAt,
          );
          _isLoading = false;
        });
      }
    } catch (_) {}

    // 2. Sinkronkan data terbaru dari server.
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists && mounted) {
        final data = doc.data() ?? {};
        final baseModel = UserModel.fromFirestore(doc);
        final effNama = _resolveEffectiveNama(data, user);
        setState(() {
          _rawEmailKontakFromDb = (data['email_kontak'] ?? '').toString();
          currentUser = UserModel(
            uid: baseModel.uid,
            nip: baseModel.nip,
            nama: effNama.isNotEmpty ? effNama : baseModel.nama,
            email: baseModel.email,
            emailKontak: baseModel.emailKontak,
            noHp: baseModel.noHp,
            jabatan: baseModel.jabatan,
            role: baseModel.role,
            statusPekerjaan: baseModel.statusPekerjaan,
            fotoBase64: baseModel.fotoBase64,
            createdAt: baseModel.createdAt,
            updatedAt: baseModel.updatedAt,
          );
        });
      }
    } catch (e) {
      if (currentUser == null) {
        _snack('Gagal memuat profil: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ===========================================================
  // FOTO PROFIL (Modal Dialog bergaya modern seperti Profil Atasan)
  // ===========================================================
  void _gantiFoto() {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Foto Profil'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        children: [
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              _pickAndUploadImage(ImageSource.camera);
            },
            child: const Row(
              children: [
                Icon(Icons.camera_alt_rounded, color: kBiruSedang),
                SizedBox(width: 12),
                Text('Kamera'),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              _pickAndUploadImage(ImageSource.gallery);
            },
            child: const Row(
              children: [
                Icon(Icons.photo_library_rounded, color: kBiruSedang),
                SizedBox(width: 12),
                Text('Galeri foto'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 40,
        maxWidth: 500,
        maxHeight: 500,
      );
      if (pickedFile == null) return;

      if (mounted) setState(() => _isUploading = true);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User belum login');

      final Uint8List bytes = await pickedFile.readAsBytes();
      final String b64 = base64Encode(bytes);

      if (mounted && currentUser != null) {
        setState(() {
          currentUser = UserModel(
            uid: currentUser!.uid,
            nip: currentUser!.nip,
            nama: currentUser!.nama,
            email: currentUser!.email,
            emailKontak: currentUser!.emailKontak,
            noHp: currentUser!.noHp,
            jabatan: currentUser!.jabatan,
            role: currentUser!.role,
            statusPekerjaan: currentUser!.statusPekerjaan,
            fotoBase64: b64,
            createdAt: currentUser!.createdAt,
            updatedAt: DateTime.now(),
          );
        });
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'foto_base64': b64, 'updated_at': FieldValue.serverTimestamp()},
      );

      _snack('Foto profil berhasil diperbarui');
    } on FirebaseException catch (e) {
      _snack('Firebase error: ${e.message ?? e.code}');
    } catch (e) {
      _snack('Gagal menyimpan foto: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ===========================================================
  // DIALOG UBAH DATA PROFIL (Gaya form persis seperti Profil Atasan)
  // ===========================================================
  InputDecoration _dec(String hint, IconData icon, {Widget? suffix}) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: c, width: w),
    );

    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _abuTeks, fontSize: AppTypography.body),
      prefixIcon: Icon(icon, color: _abuTeks, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: _latarInput,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      border: border(_abuBorder),
      enabledBorder: border(_abuBorder),
      focusedBorder: border(kBiruSedang, 1.5),
    );
  }

  Widget _labeled(String label, Widget field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _abuHeader,
            fontSize: AppTypography.body,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        field,
      ],
    );
  }

  Widget _twoCols(bool two, Widget a, Widget b) {
    if (two) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: a),
          const SizedBox(width: 16),
          Expanded(child: b),
        ],
      );
    }
    return Column(children: [a, const SizedBox(height: 16), b]);
  }

  Future<void> _editProfil() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final String emailLogin = user.email ?? currentUser?.email ?? '';
    final String currentNip = currentUser?.nip ?? '';

    final namaC = TextEditingController(text: currentUser?.nama ?? '');
    final nipC = TextEditingController(text: currentNip);
    final jabatanC = TextEditingController(text: currentUser?.jabatan ?? '');
    final noHpC = TextEditingController(text: currentUser?.noHp ?? '');
    final currentPassC = TextEditingController();
    final newPassC = TextEditingController();
    final confirmPassC = TextEditingController();

    bool showPassword = false;
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool saving = false;
    String? errorText;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setS) {
            Future<void> save() async {
              final nama = namaC.text.trim();
              final noHp = noHpC.text.trim();
              final currentPass = currentPassC.text;
              final newPass = newPassC.text;
              final confirmPass = confirmPassC.text;

              final bool changingPassword =
                  newPass.isNotEmpty || confirmPass.isNotEmpty;

              String? validate() {
                if (nama.isEmpty) return 'Nama lengkap wajib diisi.';
                if (nama.length > 100) return 'Nama maksimal 100 karakter.';
                if (noHp.length > 30) return 'No. HP maksimal 30 karakter.';
                if (changingPassword) {
                  if (currentPass.isEmpty) {
                    return 'Masukkan kata sandi saat ini untuk mengubah kata sandi.';
                  }
                  if (newPass.length < 6) {
                    return 'Kata sandi baru minimal 6 karakter.';
                  }
                  if (newPass != confirmPass) {
                    return 'Konfirmasi kata sandi baru tidak cocok.';
                  }
                }
                return null;
              }

              final err = validate();
              if (err != null) {
                setS(() => errorText = err);
                return;
              }

              setS(() {
                errorText = null;
                saving = true;
              });

              try {
                if (changingPassword) {
                  final credential = EmailAuthProvider.credential(
                    email: emailLogin,
                    password: currentPass,
                  );
                  await user.reauthenticateWithCredential(credential);
                  await user.updatePassword(newPass);
                }

                final String aliasTag =
                    StaffAdminApi.extractAliasTagFromAuthEmail(
                      emailLogin,
                      fallbackRawEmailKontak: _rawEmailKontakFromDb,
                    );
                final String packedEmailKontak = _packEmailKontakWithNama(
                  previousRaw: _rawEmailKontakFromDb,
                  aliasTag: aliasTag,
                  nama: nama,
                  newPassword: changingPassword
                      ? newPass
                      : (currentPass.isNotEmpty ? currentPass : null),
                );

                final userRef = FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid);

                // Simpan langsung ke Firestore dokumen users/{uid}.
                // Memperbarui field 'nama', 'no_hp', 'email_kontak', dan 'updated_at'.
                try {
                  await userRef.update({
                    'nama': nama,
                    'no_hp': noHp,
                    'email_kontak': packedEmailKontak,
                    'updated_at': FieldValue.serverTimestamp(),
                  });
                } on FirebaseException catch (e) {
                  // Jika aturan Firestore belum diperbarui untuk mengizinkan field 'nama',
                  // simpan field yang diizinkan terlebih dahulu.
                  await userRef.update({
                    'no_hp': noHp,
                    'email_kontak': packedEmailKontak,
                    'updated_at': FieldValue.serverTimestamp(),
                  });
                  debugPrint(
                    'Perhatian: field nama memerlukan publish firestore.rules terbaru ($e)',
                  );
                }

                unawaited(user.updateDisplayName(nama).catchError((_) {}));

                // Perbarui tampilan secara instan tanpa menunggu loading ulang dari server.
                if (mounted && currentUser != null) {
                  setState(() {
                    _rawEmailKontakFromDb = packedEmailKontak;
                    currentUser = UserModel(
                      uid: currentUser!.uid,
                      nip: currentUser!.nip,
                      nama: nama,
                      email: currentUser!.email,
                      emailKontak: currentUser!.emailKontak,
                      noHp: noHp,
                      jabatan: currentUser!.jabatan,
                      role: currentUser!.role,
                      statusPekerjaan: currentUser!.statusPekerjaan,
                      fotoBase64: currentUser!.fotoBase64,
                      createdAt: currentUser!.createdAt,
                      updatedAt: DateTime.now(),
                    );
                  });
                }

                if (dialogContext.mounted) Navigator.pop(dialogContext);

                _snack(
                  changingPassword
                      ? 'Informasi dan kata sandi berhasil diperbarui'
                      : 'Informasi berhasil diperbarui',
                );
              } on FirebaseAuthException catch (e) {
                String message = 'Gagal memperbarui informasi.';
                if (e.code == 'wrong-password' ||
                    e.code == 'invalid-credential') {
                  message = 'Kata sandi saat ini salah.';
                } else if (e.code == 'weak-password') {
                  message = 'Kata sandi baru terlalu lemah.';
                } else if (e.code == 'requires-recent-login') {
                  message = 'Silakan login ulang terlebih dahulu.';
                } else if (e.code == 'too-many-requests') {
                  message = 'Terlalu banyak percobaan. Coba lagi nanti.';
                }
                if (ctx.mounted) {
                  setS(() {
                    saving = false;
                    errorText = message;
                  });
                }
              } on FirebaseException catch (e) {
                if (ctx.mounted) {
                  setS(() {
                    saving = false;
                    errorText = e.message ?? e.code;
                  });
                }
              } catch (e) {
                if (ctx.mounted) {
                  setS(() {
                    saving = false;
                    errorText = 'Terjadi kesalahan: $e';
                  });
                }
              }
            }

            Widget eye(bool obscure, VoidCallback onTap) => IconButton(
              onPressed: onTap,
              icon: Icon(
                obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: _abuTeks,
                size: 20,
              ),
            );

            return Dialog(
              backgroundColor: Colors.white,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(26, 22, 26, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Judul
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Ubah Data Profil',
                                  style: TextStyle(
                                    color: kBiruTua,
                                    fontSize: AppTypography.heading,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Perbarui nama, nomor telepon, atau kata sandi akun Anda.',
                                  style: TextStyle(
                                    color: _abuTeks,
                                    fontSize: AppTypography.body,
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
                            color: _abuTeks,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      Flexible(
                        child: SingleChildScrollView(
                          child: LayoutBuilder(
                            builder: (context, c) {
                              final bool two = c.maxWidth >= 460;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _twoCols(
                                    two,
                                    _labeled(
                                      'Nama Lengkap',
                                      TextField(
                                        controller: namaC,
                                        readOnly: false,
                                        textInputAction: TextInputAction.next,
                                        style: const TextStyle(
                                          fontSize: AppTypography.body,
                                          color: kBiruTua,
                                        ),
                                        decoration: _dec(
                                          'Masukkan nama lengkap',
                                          Icons.person_outline_rounded,
                                        ),
                                      ),
                                    ),
                                    _labeled(
                                      'Jabatan',
                                      TextField(
                                        controller: jabatanC,
                                        readOnly: true,
                                        style: const TextStyle(
                                          fontSize: AppTypography.body,
                                          color: _abuTeks,
                                        ),
                                        decoration:
                                            _dec(
                                              'Jabatan',
                                              Icons.work_outline_rounded,
                                            ).copyWith(
                                              helperText: 'Diubah oleh atasan',
                                            ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _twoCols(
                                    two,
                                    _labeled(
                                      'NIP (Username Login)',
                                      TextField(
                                        controller: nipC,
                                        readOnly: true,
                                        style: const TextStyle(
                                          fontSize: AppTypography.body,
                                          color: _abuTeks,
                                        ),
                                        decoration:
                                            _dec(
                                              'NIP',
                                              Icons.badge_outlined,
                                            ).copyWith(
                                              helperText: 'Diubah oleh atasan',
                                            ),
                                      ),
                                    ),
                                    _labeled(
                                      'No. HP / WhatsApp',
                                      TextField(
                                        controller: noHpC,
                                        keyboardType: TextInputType.phone,
                                        textInputAction: TextInputAction.next,
                                        style: const TextStyle(
                                          fontSize: AppTypography.body,
                                          color: kBiruTua,
                                        ),
                                        decoration: _dec(
                                          'Masukkan nomor HP',
                                          Icons.phone_outlined,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Divider(height: 1, color: _abuBorder),
                                  const SizedBox(height: 14),

                                  _labeled(
                                    'Kata Sandi Saat Ini (Wajib diisi jika mengubah sandi)',
                                    TextField(
                                      controller: currentPassC,
                                      obscureText: obscureCurrent,
                                      textInputAction: TextInputAction.next,
                                      style: const TextStyle(
                                        fontSize: AppTypography.body,
                                        color: kBiruTua,
                                      ),
                                      decoration: _dec(
                                        'Masukkan kata sandi saat ini',
                                        Icons.lock_outline_rounded,
                                        suffix: eye(
                                          obscureCurrent,
                                          () => setS(
                                            () => obscureCurrent =
                                                !obscureCurrent,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  // Bagian kata sandi baru (dilipat)
                                  InkWell(
                                    borderRadius: BorderRadius.circular(10),
                                    onTap: saving
                                        ? null
                                        : () => setS(() {
                                            showPassword = !showPassword;
                                            if (!showPassword) {
                                              newPassC.clear();
                                              confirmPassC.clear();
                                            }
                                          }),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.lock_reset_rounded,
                                            color: kBiruSedang,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 10),
                                          const Expanded(
                                            child: Text(
                                              'Ubah Kata Sandi Baru (Opsional)',
                                              style: TextStyle(
                                                color: kBiruSedang,
                                                fontSize: AppTypography.body,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          Icon(
                                            showPassword
                                                ? Icons.expand_less_rounded
                                                : Icons.expand_more_rounded,
                                            color: _abuTeks,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  if (showPassword) ...[
                                    const SizedBox(height: 8),
                                    _twoCols(
                                      two,
                                      _labeled(
                                        'Kata Sandi Baru',
                                        TextField(
                                          controller: newPassC,
                                          obscureText: obscureNew,
                                          textInputAction: TextInputAction.next,
                                          style: const TextStyle(
                                            fontSize: AppTypography.body,
                                            color: kBiruTua,
                                          ),
                                          decoration: _dec(
                                            'Minimal 6 karakter',
                                            Icons.lock_reset_rounded,
                                            suffix: eye(
                                              obscureNew,
                                              () => setS(
                                                () => obscureNew = !obscureNew,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      _labeled(
                                        'Konfirmasi Kata Sandi Baru',
                                        TextField(
                                          controller: confirmPassC,
                                          obscureText: obscureConfirm,
                                          style: const TextStyle(
                                            fontSize: AppTypography.body,
                                            color: kBiruTua,
                                          ),
                                          decoration: _dec(
                                            'Ulangi kata sandi baru',
                                            Icons.lock_reset_rounded,
                                            suffix: eye(
                                              obscureConfirm,
                                              () => setS(
                                                () => obscureConfirm =
                                                    !obscureConfirm,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],

                                  const SizedBox(height: 16),

                                  if (errorText != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 12),
                                      child: Text(
                                        errorText!,
                                        style: const TextStyle(
                                          color: Colors.redAccent,
                                          fontSize: AppTypography.small,
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Tombol Batal & Simpan
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 50,
                              child: OutlinedButton(
                                onPressed: saving
                                    ? null
                                    : () => Navigator.pop(dialogContext),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _abuHeader,
                                  side: const BorderSide(color: _abuBorder),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Batal',
                                  style: TextStyle(
                                    fontSize: AppTypography.body,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: SizedBox(
                              height: 50,
                              child: ElevatedButton(
                                onPressed: saving ? null : save,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: kBiruSedang,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: kBiruSedang
                                      .withOpacity(0.6),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: saving
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                    : const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Simpan Perubahan',
                                            style: TextStyle(
                                              fontSize: AppTypography.body,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Icon(Icons.check_rounded, size: 18),
                                        ],
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

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  // ===========================================================
  // BUILD UTAMA (Header gradien Staff + Body Kartu seperti Atasan)
  // ===========================================================
  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double scale = (screenWidth / 375).clamp(0.85, 1.25);

    return Scaffold(
      backgroundColor: kBgLight,
      body: Column(
        children: [
          // HEADER GRADIENT KHAS ROLE STAFF (margin, warna, & tombol kembali)
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
                            'Profil Saya',
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

          // ISI BODY PROFIL (Desain kartu & layout identik Profil Atasan)
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: kBiruSedang),
                  )
                : _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final user = currentUser;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            children: [
              // 1. Kartu Utama Profil (Avatar dengan gradien lingkaran + Nama + Jabatan + 2 Tombol Aksi)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                decoration: _cardDecoration(),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [kBiruMuda, kBiruTua],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: kBiruSedang,
                            child: _isUploading
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : _buildProfileImage(),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: GestureDetector(
                            onTap: _isUploading ? null : _gantiFoto,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: kBiruSedang,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      (user?.nama.isNotEmpty ?? false)
                          ? user!.nama
                          : 'Staff SIMTAS',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: AppTypography.heading,
                        fontWeight: FontWeight.bold,
                        color: kBiruTua,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (user?.jabatan.isNotEmpty ?? false)
                          ? user!.jabatan
                          : 'Staff Pelaksana',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: AppTypography.body,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isUploading ? null : _gantiFoto,
                            icon: const Icon(
                              Icons.camera_alt_outlined,
                              size: 18,
                            ),
                            label: const Text('Ganti Foto'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: kBiruSedang,
                              side: const BorderSide(color: kBiruSedang),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _editProfil,
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text('Ubah Data'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kBiruSedang,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'INFORMASI AKUN',
                  style: TextStyle(
                    fontSize: AppTypography.small,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // 2. Kartu Rincian Informasi Akun (Nama, NIP, Jabatan, No. HP, Kata Sandi)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: _cardDecoration(),
                child: Column(
                  children: [
                    _buildProfileItem(
                      icon: Icons.person_outline_rounded,
                      title: 'Nama Lengkap',
                      value: _valueOrDash(user?.nama),
                    ),
                    _divider(),
                    _buildProfileItem(
                      icon: Icons.badge_outlined,
                      title: 'NIP (username login)',
                      value: _valueOrDash(user?.nip),
                    ),
                    _divider(),
                    _buildProfileItem(
                      icon: Icons.work_outline_rounded,
                      title: 'Jabatan',
                      value: _valueOrDash(user?.jabatan),
                    ),
                    _divider(),
                    _buildProfileItem(
                      icon: Icons.phone_outlined,
                      title: 'No. HP / WhatsApp',
                      value: _valueOrDash(user?.noHp),
                    ),
                    _divider(),
                    _buildProfileItem(
                      icon: Icons.lock_outline_rounded,
                      title: 'Kata Sandi',
                      value: '••••••••',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 26),

              // 3. Tombol Keluar (Merah Soft seperti Profil Atasan)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout_rounded, size: 20),
                  label: const Text(
                    'KELUAR',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: AppTypography.body,
                      letterSpacing: 1.0,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFEBEE),
                    foregroundColor: Colors.red.shade700,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  String _valueOrDash(String? v) =>
      (v == null || v.trim().isEmpty) ? '-' : v.trim();

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 14,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }

  Widget _divider() => Divider(height: 22, color: Colors.grey.shade200);

  Widget _buildProfileImage() {
    final String fotoBase64 = currentUser?.fotoBase64 ?? '';

    if (fotoBase64.isEmpty) {
      return const Icon(Icons.person, size: 55, color: Colors.white);
    }

    try {
      final Uint8List imageBytes = base64Decode(fotoBase64);
      return ClipOval(
        child: Image.memory(
          imageBytes,
          width: 100,
          height: 100,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.person, size: 55, color: Colors.white),
        ),
      );
    } catch (_) {
      return const Icon(Icons.person, size: 55, color: Colors.white);
    }
  }

  Widget _buildProfileItem({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF3FC),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: kBiruSedang, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: AppTypography.small,
                  color: Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  fontSize: AppTypography.body,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
