import 'package:flutter/material.dart';
import '../../tugas/kelola_tugas_page.dart';
import 'dashboard_admin_page.dart';
import 'kelola_staff.dart';
import 'profil_admin.dart';

class AdminBottomNavigationBar extends StatelessWidget {
  final int currentIndex;

  const AdminBottomNavigationBar({super.key, required this.currentIndex});

  void _navigate(BuildContext context, int index) {
    if (index == currentIndex) return;

    final Widget page = switch (index) {
      0 => const DashboardAdminPage(),
      1 => const KelolaTugasPage(),
      2 => const KelolaStaffPage(),
      3 => const ProfilAdminPage(),
      _ => const DashboardAdminPage(),
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
      selectedItemColor: const Color(0xFF0011CC),
      unselectedItemColor: const Color(0xFF5A6472),
      type: BottomNavigationBarType.fixed,
      onTap: (index) => _navigate(context, index),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard_rounded),
          label: 'Dashboard',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.assignment_rounded),
          label: 'Tugas',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.people_alt_rounded),
          label: 'Pegawai',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline_rounded),
          label: 'Profil',
        ),
      ],
    );
  }
}
