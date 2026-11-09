import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'package:image_picker/image_picker.dart';

import '/widgets/admin_header.dart';
import '../../models/user_model.dart';
import '../../services/staff_admin_api.dart';
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
  // UBAH DATA PROFIL ADMIN (Nama, Jabatan, NIP, No. HP, Email, Password)
  // Semua kolom dapat diubah dan disimpan untuk mendukung mutasi atasan.
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

    final String nipSaatIni = (currentUser?.nip ?? '').trim();

    final namaC = TextEditingController(text: currentUser?.nama ?? '');
    final nipC = TextEditingController(text: nipSaatIni);
    final emailC = TextEditingController(text: currentUser?.emailKontak ?? '');
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
              final nip = nipC.text.trim();
              final emailKontak = emailC.text.trim();
              final jabatan = jabatanC.text.trim();
              final noHp = noHpC.text.trim();
              final currentPass = currentPassC.text;
              final newPass = newPassC.text;
              final confirmPass = confirmPassC.text;

              final bool nipChanged =
                  nipSaatIni.isNotEmpty && nip != nipSaatIni;
              final bool changingPassword =
                  newPass.isNotEmpty || confirmPass.isNotEmpty;

              String? validate() {
                if (nama.isEmpty) return 'Nama lengkap wajib diisi.';
                if (jabatan.isEmpty) return 'Jabatan wajib diisi.';
                if (nip.isEmpty) return 'NIP wajib diisi.';
                if (!RegExp(r'^[0-9]{6,30}$').hasMatch(nip)) {
                  return 'NIP harus berupa angka 6 sampai 30 digit.';
                }
                if (noHp.length > 30) return 'No. HP maksimal 30 karakter.';
                if (emailKontak.isNotEmpty &&
                    !RegExp(
                      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                    ).hasMatch(emailKontak)) {
                  return 'Format email tidak valid.';
                }
                if ((nipChanged || changingPassword) && currentPass.isEmpty) {
                  return 'Masukkan kata sandi saat ini untuk mengubah NIP atau kata sandi.';
                }
                if (changingPassword) {
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
                await StaffAdminApi.updateAdminProfileAndCredentials(
                  nama: nama,
                  jabatan: jabatan,
                  newNip: nip,
                  noHp: noHp,
                  emailKontak: emailKontak,
                  currentPassword: currentPass,
                  newPassword: changingPassword ? newPass : '',
                );

                if (dialogContext.mounted) Navigator.pop(dialogContext);

                await _fetchUserData();
                _snack(
                  (nipChanged || changingPassword)
                      ? 'Data profil dan akun login berhasil diperbarui'
                      : 'Data profil berhasil diperbarui',
                );
              } on StaffAdminException catch (e) {
                if (ctx.mounted) {
                  setS(() {
                    saving = false;
                    errorText = e.message;
                  });
                }
              } on FirebaseAuthException catch (e) {
                String message = 'Gagal memperbarui kredensial akun.';
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
                                  'Ubah Data Profil Admin',
                                  style: TextStyle(
                                    color: _loginTitle,
                                    fontSize: AppTypography.heading,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Perbarui data diri atau lengkapi data atasan baru.',
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
                                      'NIP (Username Login)',
                                      TextField(
                                        controller: nipC,
                                        keyboardType: TextInputType.number,
                                        textInputAction: TextInputAction.next,
                                        style: const TextStyle(
                                          fontSize: AppTypography.body,
                                          color: _loginTitle,
                                        ),
                                        decoration:
                                            _dec(
                                              'Masukkan NIP',
                                              Icons.badge_outlined,
                                            ).copyWith(
                                              helperText:
                                                  'Ubah jika jabatan atasan diserahkan ke atasan baru',
                                              helperMaxLines: 2,
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
                                  const SizedBox(height: 14),

                                  _labeled(
                                    'Kata Sandi Saat Ini (Wajib diisi jika NIP atau Sandi diubah)',
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
                                  const SizedBox(height: 8),

                                  // Kata sandi baru (dilipat)
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
                                            color: _loginBlue,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 10),
                                          const Expanded(
                                            child: Text(
                                              'Ubah Kata Sandi Baru (Opsional)',
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
                                        'Konfirmasi Kata Sandi Baru',
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
            color: const Color(0xFFEAF3FC),
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
