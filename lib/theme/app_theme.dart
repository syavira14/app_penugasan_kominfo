import 'package:flutter/material.dart';

/// Standar desain SIMTAS.
/// Gunakan konstanta ini agar warna, tipografi, status, dan tombol konsisten.
class AppPalette {
  static const Color navy = Color(0xFF1A1464);
  static const Color blue = Color(0xFF1D5FA0);
  static const Color sky = Color(0xFF4FA6DE);
  static const Color background = Color(0xFFF4F7FB);
  static const Color white = Colors.white;
  static const Color surface = Colors.white;
  static const Color text = Color(0xFF303846);
  static const Color muted = Color(0xFF64748B);
  static const Color border = Color(0xFFE1E5F0);

  static const Color success = Color(0xFF2E8B57);
  static const Color warning = Color(0xFFFF9800);
  static const Color danger = Color(0xFFE5484D);
  static const Color purple = Color(0xFF8E24AA);
  static const Color pending = Color(0xFF78909C);
}

class AppTypography {
  static const double caption = 11;
  static const double small = 12;
  static const double body = 14;
  static const double section = 17;
  static const double subtitle = 18;
  static const double heading = 22;
  static const double largeHeading = 24;
  static const double pageTitle = 28;
}

class AppTaskStatus {
  static Color color(String rawStatus) {
    switch (rawStatus.trim().toLowerCase()) {
      case 'disetujui':
      case 'selesai':
        return AppPalette.success;
      case 'dikumpulkan':
        return AppPalette.purple;
      case 'berlangsung':
        return AppPalette.warning;
      case 'revisi':
        return const Color(0xFFE65100);
      case 'terkendala':
        return AppPalette.danger;
      case 'pending':
      case 'antrean':
      case 'menunggu giliran':
        return AppPalette.pending;
      default:
        return AppPalette.pending;
    }
  }
}

class AppReportStatus {
  static Color color(String rawStatus) {
    switch (rawStatus.trim().toLowerCase()) {
      case 'selesai':
        return AppPalette.success;
      case 'sedang diproses':
        return AppPalette.blue;
      default:
        return AppPalette.warning;
    }
  }
}

class AppButtonTheme {
  static ButtonStyle primary({Color? backgroundColor}) =>
      ElevatedButton.styleFrom(
        backgroundColor: backgroundColor ?? AppPalette.blue,
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFFCBD5E1),
        disabledForegroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontSize: AppTypography.body,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        elevation: 0,
      );

  static ButtonStyle secondary() => OutlinedButton.styleFrom(
    foregroundColor: AppPalette.blue,
    side: const BorderSide(color: AppPalette.blue),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    textStyle: const TextStyle(
      fontSize: AppTypography.body,
      fontWeight: FontWeight.w600,
    ),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
  );

  static ButtonStyle danger() => primary(backgroundColor: AppPalette.danger);
}
