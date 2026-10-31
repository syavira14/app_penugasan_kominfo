import 'package:flutter/material.dart';

class AppColors {
  static const Color biruTua = Color(0xFF0D1B2A);
  static const Color biruPrimary = Color(0xFF1E3A8A);
  static const Color biruSedang = Color.fromARGB(
    255,
    37,
    99,
    235,
  ); // Warna tombol baru
  static const Color cyan = Color(0xFF06B6D4);

  static const Color putih = Colors.white;
  static const Color abuTeks = Color(0xFF64748B);
  static const Color abuHeader = Color(0xFF475569);
  static const Color abuBorder = Color(0xFFE2E8F0);
  static const Color latar = Color(0xFFF8FAFC);
}

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nipController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  bool _isLoading = false;
  bool _isSuccess = false;
  String _successEmailMessage = '';

  @override
  void dispose() {
    _nipController.dispose();
    _birthDateController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // Picker Tanggal Lahir
  Future<void> _selectBirthDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1995, 1, 1),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.biruSedang,
              onPrimary: Colors.white,
              onSurface: AppColors.biruTua,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _birthDateController.text =
            "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
      });
    }
  }

  void _handleProsesPemulihan() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
    });

    // Simulasi proses validasi data & pengiriman email pemulihan
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    String rawEmail = _emailController.text.trim();
    String maskedEmail = _maskEmail(rawEmail);

    setState(() {
      _isLoading = false;
      _isSuccess = true;
      _successEmailMessage =
          'Email berisi kata sandi baru akun SIMTAS Anda telah dikirim ke $maskedEmail. Silakan cek email Anda (termasuk folder spam). Terimakasih!';
    });
  }

  // Sensor Email (contoh: gizz*******@gmail.com)
  String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    String name = parts[0];
    String domain = parts[1];

    if (name.length <= 3) {
      return "${name[0]}***@$domain";
    }
    return "${name.substring(0, 3)}${'*' * (name.length - 3)}@$domain";
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
          _buildHeader(),
          Transform.translate(
            offset: const Offset(0, -30),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildFormCard(),
            ),
          ),
          const SizedBox(height: 16),
          _buildFooter(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // =========================================================================
  // LAYOUT DESKTOP
  // =========================================================================
  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Kiri: Form Pemulihan
        Expanded(
          flex: 1,
          child: Container(
            color: AppColors.latar,
            height: double.infinity,
            padding: const EdgeInsets.all(40),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildFormCard(),
                      const SizedBox(height: 24),
                      _buildFooter(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // Kanan: Branding SIMTAS
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
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 110,
                    height: 110,
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/logokominfo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              Icons.lock_reset_rounded,
                              color: AppColors.biruPrimary,
                              size: 50,
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'PEMULIHAN KATA SANDI',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'SIMTAS - Dinas Komunikasi dan Informatika',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // HEADER (Mobile)
  // =========================================================================
  Widget _buildHeader() {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(32),
        bottomRight: Radius.circular(32),
      ),
      child: Container(
        height: 220,
        width: double.infinity,
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 70,
              height: 70,
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/logokominfo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.lock_reset_rounded,
                    color: AppColors.biruPrimary,
                    size: 32,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Pemulihan Password',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'SIMTAS KOMINFO',
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // KARTU FORM PEMULIHAN
  // =========================================================================
  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(26),
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
              'Pemulihan Password',
              style: TextStyle(
                color: AppColors.biruTua,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'SIMTAS KOMINFO',
              style: TextStyle(
                color: AppColors.biruPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 20),

            // NOTIFIKASI SUKSES DENGAN WARNA HIJAU SOFT
            if (_isSuccess) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFA5D6A7)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      color: Color(0xFF2E7D32),
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _successEmailMessage,
                        style: const TextStyle(
                          color: Color(0xFF1B5E20),
                          fontSize: 12.5,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // INPUT NIP
            _buildInputLabel('NIP'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nipController,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 14, color: AppColors.biruTua),
              decoration: _inputDecoration(
                hint: 'Masukkan NIP Anda',
                icon: Icons.badge_outlined,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'NIP wajib diisi';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // INPUT EMAIL PEMULIHAN
            _buildInputLabel('Email Pemulihan'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(fontSize: 14, color: AppColors.biruTua),
              decoration: _inputDecoration(
                hint: 'Masukkan email terdaftar Anda',
                icon: Icons.email_outlined,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Email pemulihan wajib diisi';
                }
                if (!value.contains('@')) {
                  return 'Format email tidak valid';
                }
                return null;
              },
            ),

            const SizedBox(height: 24),

            // TOMBOL PROSES PRESISI DI TENGAH (FULL WIDTH BANNER / CENTERED)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleProsesPemulihan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(
                    255,
                    37,
                    99,
                    235,
                  ), // WARNA PERMINTAAN
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text(
                        'PROSES',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 20),

            // LINK KEMBALI KE LOGIN
            Center(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    'klik ',
                    style: TextStyle(color: AppColors.abuTeks, fontSize: 13),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'disini ',
                      style: TextStyle(
                        color: AppColors.biruSedang,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  const Text(
                    'untuk kembali ke Halaman Login',
                    style: TextStyle(color: AppColors.abuTeks, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: AppColors.abuHeader,
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildFooter() {
    return const Center(
      child: Text(
        '© SIMTAS - Dinas Komunikasi dan Informatika',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.abuTeks,
          fontSize: 11.5,
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
      hintStyle: const TextStyle(color: AppColors.abuTeks, fontSize: 13.5),
      prefixIcon: Icon(icon, color: AppColors.abuTeks, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.latar,
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.abuBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.abuBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.biruSedang, width: 1.5),
      ),
    );
  }
}
