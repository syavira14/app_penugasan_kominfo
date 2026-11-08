import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/user_model.dart';
import '../../widgets/app_layout.dart';
import '../auth/login_page.dart';

class StaffProfilPage extends StatefulWidget {
  const StaffProfilPage({super.key});

  @override
  State<StaffProfilPage> createState() => _StaffProfilPageState();
}

class _StaffProfilPageState extends State<StaffProfilPage> {
  static const Color kBiruTua = Color(0xFF1A1464);
  static const Color kBiruSedang = Color(0xFF1D5FA0);
  static const Color kBiruMuda = Color(0xFF4FA6DE);
  static const Color kBgLight = Color(0xFFF7F9FB);

  UserModel? currentUser;

  bool _isLoading = true;
  bool _isUploading = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    try {
      var doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        // Sinkronkan email di Firestore jika email Auth sudah berubah
        // (setelah verifikasi email baru).
        try {
          await user.reload();
        } catch (_) {}
        final authEmail = FirebaseAuth.instance.currentUser?.email ?? '';
        final docEmail = (doc.data()?['email'] ?? '').toString();
        if (authEmail.isNotEmpty && authEmail != docEmail) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({'email': authEmail}, SetOptions(merge: true));
          doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
        }

        if (mounted) {
          setState(() {
            currentUser = UserModel.fromFirestore(doc);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal memuat profil: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _gantiFoto() {
    showModalBottomSheet(
      context: context,
      constraints: const BoxConstraints(maxWidth: 640),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Wrap(
              children: [
                const ListTile(
                  title: Text(
                    'Pilih Sumber Foto Profil',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt, color: kBiruSedang),
                  title: const Text('Kamera'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndUploadImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library, color: kBiruSedang),
                  title: const Text('Galeri Foto'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndUploadImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
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

      if (mounted) {
        setState(() {
          _isUploading = true;
        });
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User belum login');

      final Uint8List bytes = await pickedFile.readAsBytes();
      final String fotoBase64 = base64Encode(bytes);

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'foto_base64': fotoBase64,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _fetchUserData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto profil berhasil diperbarui!')),
        );
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Firebase error: ${e.message ?? e.code}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal menyimpan foto: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _editProfil() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final String emailLama = user.email ?? currentUser?.email ?? '';

    final namaController = TextEditingController(text: currentUser?.nama ?? '');
    final nipController = TextEditingController(text: currentUser?.nip ?? '');
    final emailController = TextEditingController(text: emailLama);
    final noHpController = TextEditingController(text: currentUser?.noHp ?? '');
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    bool obscureCurrentPassword = true;
    bool obscureNewPassword = true;
    bool obscureConfirmPassword = true;
    bool isSaving = false;

    InputDecoration dekorasi(String label, IconData icon, {Widget? suffix}) {
      return InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      );
    }

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                'Ubah Informasi',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: namaController,
                      textCapitalization: TextCapitalization.words,
                      decoration: dekorasi(
                        'Nama Lengkap',
                        Icons.person_outline,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: nipController,
                      keyboardType: TextInputType.number,
                      decoration: dekorasi('NIP', Icons.badge_outlined),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: dekorasi('Email', Icons.email_outlined),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: noHpController,
                      keyboardType: TextInputType.phone,
                      decoration: dekorasi(
                        'No. HP / WhatsApp',
                        Icons.phone_outlined,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Ubah Kata Sandi',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: kBiruSedang,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: currentPasswordController,
                      obscureText: obscureCurrentPassword,
                      decoration: dekorasi(
                        'Kata Sandi Saat Ini',
                        Icons.lock_outline,
                        suffix: IconButton(
                          icon: Icon(
                            obscureCurrentPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              obscureCurrentPassword = !obscureCurrentPassword;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: newPasswordController,
                      obscureText: obscureNewPassword,
                      decoration: dekorasi(
                        'Kata Sandi Baru',
                        Icons.lock_reset_outlined,
                        suffix: IconButton(
                          icon: Icon(
                            obscureNewPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              obscureNewPassword = !obscureNewPassword;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: confirmPasswordController,
                      obscureText: obscureConfirmPassword,
                      decoration: dekorasi(
                        'Konfirmasi Kata Sandi Baru',
                        Icons.lock_reset_outlined,
                        suffix: IconButton(
                          icon: Icon(
                            obscureConfirmPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              obscureConfirmPassword = !obscureConfirmPassword;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Kosongkan bagian kata sandi jika tidak ingin mengubahnya. '
                        'Kata sandi saat ini wajib diisi jika mengubah email atau kata sandi.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () {
                          Navigator.of(
                            dialogContext,
                            rootNavigator: true,
                          ).pop();
                        },
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kBiruSedang,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          final messenger = ScaffoldMessenger.of(context);

                          final newNama = namaController.text.trim();
                          final newNip = nipController.text.trim();
                          final newEmail = emailController.text.trim();
                          final newNoHp = noHpController.text.trim();
                          final currentPassword = currentPasswordController.text
                              .trim();
                          final newPassword = newPasswordController.text.trim();
                          final confirmPassword = confirmPasswordController.text
                              .trim();

                          final bool isChangingPassword =
                              newPassword.isNotEmpty ||
                              confirmPassword.isNotEmpty;
                          final bool isChangingEmail =
                              newEmail.toLowerCase() != emailLama.toLowerCase();

                          if (newNama.isEmpty) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Nama tidak boleh kosong.'),
                              ),
                            );
                            return;
                          }

                          if (newEmail.isEmpty ||
                              !RegExp(
                                r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                              ).hasMatch(newEmail)) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Format email tidak valid.'),
                              ),
                            );
                            return;
                          }

                          if ((isChangingPassword || isChangingEmail) &&
                              currentPassword.isEmpty) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Masukkan kata sandi saat ini untuk mengubah email atau kata sandi.',
                                ),
                              ),
                            );
                            return;
                          }

                          if (isChangingPassword) {
                            if (newPassword.length < 6) {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Kata sandi baru minimal 6 karakter.',
                                  ),
                                ),
                              );
                              return;
                            }

                            if (newPassword != confirmPassword) {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Konfirmasi kata sandi tidak cocok.',
                                  ),
                                ),
                              );
                              return;
                            }
                          }

                          setDialogState(() => isSaving = true);

                          try {
                            if (isChangingPassword || isChangingEmail) {
                              final credential = EmailAuthProvider.credential(
                                email: emailLama,
                                password: currentPassword,
                              );
                              await user.reauthenticateWithCredential(
                                credential,
                              );
                            }

                            if (isChangingPassword) {
                              await user.updatePassword(newPassword);
                            }

                            // Email baru baru aktif setelah diverifikasi lewat
                            // link yang dikirim ke email baru.
                            if (isChangingEmail) {
                              await user.verifyBeforeUpdateEmail(newEmail);
                            }

                            // Email di Firestore TIDAK diubah di sini; akan
                            // disinkronkan otomatis di _fetchUserData setelah
                            // email baru diverifikasi.
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(user.uid)
                                .set({
                                  'nama': newNama,
                                  'nip': newNip,
                                  'no_hp': newNoHp,
                                  'updated_at': FieldValue.serverTimestamp(),
                                }, SetOptions(merge: true));

                            await _fetchUserData();

                            if (dialogContext.mounted) {
                              Navigator.of(
                                dialogContext,
                                rootNavigator: true,
                              ).pop();
                            }

                            if (mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isChangingEmail
                                        ? 'Informasi diperbarui. Cek email baru Anda untuk verifikasi perubahan email.'
                                        : 'Informasi berhasil diperbarui!',
                                  ),
                                ),
                              );
                            }
                          } on FirebaseAuthException catch (e) {
                            String message = 'Gagal memperbarui informasi.';
                            if (e.code == 'wrong-password' ||
                                e.code == 'invalid-credential') {
                              message = 'Kata sandi saat ini salah.';
                            } else if (e.code == 'weak-password') {
                              message = 'Kata sandi terlalu lemah.';
                            } else if (e.code == 'requires-recent-login') {
                              message = 'Silakan login ulang terlebih dahulu.';
                            } else if (e.code == 'email-already-in-use') {
                              message = 'Email sudah dipakai akun lain.';
                            } else if (e.code == 'invalid-email') {
                              message = 'Format email tidak valid.';
                            } else if (e.code == 'too-many-requests') {
                              message =
                                  'Terlalu banyak percobaan. Coba lagi nanti.';
                            }
                            messenger.showSnackBar(
                              SnackBar(content: Text(message)),
                            );
                          } catch (e) {
                            messenger.showSnackBar(
                              SnackBar(content: Text('Terjadi kesalahan: $e')),
                            );
                          } finally {
                            if (dialogContext.mounted) {
                              setDialogState(() => isSaving = false);
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Simpan'),
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
    final double screenWidth = MediaQuery.of(context).size.width;
    final double scale = (screenWidth / 375).clamp(0.85, 1.25);
    final bool isWide = screenWidth >= 900;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: kBiruSedang)),
      );
    }

    final List<Widget> kolomProfil = [
      Center(
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  padding: EdgeInsets.all(4 * scale),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 50 * scale,
                    backgroundColor: kBiruSedang,
                    child: _isUploading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : _buildProfileImage(scale),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12 * scale),
            Text(
              currentUser?.nama.isNotEmpty == true
                  ? currentUser!.nama
                  : 'Tanpa Nama',
              style: TextStyle(
                fontSize: 20 * scale,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 4 * scale),
            Text(
              currentUser?.jabatan.isNotEmpty == true
                  ? currentUser!.jabatan
                  : '-',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13 * scale,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      SizedBox(height: 24 * scale),
      Row(
        children: [
          Expanded(
            child: _buildActionButton(
              icon: Icons.camera_alt_outlined,
              title: 'Ganti Foto',
              onTap: _isUploading ? () {} : _gantiFoto,
              scale: scale,
            ),
          ),
          SizedBox(width: 10 * scale),
          Expanded(
            child: _buildActionButton(
              icon: Icons.edit_outlined,
              title: 'Ubah Info',
              onTap: _editProfil,
              scale: scale,
            ),
          ),
        ],
      ),
    ];

    final List<Widget> kolomInfo = [
      Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'INFORMASI AKUN',
          style: TextStyle(
            fontSize: 13 * scale,
            fontWeight: FontWeight.bold,
            color: kBiruTua,
            letterSpacing: 0.5,
          ),
        ),
      ),
      SizedBox(height: 10 * scale),
      Container(
        padding: EdgeInsets.all(16 * scale),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20 * scale),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildProfileItem(
              icon: Icons.badge_outlined,
              title: 'NIP',
              value: currentUser?.nip.isNotEmpty == true
                  ? currentUser!.nip
                  : '-',
              scale: scale,
            ),
            Divider(height: 22 * scale, color: Colors.grey.shade200),
            _buildProfileItem(
              icon: Icons.email_outlined,
              title: 'Email',
              value: currentUser?.email.isNotEmpty == true
                  ? currentUser!.email
                  : '-',
              scale: scale,
            ),
            Divider(height: 22 * scale, color: Colors.grey.shade200),
            _buildProfileItem(
              icon: Icons.phone_outlined,
              title: 'No. HP / WhatsApp',
              value: currentUser?.noHp.isNotEmpty == true
                  ? currentUser!.noHp
                  : '-',
              scale: scale,
            ),
            Divider(height: 22 * scale, color: Colors.grey.shade200),
            _buildProfileItem(
              icon: Icons.work_outline,
              title: 'Jabatan',
              value: currentUser?.jabatan.isNotEmpty == true
                  ? currentUser!.jabatan
                  : '-',
              scale: scale,
            ),
          ],
        ),
      ),
    ];

    final List<Widget> kolomKeluar = [
      SizedBox(
        width: double.infinity,
        height: 52 * scale,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFEBEE),
            foregroundColor: Colors.red.shade700,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16 * scale),
            ),
          ),
          onPressed: () async {
            await FirebaseAuth.instance.signOut();

            if (context.mounted) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (_) => false,
              );
            }
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout, size: 20 * scale),
              SizedBox(width: 8 * scale),
              Text(
                'KELUAR',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14 * scale,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    ];

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

          // CONTENT
          Expanded(
            child: ResponsiveContent(
              child: Padding(
                padding: EdgeInsets.fromLTRB(0, 16 * scale, 0, 12 * scale),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 4,
                              child: Column(children: kolomProfil),
                            ),
                            SizedBox(width: 32 * scale),
                            Expanded(
                              flex: 6,
                              child: Column(
                                children: [
                                  ...kolomInfo,
                                  SizedBox(height: 30 * scale),
                                  ...kolomKeluar,
                                ],
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            ...kolomProfil,
                            SizedBox(height: 24 * scale),
                            ...kolomInfo,
                            SizedBox(height: 30 * scale),
                            ...kolomKeluar,
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

  Widget _buildProfileImage(double scale) {
    final String fotoBase64 = currentUser?.fotoBase64 ?? '';

    if (fotoBase64.isEmpty) {
      return Icon(Icons.person, size: 55 * scale, color: Colors.white);
    }

    try {
      final Uint8List imageBytes = base64Decode(fotoBase64);

      return ClipOval(
        child: Image.memory(
          imageBytes,
          width: 100 * scale,
          height: 100 * scale,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Icon(Icons.person, size: 55 * scale, color: Colors.white);
          },
        ),
      );
    } catch (e) {
      return Icon(Icons.person, size: 55 * scale, color: Colors.white);
    }
  }

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required double scale,
  }) {
    return SizedBox(
      height: 82 * scale,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: kBiruSedang,
          elevation: 0,
          padding: EdgeInsets.symmetric(vertical: 10 * scale),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16 * scale),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 25 * scale),
            SizedBox(height: 6 * scale),
            Text(
              title,
              style: TextStyle(
                fontSize: 11 * scale,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileItem({
    required IconData icon,
    required String title,
    required String value,
    required double scale,
  }) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(10 * scale),
          decoration: BoxDecoration(
            color: const Color(0xFFE3EEFA),
            borderRadius: BorderRadius.circular(12 * scale),
          ),
          child: Icon(icon, color: kBiruSedang, size: 22 * scale),
        ),
        SizedBox(width: 14 * scale),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 11 * scale,
                  color: Colors.grey.shade500,
                ),
              ),
              SizedBox(height: 3 * scale),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14 * scale,
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
