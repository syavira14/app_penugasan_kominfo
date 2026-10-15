import 'dart:async';

import 'package:flutter/material.dart';
import 'login_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  Timer? _navigationTimer;

  static const Color navy = Color(0xFF003B7A);
  static const Color blue = Color(0xFF1976D2);
  static const Color cyan = Color(0xFF00AEEF);

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    _scaleAnimation = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _animationController.forward();

    _navigationTimer = Timer(const Duration(seconds: 3), () {
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
  void dispose() {
    _navigationTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF062B59), navy, Color(0xFF0877C9)],
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Dekorasi lingkaran
            Positioned(top: -75, right: -55, child: _circle(230, 0.07)),
            Positioned(bottom: 75, left: -85, child: _circle(250, 0.06)),
            Positioned(top: 155, left: 35, child: _circle(45, 0.09)),
            Positioned(bottom: 190, right: 38, child: _circle(30, 0.12)),

            // Konten utama
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo SIMTAS
                      Container(
                        width: 112,
                        height: 112,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 30,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Container(
                          margin: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [blue, cyan],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: const Icon(
                            Icons.assignment_turned_in_rounded,
                            color: Colors.white,
                            size: 58,
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      const Text(
                        'SIMTAS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                        ),
                      ),

                      const SizedBox(height: 12),

                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 42),
                        child: Text(
                          'Sistem Informasi Manajemen\nTugas dan Staf',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            height: 1.6,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      Container(
                        width: 48,
                        height: 3,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFC857),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),

                      const SizedBox(height: 65),

                      const SizedBox(
                        width: 25,
                        height: 25,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),

                      const SizedBox(height: 15),

                      Text(
                        'Mempersiapkan aplikasi...',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer
            Positioned(
              bottom: 25,
              left: 20,
              right: 20,
              child: Text(
                'MANAJEMEN PENUGASAN STAF',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.65),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circle(double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(opacity),
      ),
    );
  }
}
