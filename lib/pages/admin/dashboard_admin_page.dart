import 'package:flutter/material.dart';
import '../../tugas/kelola_tugas_page.dart';
import 'admin_navbar.dart';
import 'kelola_staff.dart';
import 'profil_admin.dart';

/// ============================================================
/// DASHBOARD ADMIN — Sistem Penjadwalan Penugasan Pegawai
/// Dinas Komunikasi dan Informatika
/// ============================================================
/// Konsisten dengan Welcome Page & Login Page:
///   Biru Tua    : #0011CC
///   Biru Sedang : #0066FF
///   Cyan        : #00CCFF
///
/// ISI HALAMAN
/// 1. Header ringkas + info admin
/// 2. 3 kartu statistik: Belum Selesai / Selesai / Total Tugas
/// 3. Diagram batang rekap tugas per bulan + legenda warna
/// 4. Aksi cepat admin (tambah tugas, kelola pegawai, dll)
/// 5. Tugas mendekati tenggat waktu
/// 6. Pegawai dengan penyelesaian tugas terbanyak (ringkas)
/// ============================================================

class AppColors {
  static const Color biruTua = Color(0xFF0011CC);
  static const Color biruSedang = Color(0xFF0066FF);
  static const Color cyan = Color(0xFF00CCFF);
  static const Color putih = Colors.white;
  static const Color abuTeks = Color(0xFF5A6472);
  static const Color latarAbu = Color(0xFFF4F6FB);
  static const Color oranyeWarning = Color(0xFFFF9800);
}

/// Model data sederhana untuk rekap tugas per bulan.
class MonthlyTaskData {
  final String bulan;
  final int selesai;
  final int belumSelesai;

  const MonthlyTaskData({
    required this.bulan,
    required this.selesai,
    required this.belumSelesai,
  });
}

class DashboardAdminPage extends StatelessWidget {
  const DashboardAdminPage({super.key});

  // Data contoh — ganti dengan data dari backend/API
  static const List<MonthlyTaskData> _dataBulanan = [
    MonthlyTaskData(bulan: 'Mar', selesai: 18, belumSelesai: 4),
    MonthlyTaskData(bulan: 'Apr', selesai: 22, belumSelesai: 6),
    MonthlyTaskData(bulan: 'Mei', selesai: 15, belumSelesai: 9),
    MonthlyTaskData(bulan: 'Jun', selesai: 27, belumSelesai: 3),
    MonthlyTaskData(bulan: 'Jul', selesai: 20, belumSelesai: 7),
    MonthlyTaskData(bulan: 'Agu', selesai: 25, belumSelesai: 5),
  ];

  @override
  Widget build(BuildContext context) {
    const int totalSelesai = 127;
    const int totalBelumSelesai = 34;
    const int totalTugas = totalSelesai + totalBelumSelesai;

    return Scaffold(
      backgroundColor: AppColors.latarAbu,
      body: CustomScrollView(
        slivers: [
          // ================= APP BAR =================
          SliverAppBar(
            pinned: true,
            expandedHeight: 120,
            backgroundColor: AppColors.biruTua,
            elevation: 0,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: const Text(
                'Dashboard Admin',
                style: TextStyle(
                  color: AppColors.putih,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.biruTua, AppColors.biruSedang],
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: AppColors.putih,
                ),
                onPressed: () {
                  // TODO: arahkan ke halaman notifikasi
                },
              ),
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ProfilAdminPage(),
                    ),
                  ),
                  child: const CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.putih,
                    child: Icon(
                      Icons.person,
                      color: AppColors.biruTua,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // ================= KONTEN =================
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ---------- 3 KARTU STATISTIK ----------
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        label: 'Belum Selesai',
                        value: '$totalBelumSelesai',
                        icon: Icons.pending_actions_rounded,
                        color: AppColors.cyan,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const KelolaTugasPage(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        label: 'Selesai',
                        value: '$totalSelesai',
                        icon: Icons.task_alt_rounded,
                        color: AppColors.biruSedang,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const KelolaTugasPage(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        label: 'Total Tugas',
                        value: '$totalTugas',
                        icon: Icons.assignment_rounded,
                        color: AppColors.biruTua,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const KelolaTugasPage(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ---------- DIAGRAM BATANG ----------
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.putih,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.biruTua.withOpacity(0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Rekap Tugas per Bulan',
                        style: TextStyle(
                          color: AppColors.biruTua,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        '6 bulan terakhir',
                        style: TextStyle(
                          color: AppColors.abuTeks,
                          fontSize: 11.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 180,
                        child: _BarChart(data: _dataBulanan),
                      ),
                      const SizedBox(height: 18),
                      const Divider(height: 1, color: AppColors.latarAbu),
                      const SizedBox(height: 14),
                      // ---------- LEGENDA ----------
                      Row(
                        children: const [
                          _LegendItem(
                            color: AppColors.biruSedang,
                            label: 'Tugas Selesai',
                          ),
                          SizedBox(width: 20),
                          _LegendItem(
                            color: AppColors.cyan,
                            label: 'Tugas Belum Selesai',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ---------- AKSI CEPAT ----------
                const Text(
                  'Aksi Cepat',
                  style: TextStyle(
                    color: AppColors.biruTua,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  children: [
                    _QuickAction(
                      icon: Icons.add_task_rounded,
                      label: 'Tambah\nTugas',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const KelolaTugasPage(),
                        ),
                      ),
                    ),
                    _QuickAction(
                      icon: Icons.people_alt_rounded,
                      label: 'Kelola\nPegawai',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const KelolaStaffPage(),
                        ),
                      ),
                    ),
                    _QuickAction(
                      icon: Icons.calendar_month_rounded,
                      label: 'Jadwal\nPenugasan',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const KelolaTugasPage(),
                        ),
                      ),
                    ),
                    _QuickAction(
                      icon: Icons.bar_chart_rounded,
                      label: 'Laporan',
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ---------- TUGAS MENDEKATI TENGGAT ----------
                const Text(
                  'Tugas Mendekati Tenggat Waktu',
                  style: TextStyle(
                    color: AppColors.biruTua,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                const _DeadlineTaskTile(
                  judul: 'Pemeliharaan Server Data Center',
                  pegawai: 'Ahmad Fauzi',
                  sisaHari: 1,
                  progress: 0.8,
                ),
                const SizedBox(height: 10),
                const _DeadlineTaskTile(
                  judul: 'Update Konten Portal Layanan Publik',
                  pegawai: 'Siti Nurhaliza',
                  sisaHari: 3,
                  progress: 0.45,
                ),
                const SizedBox(height: 10),
                const _DeadlineTaskTile(
                  judul: 'Audit Keamanan Jaringan',
                  pegawai: 'Budi Santoso',
                  sisaHari: 5,
                  progress: 0.2,
                ),

                const SizedBox(height: 24),

                // ---------- PEGAWAI TERAKTIF ----------
                const Text(
                  'Pegawai dengan Penyelesaian Tugas Terbanyak',
                  style: TextStyle(
                    color: AppColors.biruTua,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.putih,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.biruTua.withOpacity(0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: const [
                      _EmployeeRankTile(
                        nama: 'Ahmad Fauzi',
                        jabatan: 'Staf IT',
                        jumlahTugas: 24,
                        peringkat: 1,
                      ),
                      Divider(height: 1, indent: 68, color: AppColors.latarAbu),
                      _EmployeeRankTile(
                        nama: 'Siti Nurhaliza',
                        jabatan: 'Staf Konten',
                        jumlahTugas: 19,
                        peringkat: 2,
                      ),
                      Divider(height: 1, indent: 68, color: AppColors.latarAbu),
                      _EmployeeRankTile(
                        nama: 'Budi Santoso',
                        jabatan: 'Staf Jaringan',
                        jumlahTugas: 16,
                        peringkat: 3,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
              ]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AdminBottomNavigationBar(currentIndex: 0),
    );
  }
}

/// ---------------------------------------------------------
/// KARTU STATISTIK
/// ---------------------------------------------------------
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.putih,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.biruTua.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.biruTua,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.abuTeks, fontSize: 10.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------
/// DIAGRAM BATANG (custom, tanpa dependency tambahan)
/// ---------------------------------------------------------
class _BarChart extends StatelessWidget {
  final List<MonthlyTaskData> data;

  const _BarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final int maxValue = data
        .map((e) => e.selesai > e.belumSelesai ? e.selesai : e.belumSelesai)
        .reduce((a, b) => a > b ? a : b);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: data.map((item) {
        final double tinggiSelesai = (item.selesai / maxValue) * 130;
        final double tinggiBelum = (item.belumSelesai / maxValue) * 130;

        return Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _Bar(height: tinggiSelesai, color: AppColors.biruSedang),
                  const SizedBox(width: 4),
                  _Bar(height: tinggiBelum, color: AppColors.cyan),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                item.bulan,
                style: const TextStyle(color: AppColors.abuTeks, fontSize: 11),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _Bar extends StatelessWidget {
  final double height;
  final Color color;

  const _Bar({required this.height, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: height < 4 ? 4 : height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
      ),
    );
  }
}

/// ---------------------------------------------------------
/// LEGENDA DIAGRAM
/// ---------------------------------------------------------
class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: AppColors.abuTeks, fontSize: 12),
        ),
      ],
    );
  }
}

/// ---------------------------------------------------------
/// AKSI CEPAT
/// ---------------------------------------------------------
class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _QuickAction({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap:
          onTap ??
          () {
            // TODO: arahkan sesuai aksi
          },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.putih,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.biruTua.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.biruSedang, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.abuTeks,
                fontSize: 9.5,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------
/// ITEM TUGAS MENDEKATI TENGGAT
/// ---------------------------------------------------------
class _DeadlineTaskTile extends StatelessWidget {
  final String judul;
  final String pegawai;
  final int sisaHari;
  final double progress;

  const _DeadlineTaskTile({
    required this.judul,
    required this.pegawai,
    required this.sisaHari,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final bool mendesak = sisaHari <= 2;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.putih,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.biruTua.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  judul,
                  style: const TextStyle(
                    color: AppColors.biruTua,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      (mendesak
                              ? AppColors.oranyeWarning
                              : AppColors.biruSedang)
                          .withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$sisaHari hari lagi',
                  style: TextStyle(
                    color: mendesak
                        ? AppColors.oranyeWarning
                        : AppColors.biruSedang,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Ditugaskan kepada $pegawai',
            style: const TextStyle(color: AppColors.abuTeks, fontSize: 11.5),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.latarAbu,
              valueColor: AlwaysStoppedAnimation<Color>(
                mendesak ? AppColors.oranyeWarning : AppColors.cyan,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------
/// PERINGKAT PEGAWAI
/// ---------------------------------------------------------
class _EmployeeRankTile extends StatelessWidget {
  final String nama;
  final String jabatan;
  final int jumlahTugas;
  final int peringkat;

  const _EmployeeRankTile({
    required this.nama,
    required this.jabatan,
    required this.jumlahTugas,
    required this.peringkat,
  });

  @override
  Widget build(BuildContext context) {
    final List<Color> warnaPeringkat = [
      AppColors.biruTua,
      AppColors.biruSedang,
      AppColors.cyan,
    ];
    final Color warna = warnaPeringkat[(peringkat - 1).clamp(0, 2)];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: warna, shape: BoxShape.circle),
            child: Text(
              '$peringkat',
              style: const TextStyle(
                color: AppColors.putih,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nama,
                  style: const TextStyle(
                    color: AppColors.biruTua,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  jabatan,
                  style: const TextStyle(
                    color: AppColors.abuTeks,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$jumlahTugas tugas',
            style: const TextStyle(
              color: AppColors.biruSedang,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
