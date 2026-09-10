import 'package:flutter/material.dart';
import '../../tugas/kelola_tugas_page.dart';
import 'dashboard_admin_page.dart';
import 'admin_kalender.dart';
import 'kelola_staff.dart';
import 'profil_admin.dart';

Widget withAdminReadableText(BuildContext context, Widget child) {
  return MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: const TextScaler.linear(1.12)),
    child: child,
  );
}

class AdminBottomNavigationBar extends StatelessWidget {
  final int currentIndex;

  const AdminBottomNavigationBar({super.key, required this.currentIndex});

  void _navigate(BuildContext context, int index) {
    if (index == currentIndex) return;

    final Widget page = switch (index) {
      0 => const DashboardAdminPage(),
      1 => const KelolaTugasPage(),
      2 => const AdminKalenderPage(),
      3 => const KelolaStaffPage(),
      4 => const ProfilAdminPage(),
      _ => const DashboardAdminPage(),
    };

    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => page));
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
          icon: Icon(Icons.calendar_month_rounded),
          label: 'Kalender',
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
