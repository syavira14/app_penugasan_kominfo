import 'package:flutter/material.dart';

/// ============================================================
/// MODEL: TugasModel
/// Dipakai bersama oleh KelolaTugasPage & DetailTugasAdminPage
/// ============================================================
class TugasModel {
  final String id;
  final String judul;
  final String deskripsi;
  final String tempat;
  final double? latitude;
  final double? longitude;
  final DateTime tanggal;
  final TimeOfDay jam;
  final List<String> staff;
  final String prioritas; // 'Rendah' | 'Sedang' | 'Tinggi'
  final bool selesai;

  const TugasModel({
    required this.id,
    required this.judul,
    required this.deskripsi,
    required this.tempat,
    this.latitude,
    this.longitude,
    required this.tanggal,
    required this.jam,
    required this.staff,
    this.prioritas = 'Sedang',
    this.selesai = false,
  });

  TugasModel copyWith({
    String? judul,
    String? deskripsi,
    String? tempat,
    double? latitude,
    double? longitude,
    DateTime? tanggal,
    TimeOfDay? jam,
    List<String>? staff,
    String? prioritas,
    bool? selesai,
  }) {
    return TugasModel(
      id: id,
      judul: judul ?? this.judul,
      deskripsi: deskripsi ?? this.deskripsi,
      tempat: tempat ?? this.tempat,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      tanggal: tanggal ?? this.tanggal,
      jam: jam ?? this.jam,
      staff: staff ?? this.staff,
      prioritas: prioritas ?? this.prioritas,
      selesai: selesai ?? this.selesai,
    );
  }
}

/// Format tanggal sederhana ke Bahasa Indonesia tanpa dependency `intl`.
String formatTanggalIndo(DateTime date) {
  const List<String> bulan = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];
  return '${date.day} ${bulan[date.month - 1]} ${date.year}';
}

/// Format TimeOfDay menjadi "HH.mm".
String formatJam(TimeOfDay time) {
  final String jam = time.hour.toString().padLeft(2, '0');
  final String menit = time.minute.toString().padLeft(2, '0');
  return '$jam.$menit';
}