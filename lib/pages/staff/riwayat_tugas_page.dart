import 'package:flutter/material.dart';

class RiwayatTugasPage extends StatelessWidget {
  const RiwayatTugasPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0011CC),
        foregroundColor: Colors.white,
        title: const Text(
          'Riwayat Tugas',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: const Center(
        child: Text(
          'Riwayat tugas staff akan ditampilkan di sini.',
          style: TextStyle(color: Color(0xFF5A6472), fontSize: 13),
        ),
      ),
    );
  }
}
