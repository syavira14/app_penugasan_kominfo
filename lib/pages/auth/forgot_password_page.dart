import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/auth_service.dart';
import 'login_page.dart' show AppColors, BackgroundWavePainter;

/// Halaman Lupa Password sesuai alur Firebase Authentication,
/// dengan layout split-screen (desktop) & header branding SIMTAS (mobile).
class ForgotPasswordPage extends StatefulWidget {
  final String initialNip;
  const ForgotPasswordPage({super.key, this.initialNip = ''});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailC = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _isSent = false;
  String? _successMessage;
  String? _errorMessage;

  @override
  void dispose() {
    _emailC.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final msg = await _authService.forgotPassword(email: _emailC.text);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isSent = true;
        _successMessage = msg;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  InputDecoration _decoration(String hint, IconData icon) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: c, width: w),
    );
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.abuTeks, fontSize: 14),
      prefixIcon: Icon(icon, color: AppColors.abuTeks, size: 20),
      filled: true,
      fillColor: AppColors.latar,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      border: border(AppColors.abuBorder),
      enabledBorder: border(AppColors.abuBorder),
      focusedBorder: border(AppColors.biruSedang, 1.5),
      errorBorder: border(Colors.redAccent),
      focusedErrorBorder: border(Colors.redAccent, 1.5),
    );
  }

  Widget _label(String t) => Text(
    t,
    style: const TextStyle(
      color: AppColors.abuHeader,
      fontSize: 14,
      fontWeight: FontWeight.w600,
    ),
  );

  Widget _notice(String text, Color color, IconData icon) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.4)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: color, fontSize: 13, height: 1.4),
          ),
        ),
      ],
    ),
  );

  Widget _buildSuccessIcon() {
    return Center(
      child: SizedBox(
        width: 88,
        height: 82,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.mail_outline_rounded,
                size: 40,
                color: AppColors.biruSedang,
              ),
            ),
            Positioned(
              bottom: 2,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // KARTU FORM (isi sama untuk mobile & desktop)
  // ---------------------------------------------------------------------
  Widget _buildCard() {
    return Container(
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
      child: _isSent ? _buildSuccessContent() : _buildFormContent(),
    );
  }

  Widget _buildFormContent() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Reset Password',
            style: TextStyle(
              color: AppColors.biruTua,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Masukkan email yang terdaftar pada akun SIMTAS untuk mendapatkan link reset password.',
            style: TextStyle(
              color: AppColors.abuTeks,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          if (_errorMessage != null)
            _notice(
              _errorMessage!,
              Colors.redAccent,
              Icons.error_outline_rounded,
            ),
          _label('Email Terdaftar'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _emailC,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
            style: const TextStyle(fontSize: 14, color: AppColors.biruTua),
            decoration: _decoration(
              'Masukkan email',
              Icons.mail_outline_rounded,
            ),
            onFieldSubmitted: (_) {
              if (!_isLoading) _submit();
            },
            validator: (v) {
              final c = (v ?? '').trim();
              if (c.isEmpty) return 'Email wajib diisi';
              if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(c)) {
                return 'Format email tidak valid';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submit,
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
                        color: Colors.white,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Kirim Link Reset',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.send_rounded, size: 18),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(
                Icons.arrow_back_rounded,
                size: 16,
                color: AppColors.biruSedang,
              ),
              label: const Text(
                'Kembali ke halaman login',
                style: TextStyle(color: AppColors.biruSedang),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildSuccessIcon(),
        const SizedBox(height: 18),
        const Text(
          'Permintaan Berhasil',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.biruTua,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _successMessage ??
              'Link reset password telah dikirimkan ke email Anda. Silakan periksa kotak masuk (inbox) atau folder spam.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.abuTeks,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.biruSedang,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text(
              'Kembali ke Login',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // BRANDING SIMTAS (logo + nama), sama seperti halaman login
  // ---------------------------------------------------------------------
  Widget _buildBrandContent({required bool isDesktop}) {
    final double logoSize = isDesktop ? 110.0 : 70.0;
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
          ),
          child: Container(
            width: logoSize,
            height: logoSize,
            padding: EdgeInsets.all(isDesktop ? 8 : 4),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/logokominfo.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.image_not_supported_rounded,
                  color: AppColors.biruPrimary,
                  size: isDesktop ? 45 : 30,
                ),
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

  Widget _buildGradientBackground({required Widget child}) {
    return Stack(
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
        Positioned.fill(child: CustomPaint(painter: BackgroundWavePainter())),
        Positioned.fill(child: Center(child: child)),
      ],
    );
  }

  Widget _buildFooter() => Center(
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

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        Expanded(
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
                      _buildCard(),
                      const SizedBox(height: 24),
                      _buildFooter(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: _buildGradientBackground(
            child: _buildBrandContent(isDesktop: true),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
            child: SizedBox(
              height: 270,
              width: double.infinity,
              child: _buildGradientBackground(
                child: _buildBrandContent(isDesktop: false),
              ),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -30),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildCard(),
            ),
          ),
          _buildFooter(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.latar,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth > 600
              ? _buildDesktopLayout()
              : _buildMobileLayout(),
        ),
      ),
    );
  }
}
