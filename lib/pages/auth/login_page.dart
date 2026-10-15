import 'package:flutter/material.dart';

import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../admin/dashboard_admin_page.dart';
import '../staff/staff_dashboard.dart';

class AppColors {
  static const Color biruTua = Color(0xFF0D1B2A);
  static const Color biruPrimary = Color(0xFF1E3A8A);
  static const Color biruSedang = Color(0xFF2563EB);
  static const Color cyan = Color(0xFF06B6D4);

  static const Color putih = Colors.white;
  static const Color abuTeks = Color(0xFF64748B);
  static const Color abuHeader = Color(0xFF475569);
  static const Color abuBorder = Color(0xFFE2E8F0);
  static const Color latar = Color(0xFFF8FAFC);
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final FocusNode _passwordFocusNode = FocusNode();
  final AuthService _authService = AuthService();

  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
    });

    try {
      // Autentikasi via Firebase (Mengembalikan Map<String, dynamic>?)
      final userDataMap = await _authService.loginWithEmail(
        email: _identifierController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      // Peta data Map ke UserModel
      UserModel userModel;
      if (userDataMap != null) {
        userModel = UserModel.fromMap(userDataMap);
      } else {
        throw Exception("Data pengguna tidak ditemukan di database.");
      }

      // Navigasi Otomatis Berdasarkan Role pada UserModel
      if (userModel.role.toLowerCase() == 'admin') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardAdminPage()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const StaffDashboardPage()),
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      // Notifikasi Pesan Kesalahan
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _handleForgotPassword() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Fitur reset kata sandi dikirim via link email Firebase.',
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: AppColors.biruPrimary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.latar,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // =================================================
              // HEADER DENGAN GELOMBANG SINOUS (DIBEBRSIHKAN DARI CELA PUTIH)
              // =================================================
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
                clipBehavior:
                    Clip.antiAlias, // Mencegah celah/garis putih di pinggiran
                child: SizedBox(
                  height: 270,
                  width: double.infinity,
                  child: Stack(
                    children: [
                      Container(
                        width: double.infinity,
                        height:
                            270, // Disamakan tingginya agar menutup penuh sampai bawah
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.biruTua,
                              AppColors.biruPrimary,
                              AppColors.biruSedang,
                            ],
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: CustomPaint(painter: _BackgroundWavePainter()),
                      ),
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1.5,
                                  ),
                                ),
                                child: Container(
                                  width: 56,
                                  height: 56,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.lan_outlined,
                                    color: AppColors.biruPrimary,
                                    size: 30,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'SIMTAS',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Sistem Informasi Manajemen Tugas dan Staff',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.85),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // =================================================
              // KARTU ISIAN LOGIN
              // =================================================
              Transform.translate(
                offset: const Offset(0, -30),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF64748B).withOpacity(0.08),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Selamat Datang',
                            style: TextStyle(
                              color: AppColors.biruTua,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Silakan masuk menggunakan NIP dan kata sandi Anda.',
                            style: TextStyle(
                              color: AppColors.abuTeks,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // INPUT EMAIL / NIP
                          const Text(
                            'NIP',
                            style: TextStyle(
                              color: AppColors.abuHeader,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _identifierController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.biruTua,
                            ),
                            decoration: _inputDecoration(
                              hint: 'Masukkan NIP terdaftar',
                              icon: Icons.email_outlined,
                            ),
                            onFieldSubmitted: (_) {
                              FocusScope.of(
                                context,
                              ).requestFocus(_passwordFocusNode);
                            },
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'NIP wajib diisi';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 18),

                          // INPUT KATA SANDI
                          const Text(
                            'Kata Sandi',
                            style: TextStyle(
                              color: AppColors.abuHeader,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _passwordController,
                            focusNode: _passwordFocusNode,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.biruTua,
                            ),
                            onFieldSubmitted: (_) {
                              if (!_isLoading) _handleLogin();
                            },
                            decoration: _inputDecoration(
                              hint: 'Masukkan kata sandi',
                              icon: Icons.lock_outline_rounded,
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: AppColors.abuTeks,
                                  size: 20,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Kata sandi wajib diisi';
                              }
                              return null;
                            },
                          ),

                          // LUPA PASSWORD
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _handleForgotPassword,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.only(
                                  top: 8,
                                  bottom: 8,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Lupa kata sandi?',
                                style: TextStyle(
                                  color: AppColors.biruSedang,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // TOMBOL MASUK
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.biruSedang,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isLoading
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
                                          'Masuk ',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 18,
                                        ),
                                      ],
                                    ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.latar,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.abuBorder),
                            ),
                            child: const Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.verified_user_outlined,
                                  color: AppColors.biruSedang,
                                  size: 18,
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Masuk menggunakan NIP terdaftar. Peran/Role akses ditentukan otomatis oleh sistem.',
                                    style: TextStyle(
                                      color: AppColors.abuTeks,
                                      fontSize: 11.5,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Text(
                  'Dinas Komunikasi dan Informatika',
                  style: TextStyle(
                    color: AppColors.abuTeks.withOpacity(0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.abuTeks, fontSize: 13.5),
      prefixIcon: Icon(icon, color: AppColors.abuTeks, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.latar,
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.abuBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.abuBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.biruSedang, width: 1.5),
      ),
    );
  }
}

class _BackgroundWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.fill;

    final path1 = Path();
    path1.moveTo(0, size.height * 0.7);
    path1.quadraticBezierTo(
      size.width * 0.25,
      size.height * 0.5,
      size.width * 0.5,
      size.height * 0.65,
    );
    path1.quadraticBezierTo(
      size.width * 0.75,
      size.height * 0.8,
      size.width,
      size.height * 0.6,
    );
    path1.lineTo(size.width, 0);
    path1.lineTo(0, 0);
    path1.close();

    canvas.drawPath(path1, paint);

    final paint2 = Paint()
      ..color = AppColors.cyan.withOpacity(0.08)
      ..style = PaintingStyle.fill;

    final path2 = Path();
    path2.moveTo(0, size.height * 0.5);
    path2.quadraticBezierTo(
      size.width * 0.35,
      size.height * 0.75,
      size.width * 0.7,
      size.height * 0.55,
    );
    path2.quadraticBezierTo(
      size.width * 0.85,
      size.height * 0.45,
      size.width,
      size.height * 0.5,
    );
    path2.lineTo(size.width, 0);
    path2.lineTo(0, 0);
    path2.close();

    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
