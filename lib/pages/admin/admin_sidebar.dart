import 'package:flutter/material.dart';

import '../../tugas/kelola_tugas_page.dart';
import 'dashboard_admin_page.dart';
import 'admin_kalender.dart';
import 'kelola_staff.dart';
import 'laporan_kendala_admin_page.dart';
import 'profil_admin.dart';
import 'riwayat_tugas_staff.dart';
import 'status_staff.dart';

class _SidebarItem {
  final String label;
  final IconData icon;
  final Widget Function() page;

  const _SidebarItem(this.label, this.icon, this.page);
}

/// Sidebar admin. Di layar lebar dipasang permanen di samping konten,
/// di layar kecil dipakai sebagai Drawer (isDrawer: true).
class AdminSidebar extends StatelessWidget {
  final int currentIndex;
  final bool isDrawer;

  const AdminSidebar({super.key, this.currentIndex = 0, this.isDrawer = false});

  static const Color biruTua = Color(0xFF1A1464);
  static const Color biruMid = Color(0xFF1D5FA0);
  static const Color biruMuda = Color(0xFF4FA6DE);
  static const Color accentGold = Color(0xFFFFC107);

  static final List<_SidebarItem> _items = [
    _SidebarItem(
      'Dashboard',
      Icons.dashboard_rounded,
      () => const DashboardAdminPage(),
    ),
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
      'Profil Admin',
      Icons.manage_accounts_rounded,
      () => const ProfilAdminPage(),
    ),
  ];

  void _onTap(BuildContext context, int index) {
    final navigator = Navigator.of(context);

    // Tutup drawer terlebih dahulu jika dibuka di mode mobile
    if (isDrawer) navigator.pop();

    // Jika menekan menu yang sedang aktif, tidak perlu navigasi ulang
    if (index == currentIndex) return;

    // Gunakan PageRouteBuilder dengan animasi instan (Duration.zero)
    navigator.pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation1, animation2) => _items[index].page(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
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
            // Brand / Header Sidebar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Admin Panel',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Manajemen tugas',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: Colors.white.withOpacity(0.2), height: 1),
            const SizedBox(height: 12),

            // Daftar Menu Sidebar
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
                      // Mengubah warna background item aktif agar menyatu rata dengan gradien (tanpa sorotan transparan tebal)
                      color: selected
                          ? Colors.white.withOpacity(0.12)
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
                                    fontSize: 14.5,
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
