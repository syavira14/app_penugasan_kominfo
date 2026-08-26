import 'package:flutter/material.dart';
import 'riwayat_tugas.dart';
import 'staff_dashboard.dart';
import 'staff_kalender.dart';
import 'staff_profil_page.dart';
import 'tugas_staff_page.dart';

class StaffBottomNavigationBar extends StatelessWidget {
  final int currentIndex;

  const StaffBottomNavigationBar({super.key, required this.currentIndex});

  void _navigate(BuildContext context, int index) {
    if (index == currentIndex) return;

    final Widget page = switch (index) {
      0 => const StaffDashboardPage(),
      1 => const TugasStaffPage(),
      2 => const RiwayatTugasPage(),
      3 => const StaffKalenderPage(),
      4 => const StaffProfilPage(),
      _ => const StaffDashboardPage(),
    };

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      selectedItemColor: const Color(0xFF0066B3),
      unselectedItemColor: Colors.grey,
      type: BottomNavigationBarType.fixed,
      onTap: (index) => _navigate(context, index),
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
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline_rounded),
          activeIcon: Icon(Icons.person_rounded),
          label: 'Profil',
        ),
      ],
    );
  }
}
