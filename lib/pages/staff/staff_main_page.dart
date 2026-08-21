import 'package:flutter/material.dart';

// --- IMPORT FILE-FILE HALAMAN STAFF MILIKMU ---
import 'staff_dashboard.dart';
import 'riwayat_tugas.dart';
import 'staff_kalender.dart';
// import 'staff_tugas.dart'; // Un-comment jika file tugas sudah kamu buat

class StaffMainPage extends StatefulWidget {
  const StaffMainPage({super.key});

  @override
  State<StaffMainPage> createState() => _StaffMainPageState();
}

class _StaffMainPageState extends State<StaffMainPage> {
  int _selectedIndex = 0;

  // --- URUTAN HALAMAN SESUAI TOMBOL NAVBAR (INDEX 0 - 3) ---
  late final List<Widget> _pages = [
    const StaffDashboardPage(), // Index 0: Dashboard
    const Center(
      child: Text("Halaman Tugas"),
    ), // Index 1: Tugas (Ganti dengan class tugas jika ada)
    const RiwayatTugasPage(), // Index 2: Riwayat Tugas
    const StaffKalenderPage(), // Index 3: Kalender Staff
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index; // Berpindah antar halaman
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF0066B3),
          unselectedItemColor: Colors.grey.shade400,
          selectedFontSize: 12,
          unselectedFontSize: 11,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_rounded),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.assignment_outlined),
              activeIcon: Icon(Icons.assignment_rounded),
              label: 'Tugas',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_outlined),
              activeIcon: Icon(Icons.history_rounded),
              label: 'Riwayat',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month_outlined),
              activeIcon: Icon(Icons.calendar_month_rounded),
              label: 'Kalender',
            ),
          ],
        ),
      ),
    );
  }
}
