import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../tugas/kelola_tugas_page.dart';
import '../auth/login_page.dart';
import 'admin_kalender.dart';
import 'dashboard_admin_page.dart';
import 'kelola_staff.dart';
import 'laporan_kendala_admin_page.dart';
import 'profil_admin.dart';
import 'riwayat_tugas_staff.dart';
import 'status_staff.dart';

class _SidebarItem {
  final String label;
  final IconData icon;
  final Widget Function()? page; // null = Dashboard

  const _SidebarItem(this.label, this.icon, this.page);
}

/// Sidebar admin. Di layar lebar dipasang permanen di samping konten,
/// di layar kecil dipakai sebagai Drawer (isDrawer: true).
class AdminSidebar extends StatelessWidget {
  final int currentIndex;
  final bool isDrawer;

  const AdminSidebar({super.key, this.currentIndex = 0, this.isDrawer = false});

  static const Color biruTua = AppPalette.navy;
  static const Color biruMid = AppPalette.blue;
  static const Color biruMuda = AppPalette.sky;
  static const Color accentGold = Color(0xFFFFC107);

  static final List<_SidebarItem> _items = [
    const _SidebarItem('Dashboard', Icons.dashboard_rounded, null),
    _SidebarItem(
      'Kelola Staff',
      Icons.groups_rounded,
      () => const KelolaStaffPage(),
    ),
    _SidebarItem(
      'Kelola Tugas',
      Icons.edit_note_rounded,
      () => const KelolaTugasPage(),
    ),
    _SidebarItem(
      'Status Staff',
      Icons.supervisor_account_rounded,
      () => const StatusStaffPage(),
    ),
    _SidebarItem(
      'Kalender',
      Icons.calendar_month_rounded,
      () => const AdminKalenderPage(),
    ),
    _SidebarItem(
      'Riwayat Tugas',
      Icons.history_rounded,
      () => const RiwayatTugasStaffPage(),
    ),
    _SidebarItem(
      'Laporan Kendala',
      Icons.warning_amber_rounded,
      () => const LaporanKendalaAdminPage(),
    ),
    _SidebarItem(
      'Profil Atasan',
      Icons.manage_accounts_rounded,
      () => const ProfilAdminPage(),
    ),
  ];

  void _onTap(BuildContext context, int index) {
    final item = _items[index];
    final navigator = Navigator.of(context);

    if (isDrawer) navigator.pop(); // tutup drawer dulu

    if (index == currentIndex) return;

    // Dashboard: balik ke DashboardAdminPage & reset stack
    if (item.page == null) {
      navigator.pushAndRemoveUntil(
        adminRoute(const DashboardAdminPage()),
        (route) => false,
      );
    } else if (currentIndex == 0) {
      // Dari Dashboard: tumpuk halaman baru supaya tombol kembali ke Dashboard
      navigator.push(adminRoute(item.page!()));
    } else {
      // Dari halaman lain: ganti halaman (stack tidak menumpuk)
      navigator.pushReplacement(adminRoute(item.page!()));
    }
  }

  Future<void> _logout(BuildContext context) async {
    final navigator = Navigator.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.logout_rounded,
            color: Colors.redAccent,
            size: 28,
          ),
        ),
        title: const Text('Keluar'),
        content: const Text(
          'Yakin ingin keluar dari akun ini?',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Keluar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await FirebaseAuth.instance.signOut();

    // Kembali ke halaman login dan kosongkan seluruh riwayat halaman
    navigator.pushAndRemoveUntil(
      adminRoute(const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final panel = Container(
      width: isDrawer ? null : 250,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [biruMuda, biruMid, biruTua],
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Brand
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/logokominfo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.image_not_supported_rounded,
                            color: biruMid,
                            size: 24,
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SIMTAS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: AppTypography.section,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Panel Atasan',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: AppTypography.small,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: Colors.white.withOpacity(0.2), height: 1),
            const SizedBox(height: 12),

            // Menu
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _items.length,
                itemBuilder: (context, i) {
                  final item = _items[i];
                  final selected = i == currentIndex;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Material(
                      color: selected
                          ? Colors.white.withOpacity(0.2)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _onTap(context, i),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 13,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                item.icon,
                                size: 22,
                                color: selected ? accentGold : Colors.white,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  item.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: AppTypography.body,
                                    fontWeight: selected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (selected)
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: accentGold,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Tombol keluar
            Divider(color: Colors.white.withOpacity(0.2), height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
              child: Material(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _logout(context),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    child: Row(
                      children: [
                        Icon(
                          Icons.logout_rounded,
                          size: 22,
                          color: Colors.white,
                        ),
                        SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Keluar',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: AppTypography.body,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (isDrawer) {
      return Drawer(
        width: 270,
        backgroundColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(),
        child: panel,
      );
    }
    return panel;
  }
}

/// Route tanpa animasi: pindah halaman langsung tampil,
/// tanpa efek geser, memudar, atau berkedip.
Route<T> adminRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (_, __, ___) => page,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
  );
}
