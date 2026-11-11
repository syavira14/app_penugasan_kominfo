import 'dart:async';

import 'package:flutter/material.dart';

import 'login_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  // Lama splash tampil (progress bar mengikuti durasi ini)
  static const Duration _splashDuration = Duration(milliseconds: 1800);

  // Aksen emas (sama dengan aksen di dashboard)
  static const Color _gold = Color(0xFFFFC857);

  // Logo yang SAMA dengan halaman login
  static const String _logoAsset = 'assets/images/logokominfo.png';

  late final AnimationController _intro; // animasi masuk (sekali jalan)
  late final AnimationController
  _pulse; // gelombang di belakang logo (berulang)

  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _subtitleFade;
  late final Animation<Offset> _subtitleSlide;
  late final Animation<double> _lineWidth;
  late final Animation<double> _footerFade;

  Timer? _navigationTimer;
  bool _logoPrecached = false;

  Animation<double> _interval(
    double begin,
    double end, {
    Curve curve = Curves.easeOut,
  }) {
    return CurvedAnimation(
      parent: _intro,
      curve: Interval(begin, end, curve: curve),
    );
  }

  @override
  void initState() {
    super.initState();

    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    // Urutan muncul: logo -> judul -> subjudul -> garis emas -> footer
    _logoFade = _interval(0.0, 0.4);
    _logoScale = Tween<double>(
      begin: 0.6,
      end: 1.0,
    ).animate(_interval(0.0, 0.6, curve: Curves.easeOutBack));

    _titleFade = _interval(0.3, 0.7);
    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(_interval(0.3, 0.7, curve: Curves.easeOutCubic));

    _subtitleFade = _interval(0.45, 0.85);
    _subtitleSlide = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(_interval(0.45, 0.85, curve: Curves.easeOutCubic));

    _lineWidth = _interval(0.55, 0.95, curve: Curves.easeOutCubic);
    _footerFade = _interval(0.7, 1.0);

    _intro.forward();

    _navigationTimer = Timer(_splashDuration, () {
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, animation, secondaryAnimation) => const LoginPage(),
          transitionsBuilder: (_, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Muat logo lebih awal supaya tidak berkedip (di splash maupun login)
    if (!_logoPrecached) {
      _logoPrecached = true;
      precacheImage(
        const AssetImage(_logoAsset),
        context,
        onError: (error, stackTrace) {},
      );
    }
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _intro.dispose();
    _pulse.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final bool wide = width > 600; // breakpoint yang sama dengan halaman login

    final double logoSize = wide ? 140 : 112;
    final double ringPadding = wide ? 14 : 10;
    final double outerSize = logoSize + ringPadding * 2;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        // Gradient yang sama dengan halaman login
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
            // Gelombang latar yang sama dengan halaman login
            Positioned.fill(
              child: CustomPaint(painter: _BackgroundWavePainter()),
            ),

            // KONTEN TENGAH
            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 70),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildLogo(logoSize, ringPadding, outerSize),
                      SizedBox(height: wide ? 36 : 30),
                      _buildTitle(wide),
                      const SizedBox(height: 10),
                      _buildSubtitle(wide),
                      const SizedBox(height: 22),
                      _buildGoldLine(),
                    ],
                  ),
                ),
              ),
            ),

            // BAWAH: progress + footer
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 26),
                  child: _buildBottom(wide),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // LOGO (tampilan sama persis dengan header halaman login, ukuran lebih besar)
  // ---------------------------------------------------------------------------

  Widget _buildLogo(double logoSize, double ringPadding, double outerSize) {
    return FadeTransition(
      opacity: _logoFade,
      child: SizedBox(
        width: outerSize,
        height: outerSize,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Gelombang berdenyut di belakang logo
            _ripple(outerSize, 0.0),
            _ripple(outerSize, 0.5),

            ScaleTransition(
              scale: _logoScale,
              child: Container(
                padding: EdgeInsets.all(ringPadding),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.35),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Container(
                  width: logoSize,
                  height: logoSize,
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      _logoAsset,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.image_not_supported_rounded,
                          color: AppColors.biruPrimary,
                          size: logoSize * 0.4,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ripple(double size, double offset) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final double t = (_pulse.value + offset) % 1.0;

        return Opacity(
          opacity: (1 - t) * 0.35,
          child: Transform.scale(
            scale: 1 + t * 0.8,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // TEKS
  // ---------------------------------------------------------------------------

  Widget _buildTitle(bool wide) {
    return FadeTransition(
      opacity: _titleFade,
      child: SlideTransition(
        position: _titleSlide,
        child: Text(
          'SIMTAS',
          style: TextStyle(
            color: Colors.white,
            fontSize: wide ? 46 : 38,
            fontWeight: FontWeight.w800,
            letterSpacing: 4,
          ),
        ),
      ),
    );
  }

  Widget _buildSubtitle(bool wide) {
    return FadeTransition(
      opacity: _subtitleFade,
      child: SlideTransition(
        position: _subtitleSlide,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Sistem Informasi Manajemen Tugas dan Staff',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: wide ? 15 : 13.5,
                height: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGoldLine() {
    return AnimatedBuilder(
      animation: _lineWidth,
      builder: (context, _) {
        return Container(
          width: 56 * _lineWidth.value,
          height: 3,
          decoration: BoxDecoration(
            color: _gold,
            borderRadius: BorderRadius.circular(10),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // BAWAH: progress bar + footer
  // ---------------------------------------------------------------------------

  Widget _buildBottom(bool wide) {
    return FadeTransition(
      opacity: _footerFade,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: wide ? 220 : 170,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: _splashDuration,
              curve: Curves.easeInOut,
              builder: (context, value, _) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: value,
                    minHeight: 4,
                    backgroundColor: Colors.white.withOpacity(0.18),
                    valueColor: const AlwaysStoppedAnimation<Color>(_gold),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Mempersiapkan aplikasi...',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'MANAJEMEN PENUGASAN STAF',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Gelombang latar: sama persis dengan yang dipakai di halaman login,
/// supaya perpindahan splash -> login terasa menyatu.
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
