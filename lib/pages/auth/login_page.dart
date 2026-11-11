import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  final GlobalKey<FormFieldState<String>> _nipFieldKey =
      GlobalKey<FormFieldState<String>>();
  final GlobalKey<FormFieldState<String>> _passwordFieldKey =
      GlobalKey<FormFieldState<String>>();

  bool _obscurePassword = true;
  bool _isLoading = false;

  // Pesan error dari server (ditampilkan di bawah field, bukan snackbar).
  String? _nipServerError;
  String? _passwordServerError;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    // Bersihkan error server sebelumnya sebelum validasi ulang.
    _nipServerError = null;
    _passwordServerError = null;

    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    // Hapus pesan error lama supaya tidak terbawa ke halaman berikutnya.
    ScaffoldMessenger.of(context).clearSnackBars();

    setState(() {
      _isLoading = true;
    });

    try {
      final userDataMap = await _authService.loginWithEmail(
        email: _identifierController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      UserModel userModel;
      if (userDataMap != null) {
        userModel = UserModel.fromMap(userDataMap);
      } else {
        throw Exception("Data pengguna tidak ditemukan di database.");
      }

      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).clearSnackBars();

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

      final message = e.toString().replaceAll('Exception: ', '');
      final lower = message.toLowerCase();

      if (lower.contains('kata sandi salah')) {
        // Termasuk "NIP atau kata sandi salah." -> tampil di field kata sandi.
        _passwordServerError = 'Kata sandi salah';
        _passwordFieldKey.currentState?.validate();
        _passwordFocusNode.requestFocus();
      } else if (lower.contains('nip tidak terdaftar')) {
        _nipServerError = message;
        _nipFieldKey.currentState?.validate();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.latar,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 600) {
              return _buildDesktopLayout();
            } else {
              return _buildMobileLayout();
            }
          },
        ),
      ),
    );
  }

  // =========================================================================
  // LAYOUT MOBILE
  // =========================================================================
  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildHeader(isDesktop: false),
          _buildLoginFormCard(isDesktop: false),
          const SizedBox(height: 16),
          _buildFooter(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // =========================================================================
  // LAYOUT DESKTOP (Split Screen)
  // =========================================================================
  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // 1. Bagian Kiri: Form Login (Latar Putih)
        Expanded(
          flex: 1,
          child: Container(
            color: AppColors.latar,
            height: double.infinity,
            padding: const EdgeInsets.all(40),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLoginFormCard(isDesktop: true),
                      const SizedBox(height: 24),
                      _buildFooter(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // 2. Bagian Kanan: Banner / Branding SIMTAS (Latar Biru)
        Expanded(
          flex: 1,
          child: Container(
            height: double.infinity,
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
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: _BackgroundWavePainter()),
                ),
                Center(child: _buildHeaderContent(isDesktop: true)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // WIDGET REUSABLE: HEADER
  // =========================================================================
  Widget _buildHeader({required bool isDesktop}) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(32),
        bottomRight: Radius.circular(32),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: isDesktop ? double.infinity : 270,
        width: double.infinity,
        child: Stack(
          children: [
            Container(
              width: double.infinity,
              height: double.infinity,
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
                child: Center(child: _buildHeaderContent(isDesktop: isDesktop)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderContent({required bool isDesktop}) {
    final double logoSize = isDesktop ? 110.0 : 70.0;
    final double iconPadding = isDesktop ? 8.0 : 4.0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: EdgeInsets.all(isDesktop ? 12 : 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withOpacity(0.35),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Container(
            width: logoSize,
            height: logoSize,
            padding: EdgeInsets.all(iconPadding),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/logokominfo.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.image_not_supported_rounded,
                    color: AppColors.biruPrimary,
                    size: isDesktop ? 45 : 30,
                  );
                },
              ),
            ),
          ),
        ),
        SizedBox(height: isDesktop ? 16 : 8),
        Text(
          'SIMTAS',
          style: TextStyle(
            color: Colors.white,
            fontSize: isDesktop ? 26 : 20,
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
            fontSize: isDesktop ? 13.5 : 11,
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // WIDGET REUSABLE: KARTU FORM LOGIN
  // =========================================================================
  Widget _buildLoginFormCard({required bool isDesktop}) {
    Widget cardContent = Container(
      padding: const EdgeInsets.all(28),
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
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Silakan masuk menggunakan NIP dan kata sandi Anda.',
              style: TextStyle(color: AppColors.abuTeks, fontSize: 14),
            ),
            const SizedBox(height: 28),

            // INPUT NIP (Hanya NIP angka, menolak input email/@gmail.com)
            _buildInputLabel('NIP'),
            const SizedBox(height: 8),
            TextFormField(
              key: _nipFieldKey,
              controller: _identifierController,
              onChanged: (_) {
                if (_nipServerError != null) {
                  _nipServerError = null;
                  _nipFieldKey.currentState?.validate();
                }
              },
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.deny(RegExp(r'\s')),
              ],
              textInputAction: TextInputAction.next,
              style: const TextStyle(fontSize: 14, color: AppColors.biruTua),
              decoration: _inputDecoration(
                hint: 'Masukkan NIP terdaftar',
                icon: Icons.badge_outlined,
              ),
              onFieldSubmitted: (_) {
                FocusScope.of(context).requestFocus(_passwordFocusNode);
              },
              validator: (value) {
                final clean = (value ?? '').trim();
                if (clean.isEmpty) {
                  return 'NIP wajib diisi';
                }
                if (clean.contains('@') ||
                    !RegExp(r'^[0-9]+$').hasMatch(clean)) {
                  return 'Masuk hanya menggunakan NIP (angka), bukan email';
                }
                return _nipServerError;
              },
            ),

            const SizedBox(height: 20),

            // INPUT KATA SANDI
            _buildInputLabel('Kata Sandi'),
            const SizedBox(height: 8),
            TextFormField(
              key: _passwordFieldKey,
              controller: _passwordController,
              focusNode: _passwordFocusNode,
              onChanged: (_) {
                if (_passwordServerError != null) {
                  _passwordServerError = null;
                  _passwordFieldKey.currentState?.validate();
                }
              },
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              style: const TextStyle(fontSize: 14, color: AppColors.biruTua),
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
                return _passwordServerError;
              },
            ),

            const SizedBox(height: 24),

            // TOMBOL MASUK
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 37, 99, 235),
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
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Masuk ',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 24),

            // INFO BOX
            Container(
              padding: const EdgeInsets.all(14),
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
                    size: 20,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Masuk menggunakan NIP terdaftar. Peran/Role akses ditentukan otomatis oleh sistem.',
                      style: TextStyle(
                        color: AppColors.abuTeks,
                        fontSize: 12.5,
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
    );

    if (isDesktop) {
      return cardContent;
    } else {
      return Transform.translate(
        offset: const Offset(0, -30),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: cardContent,
        ),
      );
    }
  }

  Widget _buildInputLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: AppColors.abuHeader,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildFooter() {
    return Center(
      child: Text(
        'Dinas Komunikasi dan Informatika',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.abuTeks.withOpacity(0.8),
          fontSize: 12,
          fontWeight: FontWeight.w500,
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
      hintStyle: const TextStyle(color: AppColors.abuTeks, fontSize: 14),
      prefixIcon: Icon(icon, color: AppColors.abuTeks, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.latar,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
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
