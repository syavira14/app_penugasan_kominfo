import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'package:image_picker/image_picker.dart';

import '/widgets/admin_header.dart';
import '../../models/user_model.dart';
import '../auth/login_page.dart';
import 'admin_sidebar.dart';

class ProfilAdminPage extends StatefulWidget {
  const ProfilAdminPage({super.key});

  @override
  State<ProfilAdminPage> createState() => _ProfilAdminPageState();
}

class _ProfilAdminPageState extends State<ProfilAdminPage> {
  static const Color blueDark = AppPalette.navy;
  static const Color blueMid = AppPalette.blue;
  static const Color blueLight = AppPalette.sky;
  static const Color bgLight = AppPalette.background;

  // Index "Profil Admin" di AdminSidebar
  static const int _sidebarIndex = 7;
  static const double _sidebarBreakpoint = 900;

  UserModel? currentUser;

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

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists && mounted) {
        setState(() => currentUser = UserModel.fromFirestore(doc));
      }
    } catch (e) {
      _snack('Gagal memuat profil: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ===========================================================
  // FOTO PROFIL
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
                Icon(Icons.camera_alt_rounded, color: blueMid),
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
                Icon(Icons.photo_library_rounded, color: blueMid),
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

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
            'foto_base64': base64Encode(bytes),
            'updated_at': FieldValue.serverTimestamp(),
          });

      await _fetchUserData();
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
  // UBAH DATA (nama, NIP, jabatan, no HP, password)
  // Gaya form disamakan dengan kartu di halaman login.
  // ===========================================================
  static const Color _loginTitle = AppPalette.navy;
  static const Color _loginBlue = AppPalette.blue;
  static const Color _abuTeks = Color(0xFF64748B);
  static const Color _abuHeader = Color(0xFF475569);
  static const Color _abuBorder = Color(0xFFE2E8F0);
  static const Color _latar = AppPalette.background;

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
      fillColor: _latar,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      border: border(_abuBorder),
      enabledBorder: border(_abuBorder),
      focusedBorder: border(_loginBlue, 1.5),
    );
  }

  // Label di atas kolom, seperti di halaman login.
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

  // Dua kolom berdampingan di layar lebar, satu kolom di layar sempit.
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

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: AppTypography.small,
        fontWeight: FontWeight.w700,
        color: _abuTeks,
        letterSpacing: 0.8,
      ),
    );
  }

  Future<void> _editProfil() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final String oldNip = (currentUser?.nip ?? '').trim();

    final namaC = TextEditingController(text: currentUser?.nama ?? '');
    final nipC = TextEditingController(text: oldNip);
    final jabatanC = TextEditingController(text: currentUser?.jabatan ?? '');
    final noHpC = TextEditingController(text: currentUser?.noHp ?? '');
    final currentPassC = TextEditingController();
    final newPassC = TextEditingController();
    final confirmPassC = TextEditingController();

    bool showPassword = false; // bagian kata sandi dilipat dulu
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
              final nip = nipC.text.trim();
              final jabatan = jabatanC.text.trim();
              final noHp = noHpC.text.trim();
              final currentPass = currentPassC.text;
              final newPass = newPassC.text;
              final confirmPass = confirmPassC.text;

              final bool nipChanged = nip != oldNip;
              final bool changingPassword =
                  currentPass.isNotEmpty ||
                  newPass.isNotEmpty ||
                  confirmPass.isNotEmpty;

              String? validate() {
                if (nama.isEmpty) return 'Nama wajib diisi.';
                if (jabatan.isEmpty) return 'Jabatan wajib diisi.';
                if (noHp.length > 30) return 'No. HP maksimal 30 karakter.';
                if (nipChanged && !RegExp(r'^[0-9]{6,30}$').hasMatch(nip)) {
                  return 'NIP harus angka, 6 sampai 30 digit.';
                }
                if (changingPassword) {
                  if (currentPass.isEmpty) {
                    return 'Masukkan kata sandi saat ini.';
                  }
                  if (newPass.length < 6) {
                    return 'Kata sandi baru minimal 6 karakter.';
                  }
                  if (newPass != confirmPass) {
                    return 'Konfirmasi kata sandi tidak cocok.';
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

              final messenger = ScaffoldMessenger.of(context);

              try {
                // 1. Kata sandi (butuh verifikasi sandi lama)
                if (changingPassword) {
                  final credential = EmailAuthProvider.credential(
                    email: user.email!,
                    password: currentPass,
                  );
                  await user.reauthenticateWithCredential(credential);
                  await user.updatePassword(newPass);
                }

                // 2. Nama, jabatan, no HP
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .update({
                      'nama': nama,
                      'jabatan': jabatan,
                      'no_hp': noHp,
                      'updated_at': FieldValue.serverTimestamp(),
                    });

                // 3. NIP = username login, jadi email login ikut diganti
                //    lewat Cloud Function (butuh Admin SDK).
                if (nipChanged) {
                  await FirebaseFunctions.instance
                      .httpsCallable('changeOwnNip')
                      .call({'nip': nip});
                }

                if (dialogContext.mounted) Navigator.pop(dialogContext);

                if (nipChanged) {
                  // Sesi lama tidak berlaku lagi setelah login berubah.
                  await FirebaseAuth.instance.signOut();
                  messenger
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      const SnackBar(
                        content: Text(
                          'NIP diperbarui. Silakan masuk dengan NIP baru.',
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  if (mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                      (_) => false,
                    );
                  }
                } else {
                  await _fetchUserData();
                  _snack(
                    changingPassword
                        ? 'Data dan kata sandi berhasil diperbarui'
                        : 'Data berhasil diperbarui',
                  );
                }
              } on FirebaseAuthException catch (e) {
                String message = 'Gagal memperbarui kata sandi.';
                if (e.code == 'wrong-password' ||
                    e.code == 'invalid-credential') {
                  message = 'Kata sandi saat ini salah.';
                } else if (e.code == 'weak-password') {
                  message = 'Kata sandi terlalu lemah.';
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
              } on FirebaseFunctionsException catch (e) {
                final message = (e.code == 'not-found')
                    ? 'Fungsi changeOwnNip belum di-deploy.'
                    : (e.message ?? e.code);
                if (ctx.mounted) {
                  setS(() {
                    saving = false;
                    errorText =
                        'Data lain tersimpan, tetapi NIP gagal diubah: $message';
                  });
                }
                await _fetchUserData();
              } on FirebaseException catch (e) {
                final message = e.code == 'permission-denied'
                    ? 'Ditolak aturan Firestore. Pastikan firestore.rules terbaru sudah dipublish.'
                    : (e.message ?? e.code);
                if (ctx.mounted) {
                  setS(() {
                    saving = false;
                    errorText = message;
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
                                    color: _loginTitle,
                                    fontSize: AppTypography.heading,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Perbarui informasi akun Anda.',
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

                      // Isi form (bisa di-scroll di layar pendek)
                      Flexible(
                        child: SingleChildScrollView(
                          child: LayoutBuilder(
                            builder: (context, c) {
                              final bool two = c.maxWidth >= 460;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _sectionTitle('DATA DIRI'),
                                  const SizedBox(height: 12),
                                  _twoCols(
                                    two,
                                    _labeled(
                                      'Nama Lengkap',
                                      TextField(
                                        controller: namaC,
                                        textCapitalization:
                                            TextCapitalization.words,
                                        textInputAction: TextInputAction.next,
                                        style: const TextStyle(
                                          fontSize: AppTypography.body,
                                          color: _loginTitle,
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
                                        textCapitalization:
                                            TextCapitalization.words,
                                        textInputAction: TextInputAction.next,
                                        style: const TextStyle(
                                          fontSize: AppTypography.body,
                                          color: _loginTitle,
                                        ),
                                        decoration: _dec(
                                          'Masukkan jabatan',
                                          Icons.work_outline_rounded,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _twoCols(
                                    two,
                                    _labeled(
                                      'NIP (username login)',
                                      TextField(
                                        controller: nipC,
                                        keyboardType: TextInputType.number,
                                        textInputAction: TextInputAction.next,
                                        style: const TextStyle(
                                          fontSize: AppTypography.body,
                                          color: _loginTitle,
                                        ),
                                        decoration: _dec(
                                          'Masukkan NIP',
                                          Icons.badge_outlined,
                                        ),
                                      ),
                                    ),
                                    _labeled(
                                      'No. HP / WhatsApp',
                                      TextField(
                                        controller: noHpC,
                                        keyboardType: TextInputType.phone,
                                        style: const TextStyle(
                                          fontSize: AppTypography.body,
                                          color: _loginTitle,
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
                                  const SizedBox(height: 6),

                                  // Kata sandi (dilipat)
                                  InkWell(
                                    borderRadius: BorderRadius.circular(10),
                                    onTap: saving
                                        ? null
                                        : () => setS(() {
                                            showPassword = !showPassword;
                                            if (!showPassword) {
                                              currentPassC.clear();
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
                                            Icons.lock_outline_rounded,
                                            color: _loginBlue,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 10),
                                          const Expanded(
                                            child: Text(
                                              'Ubah kata sandi',
                                              style: TextStyle(
                                                color: _loginBlue,
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
                                    _labeled(
                                      'Kata Sandi Saat Ini',
                                      TextField(
                                        controller: currentPassC,
                                        obscureText: obscureCurrent,
                                        textInputAction: TextInputAction.next,
                                        style: const TextStyle(
                                          fontSize: AppTypography.body,
                                          color: _loginTitle,
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
                                    const SizedBox(height: 16),
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
                                            color: _loginTitle,
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
                                        'Konfirmasi Kata Sandi',
                                        TextField(
                                          controller: confirmPassC,
                                          obscureText: obscureConfirm,
                                          style: const TextStyle(
                                            fontSize: AppTypography.body,
                                            color: _loginTitle,
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

                                  // Kotak info, gaya sama dengan halaman login
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: _latar,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: _abuBorder),
                                    ),
                                    child: const Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.verified_user_outlined,
                                          color: _loginBlue,
                                          size: 20,
                                        ),
                                        SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            'Jika NIP diubah, Anda akan keluar dan harus masuk ulang dengan NIP baru.',
                                            style: TextStyle(
                                              color: _abuTeks,
                                              fontSize: AppTypography.small,
                                              height: 1.4,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

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

                      // Tombol
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
                                  backgroundColor: AppPalette.blue,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: _loginBlue
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
  // BUILD
  // ===========================================================
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool wide = constraints.maxWidth >= _sidebarBreakpoint;
        return Scaffold(
          backgroundColor: bgLight,
          drawer: wide
              ? null
              : const AdminSidebar(currentIndex: _sidebarIndex, isDrawer: true),
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (wide) const AdminSidebar(currentIndex: _sidebarIndex),
              Expanded(
                child: Column(
                  children: [
                    AdminHeader(title: 'Profil Admin', showSidebar: wide),
                    Expanded(
                      child: _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(color: blueMid),
                            )
                          : _buildBody(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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
              // Kartu profil
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
                              colors: [blueLight, blueDark],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: AppPalette.blue,
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
                                color: blueMid,
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
                          : 'Administrator',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: AppTypography.heading,
                        fontWeight: FontWeight.bold,
                        color: blueDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (user?.jabatan.isNotEmpty ?? false)
                          ? user!.jabatan
                          : 'Administrator SIMTAS',
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
                              foregroundColor: blueMid,
                              side: const BorderSide(color: blueMid),
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
                              backgroundColor: AppPalette.blue,
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
            color: const Color(0xFFE3EEFA),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: blueMid, size: 22),
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
