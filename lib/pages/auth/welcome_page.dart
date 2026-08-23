import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'login_page.dart';

/// ============================================================
/// WELCOME PAGE — Sistem Penjadwalan Penugasan Pegawai
/// Dinas Komunikasi dan Informatika
/// ============================================================
/// PALET WARNA RESMI (tetap / fixed):
///   Biru Tua    : #0011CC
///   Biru Sedang : #0066FF
///   Cyan        : #00CCFF
///
/// KONSEP DESAIN
/// - Signature element: motif "gelombang sinyal" (concentric signal
///   arcs) di belakang logo — merepresentasikan komunikasi &
///   informatika, bukan sekadar dekorasi generik.
/// - Layout dua panel: panel atas (gradient) untuk identitas/logo,
///   panel bawah (kartu putih melengkung) untuk copy & aksi —
///   memberi kontras baca yang kuat dan terasa "instansional".
/// - Tipografi: 1 skala jelas (Headline tebal, Body medium,
///   Caption ringan) agar tetap sederhana namun tidak datar.
/// ============================================================

class AppColors {
  static const Color biruTua = Color(0xFF0011CC);
  static const Color biruSedang = Color(0xFF0066FF);
  static const Color cyan = Color(0xFF00CCFF);
  static const Color putih = Colors.white;
  static const Color abuTeks = Color(0xFF5A6472);
}

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.putih,
      body: Column(
        children: [
          // ================= PANEL ATAS =================
          Expanded(
            flex: 5,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.biruTua, AppColors.biruSedang, AppColors.cyan],
                  stops: [0.0, 0.6, 1.0],
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Motif gelombang sinyal (signature element)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _SignalWavePainter(),
                    ),
                  ),
                  // Titik-titik jaringan di sudut atas (aksen "informatika")
                  Positioned(
                    top: 24,
                    right: 20,
                    child: CustomPaint(
                      size: const Size(70, 70),
                      painter: _DotGridPainter(),
                    ),
                  ),
                  // Logo
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 118,
                        height: 118,
                        decoration: BoxDecoration(
                          color: AppColors.putih,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.biruTua.withOpacity(0.35),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(18),
                        child: Image.asset(
                          'assets/images/logo_kominfo.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.podcasts_rounded,
                            size: 54,
                            color: AppColors.biruTua,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'DINAS KOMUNIKASI\nDAN INFORMATIKA',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.putih,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2.2,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ================= PANEL BAWAH (kartu putih) =================
          Expanded(
            flex: 4,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
              decoration: const BoxDecoration(
                color: AppColors.putih,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(36),
                  topRight: Radius.circular(36),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x1A0011CC),
                    blurRadius: 20,
                    offset: Offset(0, -8),
                  ),
                ],
              ),
              transform: Matrix4.translationValues(0, -28, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // garis kecil penanda "handle" kartu
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.cyan.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Sistem Penjadwalan\nPenugasan Pegawai',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.biruTua,
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Atur, pantau, dan kelola penugasan pegawai\nsecara terpusat, cepat, dan transparan.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.abuTeks,
                      fontSize: 13.5,
                      height: 1.5,
                    ),
                  ),
                  const Spacer(),
                  // Tombol utama
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.biruTua,
                        foregroundColor: AppColors.putih,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Mulai Sekarang',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      // TODO: arahkan ke halaman informasi/tentang aplikasi
                    },
                    child: const Text(
                      'Pelajari fitur aplikasi',
                      style: TextStyle(
                        color: AppColors.biruSedang,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Motif "gelombang sinyal" — beberapa busur konsentris tipis
/// yang memancar dari titik logo, merepresentasikan pancaran
/// sinyal komunikasi/informasi.
class _SignalWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.42);
    final paint = Paint()
      ..color = AppColors.putih.withOpacity(0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(center, 70.0 * i, paint);
    }

    // Aksen busur cyan tipis di sisi kiri bawah
    final accentPaint = Paint()
      ..color = AppColors.cyan.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(-20, size.height + 20), radius: 160),
      -math.pi / 2,
      math.pi / 2,
      false,
      accentPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Motif titik-titik jaringan kecil (grid 4x4) sebagai aksen
/// "data/informatika" di sudut layar.
class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.putih.withOpacity(0.35);
    const int columns = 4;
    const int rows = 4;
    const double spacing = 12;

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < columns; col++) {
        canvas.drawCircle(
          Offset(col * spacing, row * spacing),
          1.6,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}