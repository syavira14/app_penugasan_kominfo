import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../admin/dashboard_admin_page.dart' hide AppColors;
import '../staff/staff_dashboard_page.dart' hide AppColors;

/// ============================================================
/// LOGIN PAGE — Sistem Penjadwalan Penugasan Pegawai
/// Dinas Komunikasi dan Informatika
/// ============================================================
/// Konsisten secara visual dengan Welcome Page:
///   - Palet warna resmi tetap: #0011CC / #0066FF / #00CCFF
///   - Motif "gelombang sinyal" sebagai signature element
///   - Kartu putih melengkung untuk area form
///
/// CATATAN:
/// Tidak ada tombol "Daftar" karena akun pegawai dibuat/didaftarkan
/// oleh admin Dinas Kominfo (bukan self-registration publik).
/// ============================================================

class AppColors {
  static const Color biruTua = Color(0xFF0011CC);
  static const Color biruSedang = Color(0xFF0066FF);
  static const Color cyan = Color(0xFF00CCFF);
  static const Color putih = Colors.white;
  static const Color abuTeks = Color(0xFF5A6472);
  static const Color abuBorder = Color(0xFFE1E5F0);
}

enum LoginRole { admin, staff }

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  LoginRole _selectedRole = LoginRole.staff;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      // TODO: ganti dengan proses autentikasi sesungguhnya (cek ke API/backend)
      Future.delayed(const Duration(seconds: 1), () {
        if (!mounted) return;
        setState(() => _isLoading = false);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => _selectedRole == LoginRole.admin
                ? const DashboardAdminPage()
                : const StaffDashboardPage(),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.putih,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ================= HEADER (gradient) =================
            Container(
              width: double.infinity,
              height: 240,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.biruTua,
                    AppColors.biruSedang,
                    AppColors.cyan,
                  ],
                  stops: [0.0, 0.6, 1.0],
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: CustomPaint(painter: _SignalWavePainter()),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          color: AppColors.putih,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.biruTua.withOpacity(0.35),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(14),
                        child: Image.asset(
                          'assets/images/logo_kominfo.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                Icons.podcasts_rounded,
                                size: 40,
                                color: AppColors.biruTua,
                              ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Masuk ke Akun',
                        style: TextStyle(
                          color: AppColors.putih,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Sistem Penjadwalan Penugasan Pegawai',
                        style: TextStyle(color: Colors.white70, fontSize: 12.5),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ================= FORM (kartu putih) =================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
              decoration: const BoxDecoration(
                color: AppColors.putih,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x1A0011CC),
                    blurRadius: 20,
                    offset: Offset(0, -6),
                  ),
                ],
              ),
              transform: Matrix4.translationValues(0, -24, 0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      alignment: Alignment.center,
                      width: double.infinity,
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.cyan.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ---------- USERNAME / NIP ----------
                    const Text(
                      'Username / NIP',
                      style: TextStyle(
                        color: AppColors.biruTua,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _usernameController,
                      decoration: _inputDecoration(
                        hint: 'Masukkan username atau NIP',
                        icon: Icons.badge_outlined,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Username / NIP wajib diisi';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // ---------- ROLE LOGIN ----------
                    const Text(
                      'Masuk Sebagai',
                      style: TextStyle(
                        color: AppColors.biruTua,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _RoleOption(
                            label: 'Staff',
                            icon: Icons.badge_outlined,
                            selected: _selectedRole == LoginRole.staff,
                            onTap: () =>
                                setState(() => _selectedRole = LoginRole.staff),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _RoleOption(
                            label: 'Admin',
                            icon: Icons.admin_panel_settings_outlined,
                            selected: _selectedRole == LoginRole.admin,
                            onTap: () =>
                                setState(() => _selectedRole = LoginRole.admin),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ---------- PASSWORD ----------
                    const Text(
                      'Kata Sandi',
                      style: TextStyle(
                        color: AppColors.biruTua,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: _inputDecoration(
                        hint: 'Masukkan kata sandi',
                        icon: Icons.lock_outline_rounded,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: AppColors.abuTeks,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(
                              () => _obscurePassword = !_obscurePassword,
                            );
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Kata sandi wajib diisi';
                        }
                        return null;
                      },
                    ),

                    // ---------- LUPA KATA SANDI ----------
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          // TODO: arahkan ke halaman reset kata sandi
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 36),
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
                    const SizedBox(height: 12),

                    // ---------- TOMBOL MASUK ----------
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.biruTua,
                          foregroundColor: AppColors.putih,
                          disabledBackgroundColor: AppColors.biruTua
                              .withOpacity(0.6),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.putih,
                                  ),
                                ),
                              )
                            : const Text(
                                'Masuk',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ---------- CATATAN KEAMANAN ----------
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.cyan.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.cyan.withOpacity(0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: AppColors.biruSedang,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Akun hanya dapat digunakan oleh pegawai terdaftar. '
                              'Hubungi admin Dinas Kominfo jika belum memiliki akun.',
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
          ],
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
      prefixIcon: Icon(icon, color: AppColors.biruSedang, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF7F8FC),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
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
        borderSide: const BorderSide(color: AppColors.biruSedang, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _RoleOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.biruTua.withOpacity(0.08)
              : const Color(0xFFF7F8FC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.biruSedang : AppColors.abuBorder,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: selected ? AppColors.biruSedang : AppColors.abuTeks,
              size: 18,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? AppColors.biruTua : AppColors.abuTeks,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Motif gelombang sinyal — sama seperti di Welcome Page,
/// dibuat lebih ringkas karena area header lebih kecil.
class _SignalWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.4);
    final paint = Paint()
      ..color = AppColors.putih.withOpacity(0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(center, 60.0 * i, paint);
    }

    final accentPaint = Paint()
      ..color = AppColors.cyan.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(size.width + 10, -10), radius: 120),
      math.pi / 2,
      math.pi / 2,
      false,
      accentPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
