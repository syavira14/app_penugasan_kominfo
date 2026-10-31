import 'package:flutter/material.dart';

/// Aturan layout bersama untuk SEMUA halaman staff.
/// Simpan di: lib/widgets/app_layout.dart
///
/// Dengan satu sumber ini, margin kiri-kanan, lebar maksimal konten,
/// breakpoint, dan skala ukuran otomatis sama di semua halaman.
class AppLayout {
  AppLayout._();

  // Breakpoint
  static const double tabletBreakpoint = 600;
  static const double desktopBreakpoint = 900;

  // Lebar maksimal konten (sudah termasuk margin kiri-kanan)
  static const double maxContentWidth = 1100;

  // Jarak antar elemen
  static const double gapCard = 16; // antar kartu
  static const double gapSection = 24; // antar bagian

  /// Skala ukuran: HP mengikuti lebar layar, tablet/desktop tetap.
  static double scaleFor(double width) {
    if (width < tabletBreakpoint) {
      return (width / 375).clamp(0.85, 1.25).toDouble();
    }
    return width < desktopBreakpoint ? 1.0 : 1.05;
  }

  /// Margin kiri-kanan halaman (sudah dikali skala).
  static double sidePadding(double width) {
    return (width < tabletBreakpoint ? 20 : 32) * scaleFor(width);
  }
}

/// Bungkus konten halaman dengan ini supaya lebar maksimal dan
/// margin kiri-kanannya SAMA di setiap halaman (termasuk isi header).
class ResponsiveContent extends StatelessWidget {
  final Widget child;

  const ResponsiveContent({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppLayout.maxContentWidth),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppLayout.sidePadding(width),
          ),
          child: child,
        ),
      ),
    );
  }
}
