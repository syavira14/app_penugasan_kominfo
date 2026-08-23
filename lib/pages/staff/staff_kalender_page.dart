import 'package:flutter/material.dart';

class StaffKalenderPage extends StatelessWidget {
  const StaffKalenderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0011CC),
        foregroundColor: Colors.white,
        title: const Text(
          'Kalender Staff',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: const Center(
        child: Text(
          'Jadwal kalender penugasan staff akan ditampilkan di sini.',
          style: TextStyle(color: Color(0xFF5A6472), fontSize: 13),
        ),
      ),
    );
  }
}
