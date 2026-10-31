
import 'package:flutter/material.dart';

// Import halaman admin
import '../../tugas/kelola_tugas_page.dart';
import 'admin_navbar.dart';
import 'kelola_staff.dart';
import 'status_staff.dart';
import 'admin_kalender.dart';
import 'riwayat_tugas_staff.dart';
import 'profil_admin.dart';

class DashboardAdminPage extends StatelessWidget {
  const DashboardAdminPage({super.key});

  // Warna utama aplikasi
  static const Color biruTua = Color(0xFF0011CC);
  static const Color biru = Color(0xFF0066FF);
  static const Color cyan = Color(0xFF00CCFF);
  static const Color latar = Color(0xFFF5F7FC);

  // Data contoh, nantinya bisa dihubungkan ke Firebase
  static const int totalTugas = 124;
  static const int belumSelesai = 18;
  static const int dikerjakan = 32;
  static const int selesai = 74;

  static const List<int> tugasBulanan = [
    40,
    49,
    67,
    81,
    98,
    113,
  ];

  static const List<String> namaBulan = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
  ];

  // Fungsi navigasi halaman
  void _buka(BuildContext context, Widget halaman) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => halaman,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lebar = MediaQuery.sizeOf(context).width;

    final padding = lebar < 400 ? 14.0 : 20.0;

    final kontenLebar =
        lebar > 1050 ? 1000.0 : double.infinity;

    return Scaffold(
      backgroundColor: latar,

      body: CustomScrollView(
        slivers: [
          // ==========================================
          // HEADER DASHBOARD ADMIN
          // ==========================================
          SliverAppBar(
            pinned: true,
            automaticallyImplyLeading: false,
            toolbarHeight: 82,
            backgroundColor: biruTua,
            surfaceTintColor: Colors.transparent,

            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0011CC),
                    Color(0xFF06067E),
                  ],
                ),
              ),
            ),

            title: const Text(
              'Dashboard Admin',
              style: TextStyle(
                color: Colors.white,
                fontSize: 23,
                fontWeight: FontWeight.bold,
              ),
            ),

            actions: [
              // Tombol notifikasi
              IconButton(
                tooltip: 'Notifikasi',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Halaman notifikasi belum tersedia.',
                      ),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),

              // Tombol profil admin
              Padding(
                padding: const EdgeInsets.only(
                  left: 8,
                  right: 18,
                ),
                child: InkWell(
                  onTap: () => _buka(
                    context,
                    const ProfilAdminPage(),
                  ),
                  customBorder: const CircleBorder(),
                  child: const CircleAvatar(
                    radius: 23,
                    backgroundColor: Color(0xFFBCEAFF),
                    child: Text(
                      'A',
                      style: TextStyle(
                        fontSize: 25,
                        color: Color(0xFF126092),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // ==========================================
          // KONTEN DASHBOARD
          // ==========================================
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: kontenLebar,
                ),

                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    padding,
                    20,
                    padding,
                    36,
                  ),

                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,

                    children: [
                      // ==================================
                      // KARTU STATISTIK
                      // ==================================
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics:
                            const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio:
                            lebar < 370 ? 1.55 : 2.15,

                        children: [
                          // Total tugas
                          _StatCard(
                            label: 'Total Tugas',
                            value: '$totalTugas',
                            icon: Icons.groups_rounded,
                            color: biru,
                            onTap: () => _buka(
                              context,
                              const KelolaTugasPage(),
                            ),
                          ),

                          // Belum selesai
                          _StatCard(
                            label: 'Tugas Belum Selesai',
                            value: '$belumSelesai',
                            icon: Icons
                                .format_list_bulleted_rounded,
                            color: const Color(0xFFF51E2D),
                            onTap: () => _buka(
                              context,
                              const KelolaTugasPage(),
                            ),
                          ),

                          // Dikerjakan
                          _StatCard(
                            label: 'Dikerjakan',
                            value: '$dikerjakan',
                            icon:
                                Icons.access_time_filled_rounded,
                            color: const Color(0xFFFFBC00),
                            darkText: true,
                            onTap: () => _buka(
                              context,
                              const KelolaTugasPage(),
                            ),
                          ),

                          // Selesai
                          _StatCard(
                            label: 'Selesai',
                            value: '$selesai',
                            icon: Icons.check_rounded,
                            color: const Color(0xFF6BCB76),
                            onTap: () => _buka(
                              context,
                              const KelolaTugasPage(),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // ==================================
                      // GRAFIK TUGAS SELESAI PER BULAN
                      // ==================================
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(
                          16,
                          20,
                          16,
                          18,
                        ),
                        decoration: _dekorasi(
                          Colors.white,
                        ),

                        child: const Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,

                          children: [
                            Text(
                              'Total Tugas Selesai per Bulan',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                            ),

                            SizedBox(height: 22),

                            SizedBox(
                              height: 230,
                              child: _GrafikBulanan(
                                data: tugasBulanan,
                                bulan: namaBulan,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 22),

                      // ==================================
                      // JUDUL MENU UTAMA
                      // ==================================
                      const Text(
                        'Menu Utama',
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),

                      const SizedBox(height: 14),

                      // ==================================
                      // ENAM MENU UTAMA ADMIN
                      // ==================================
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics:
                            const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio:
                            lebar < 370 ? 1.65 : 2.55,

                        children: [
                          // 1. KELOLA STAFF
                          _MenuCard(
                            'Kelola Staff',
                            Icons.groups_rounded,
                            biru,
                            () => _buka(
                              context,
                              const KelolaStaffPage(),
                            ),
                          ),

                          // 2. KELOLA TUGAS
                          _MenuCard(
                            'Kelola Tugas',
                            Icons.edit_note_rounded,
                            cyan,
                            () => _buka(
                              context,
                              const KelolaTugasPage(),
                            ),
                          ),

                          // 3. STATUS STAFF
                          _MenuCard(
                            'Status Staff',
                            Icons.supervisor_account_rounded,
                            cyan,
                            () => _buka(
                              context,
                              const StatusStaffPage(),
                            ),
                          ),

                          // 4. KALENDER
                          _MenuCard(
                            'Kalender',
                            Icons.calendar_month_rounded,
                            biru,
                            () => _buka(
                              context,
                              const AdminKalenderPage(),
                            ),
                          ),

                          // 5. RIWAYAT TUGAS STAFF
                          _MenuCard(
                            'Riwayat Tugas Staff',
                            Icons.history_rounded,
                            biru,
                            () => _buka(
                              context,
                              const RiwayatTugasStaffPage(),
                            ),
                          ),

                          // 6. PROFIL ADMIN
                          _MenuCard(
                            'Profil Admin',
                            Icons.manage_accounts_rounded,
                            cyan,
                            () => _buka(
                              context,
                              const ProfilAdminPage(),
                            ),
                          )
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),

      // ==========================================
      // BOTTOM NAVIGATION BAR
      // ==========================================
      bottomNavigationBar:
          const AdminBottomNavigationBar(
        currentIndex: 0,
      ),
    );
  }
}

// ==============================================
// DEKORASI KARTU
// ==============================================
BoxDecoration _dekorasi(Color warna) {
  return BoxDecoration(
    color: warna,
    borderRadius: BorderRadius.circular(17),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.14),
        blurRadius: 9,
        offset: const Offset(0, 4),
      ),
    ],
  );
}

// ==============================================
// WIDGET KARTU STATISTIK
// ==============================================
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool darkText;
  final VoidCallback onTap;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
    this.darkText = false,
  });

  @override
  Widget build(BuildContext context) {
    final textColor =
        darkText ? Colors.black : Colors.white;

    return Material(
      color: Colors.transparent,

      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),

        child: Ink(
          decoration: _dekorasi(color),

          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),

            child: Row(
              children: [
                // Ikon statistik
                Container(
                  width: 46,
                  height: 52,
                  decoration: BoxDecoration(
                    color:
                        Colors.black.withOpacity(0.13),
                    borderRadius:
                        BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: textColor,
                    size: 30,
                  ),
                ),

                const SizedBox(width: 10),

                // Informasi statistik
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    mainAxisAlignment:
                        MainAxisAlignment.center,

                    children: [
                      Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.12,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        value,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 27,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==============================================
// WIDGET MENU UTAMA
// ==============================================
class _MenuCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MenuCard(
    this.label,
    this.icon,
    this.color,
    this.onTap,
  );

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,

      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),

        child: Ink(
          decoration: _dekorasi(color),

          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 13,
            ),

            child: Row(
              children: [
                // Ikon menu
                Icon(
                  icon,
                  color: Colors.black,
                  size: 39,
                ),

                const SizedBox(width: 12),

                // Nama menu
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==============================================
// WIDGET GRAFIK TUGAS BULANAN
// ==============================================
class _GrafikBulanan extends StatelessWidget {
  final List<int> data;
  final List<String> bulan;

  const _GrafikBulanan({
    required this.data,
    required this.bulan,
  });

  @override
  Widget build(BuildContext context) {
    const batas = 120.0;

    return Row(
      children: [
        // ======================================
        // SKALA GRAFIK
        // ======================================
        SizedBox(
          width: 31,

          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            crossAxisAlignment:
                CrossAxisAlignment.end,

            children: [
              for (final n in [
                120,
                90,
                60,
                30,
                0,
              ])
                Text(
                  '$n',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black87,
                  ),
                ),

              const SizedBox(height: 22),
            ],
          ),
        ),

        const SizedBox(width: 6),

        // ======================================
        // BATANG GRAFIK
        // ======================================
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    // Garis horizontal
                    Column(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,

                      children: List.generate(
                        5,
                        (_) => Container(
                          height: 1,
                          color:
                              const Color(0xFFD4D4D4),
                        ),
                      ),
                    ),

                    // Batang per bulan
                    Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.end,

                      children: List.generate(
                        data.length,
                        (i) => Expanded(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(
                              horizontal: 6,
                            ),

                            child: FractionallySizedBox(
                              heightFactor:
                                  (data[i] / batas)
                                      .clamp(0.0, 1.0),
                              alignment:
                                  Alignment.bottomCenter,

                              child: Container(
                                decoration: BoxDecoration(
                                  color: i.isEven
                                      ? const Color(
                                          0xFF26C5E4,
                                        )
                                      : const Color(
                                          0xFF070D9B,
                                        ),

                                  borderRadius:
                                      const BorderRadius
                                          .vertical(
                                    top: Radius.circular(
                                      4,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 9),

              // ==================================
              // LABEL BULAN
              // ==================================
              Row(
                children: bulan.map((b) {
                  return Expanded(
                    child: Text(
                      b,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
