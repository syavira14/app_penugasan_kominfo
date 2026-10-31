import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/user_model.dart';
import '../auth/login_page.dart';
import 'admin_navbar.dart';

class ProfilAdminPage extends StatefulWidget {
  const ProfilAdminPage({super.key});

  @override
  State<ProfilAdminPage> createState() => _ProfilAdminPageState();
}

class _ProfilAdminPageState extends State<ProfilAdminPage> {
  static const Color blueDark = Color(0xFF1B267B);
  static const Color blueMid = Color(0xFF0066B3);
  static const Color blueLight = Color(0xFF00A8E8);
  static const Color accentGold = Color(0xFFFFC107);
  static const Color bgLight = Color(0xFFF4F8FC);

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
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
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
                    'Pilih Sumber Foto Profil Admin',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt, color: blueMid),
                  title: const Text('Kamera'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndUploadImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library, color: blueMid),
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

      if (user == null) {
        throw Exception('User belum login');
      }

      final Uint8List bytes = await pickedFile.readAsBytes();
      final String fotoBase64 = base64Encode(bytes);

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'foto_base64': fotoBase64,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _fetchUserData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto profil admin berhasil diperbarui!'),
          ),
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

    final emailController = TextEditingController(
      text: user.email ?? currentUser?.email ?? '',
    );
    final noHpController = TextEditingController(text: currentUser?.noHp ?? '');
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    bool obscureCurrentPassword = true;
    bool obscureNewPassword = true;
    bool obscureConfirmPassword = true;

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
                      controller: emailController,
                      enabled: false,
                      decoration: InputDecoration(
                        labelText: 'Email (Tidak dapat diubah)',
                        prefixIcon: const Icon(Icons.email_outlined),
                        disabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: noHpController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'No. HP / WhatsApp',
                        prefixIcon: const Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
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
                          color: blueMid,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: currentPasswordController,
                      obscureText: obscureCurrentPassword,
                      decoration: InputDecoration(
                        labelText: 'Kata Sandi Saat Ini',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
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
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: newPasswordController,
                      obscureText: obscureNewPassword,
                      decoration: InputDecoration(
                        labelText: 'Kata Sandi Baru',
                        prefixIcon: const Icon(Icons.lock_reset_outlined),
                        suffixIcon: IconButton(
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
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: confirmPasswordController,
                      obscureText: obscureConfirmPassword,
                      decoration: InputDecoration(
                        labelText: 'Konfirmasi Kata Sandi Baru',
                        prefixIcon: const Icon(Icons.lock_reset_outlined),
                        suffixIcon: IconButton(
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
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Kosongkan bagian kata sandi jika tidak ingin mengubahnya.',
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
                  onPressed: () {
                    Navigator.of(dialogContext, rootNavigator: true).pop();
                  },
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: blueMid,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    final newNoHp = noHpController.text.trim();
                    final currentPassword = currentPasswordController.text
                        .trim();
                    final newPassword = newPasswordController.text.trim();
                    final confirmPassword = confirmPasswordController.text
                        .trim();

                    final bool isChangingPassword =
                        newPassword.isNotEmpty || confirmPassword.isNotEmpty;

                    if (isChangingPassword) {
                      if (currentPassword.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Masukkan kata sandi saat ini.'),
                          ),
                        );
                        return;
                      }

                      if (newPassword.length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Kata sandi baru minimal 6 karakter.',
                            ),
                          ),
                        );
                        return;
                      }

                      if (newPassword != confirmPassword) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Konfirmasi kata sandi tidak cocok.'),
                          ),
                        );
                        return;
                      }
                    }

                    try {
                      if (isChangingPassword) {
                        final credential = EmailAuthProvider.credential(
                          email: user.email!,
                          password: currentPassword,
                        );

                        await user.reauthenticateWithCredential(credential);
                        await user.updatePassword(newPassword);
                      }

                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .set({
                            'no_hp': newNoHp,
                            'updated_at': FieldValue.serverTimestamp(),
                          }, SetOptions(merge: true));

                      await _fetchUserData();

                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext, rootNavigator: true).pop();
                      }

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Informasi berhasil diperbarui!'),
                          ),
                        );
                      }
                    } on FirebaseAuthException catch (e) {
                      if (mounted) {
                        String message = 'Gagal memperbarui kata sandi.';
                        if (e.code == 'wrong-password' ||
                            e.code == 'invalid-credential') {
                          message = 'Kata sandi saat ini salah.';
                        } else if (e.code == 'weak-password') {
                          message = 'Kata sandi terlalu lemah.';
                        } else if (e.code == 'requires-recent-login') {
                          message = 'Silakan login ulang terlebih dahulu.';
                        }
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(message)));
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Terjadi kesalahan: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('Simpan'),
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
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final scale = (screenWidth / 375).clamp(0.85, 1.25);

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: blueMid)),
      );
    }

    return Scaffold(
      backgroundColor: bgLight,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipPath(
              clipper: HeaderCurveClipper(),
              child: Container(
                height: screenHeight * 0.38,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [blueLight, blueMid, blueDark],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: -30,
                      right: -20,
                      child: CircleAvatar(
                        radius: 80,
                        backgroundColor: Colors.white.withOpacity(0.05),
                      ),
                    ),
                    Positioned(
                      top: 40,
                      left: -40,
                      child: CircleAvatar(
                        radius: 60,
                        backgroundColor: accentGold.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16 * scale,
                    vertical: 10 * scale,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      ),
                      Text(
                        'Profil Saya',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20 * scale,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                        onPressed: () {
                          _showMoreMenu(context);
                        },
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 8 * scale),

                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20 * scale),
                      child: Column(
                        children: [
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
                                            color: Colors.black.withOpacity(
                                              0.1,
                                            ),
                                            blurRadius: 10,
                                            offset: const Offset(0, 5),
                                          ),
                                        ],
                                      ),
                                      child: CircleAvatar(
                                        radius: 50 * scale,
                                        backgroundColor: blueMid,
                                        child: _isUploading
                                            ? const CircularProgressIndicator(
                                                color: Colors.white,
                                              )
                                            : _buildProfileImage(scale),
                                      ),
                                    ),
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: GestureDetector(
                                        onTap: _isUploading ? null : _gantiFoto,
                                        child: Container(
                                          padding: EdgeInsets.all(9 * scale),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: blueMid,
                                              width: 2,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.camera_alt_outlined,
                                            color: blueMid,
                                            size: 19 * scale,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12 * scale),
                                Text(
                                  currentUser?.nama.isNotEmpty == true
                                      ? currentUser!.nama
                                      : 'Administrator',
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
                                      : 'Administrator SIMTAS',
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
                          SizedBox(height: 24 * scale),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'INFORMASI AKUN',
                              style: TextStyle(
                                fontSize: 13 * scale,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          SizedBox(height: 10 * scale),
                          Container(
                            padding: EdgeInsets.all(16 * scale),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22 * scale),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 15,
                                  offset: const Offset(0, 6),
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
                                Divider(
                                  height: 22 * scale,
                                  color: Colors.grey.shade200,
                                ),
                                _buildProfileItem(
                                  icon: Icons.email_outlined,
                                  title: 'Email',
                                  value: currentUser?.email.isNotEmpty == true
                                      ? currentUser!.email
                                      : '-',
                                  scale: scale,
                                ),
                                Divider(
                                  height: 22 * scale,
                                  color: Colors.grey.shade200,
                                ),
                                _buildProfileItem(
                                  icon: Icons.phone_outlined,
                                  title: 'No. HP / WhatsApp',
                                  value: currentUser?.noHp.isNotEmpty == true
                                      ? currentUser!.noHp
                                      : '-',
                                  scale: scale,
                                ),
                                Divider(
                                  height: 22 * scale,
                                  color: Colors.grey.shade200,
                                ),
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
                          SizedBox(height: 30 * scale),
                          SizedBox(
                            width: double.infinity,
                            height: 52 * scale,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFEBEE),
                                foregroundColor: Colors.red.shade700,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    16 * scale,
                                  ),
                                ),
                              ),
                              onPressed: () async {
                                await FirebaseAuth.instance.signOut();

                                if (context.mounted) {
                                  Navigator.pushAndRemoveUntil(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const LoginPage(),
                                    ),
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
                          SizedBox(height: 20 * scale),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AdminBottomNavigationBar(currentIndex: 4),
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
          foregroundColor: blueMid,
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
          child: Icon(icon, color: blueMid, size: 22 * scale),
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

  void _showMoreMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Tentang SIMTAS'),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class HeaderCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final h = size.height;
    final w = size.width;

    path.lineTo(0, h * 0.75);
    final controlPoint = Offset(w / 2, h);
    final endPoint = Offset(w, h * 0.75);

    path.quadraticBezierTo(
      controlPoint.dx,
      controlPoint.dy,
      endPoint.dx,
      endPoint.dy,
    );

    path.lineTo(w, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
