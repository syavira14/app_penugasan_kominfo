import 'package:flutter/material.dart';
import 'riwayat_tugas_page.dart';
import 'staff_kalender_page.dart';
import 'staff_profil_page.dart' hide AppColors;
import 'tugas_staff_page.dart' hide AppColors;

class AppColors {
  static const Color biruTua = Color(0xFF0011CC);
  static const Color biruSedang = Color(0xFF0066FF);
  static const Color cyan = Color(0xFF00CCFF);
  static const Color putih = Colors.white;
  static const Color abuTeks = Color(0xFF5A6472);
  static const Color latarAbu = Color(0xFFF4F6FB);
}

class StaffDashboardPage extends StatefulWidget {
  const StaffDashboardPage({super.key});

  @override
  State<StaffDashboardPage> createState() => _StaffDashboardPageState();
}

class _StaffDashboardPageState extends State<StaffDashboardPage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    _StaffHomePage(),
    TugasStaffPage(),
    RiwayatTugasPage(),
    StaffKalenderPage(),
    StaffProfilPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: AppColors.biruTua,
        unselectedItemColor: AppColors.abuTeks,
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        onTap: (index) => setState(() => _selectedIndex = index),
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
            icon: Icon(Icons.history_rounded),
            label: 'Riwayat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_rounded),
            label: 'Kalender',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

class _StaffHomePage extends StatelessWidget {
  const _StaffHomePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.latarAbu,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 132,
            backgroundColor: AppColors.biruTua,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: const Text(
                'Dashboard Staff',
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
                    colors: [
                      AppColors.biruTua,
                      AppColors.biruSedang,
                      AppColors.cyan,
                    ],
                  ),
                ),
              ),
            ),
            actions: const [
              Padding(
                padding: EdgeInsets.only(right: 16),
                child: CircleAvatar(
                  backgroundColor: AppColors.putih,
                  child: Icon(Icons.person, color: AppColors.biruTua),
                ),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate(const [
                _GreetingCard(),
                SizedBox(height: 16),
                _SummaryRow(),
                SizedBox(height: 18),
                _TodayTaskPreview(),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _GreetingCard extends StatelessWidget {
  const _GreetingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.putih,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.biruTua.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Color(0x1A0066FF),
            child: Icon(Icons.badge_rounded, color: AppColors.biruSedang),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selamat bertugas, Ahmad Fauzi',
                  style: TextStyle(
                    color: AppColors.biruTua,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Pantau tugas hari ini dan jadwal terdekat dari satu tempat.',
                  style: TextStyle(
                    color: AppColors.abuTeks,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(
          child: _SummaryCard(
            label: 'Hari Ini',
            value: '2',
            icon: Icons.today_rounded,
            color: AppColors.cyan,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            label: 'Aktif',
            value: '4',
            icon: Icons.pending_actions_rounded,
            color: AppColors.biruSedang,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            label: 'Selesai',
            value: '8',
            icon: Icons.task_alt_rounded,
            color: AppColors.biruTua,
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.putih,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
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
            style: const TextStyle(color: AppColors.abuTeks, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _TodayTaskPreview extends StatelessWidget {
  const _TodayTaskPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.putih,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tugas Terkini',
            style: TextStyle(
              color: AppColors.biruTua,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 12),
          _PreviewTile(
            title: 'Monitoring Jaringan Kecamatan',
            place: 'Kecamatan Samarinda Ulu',
            time: 'Hari ini, 09.00',
          ),
          Divider(height: 22),
          _PreviewTile(
            title: 'Pemeliharaan Server Data Center',
            place: 'Ruang Server Diskominfo',
            time: 'Hari ini, 13.30',
          ),
        ],
      ),
    );
  }
}

class _PreviewTile extends StatelessWidget {
  final String title;
  final String place;
  final String time;

  const _PreviewTile({
    required this.title,
    required this.place,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.assignment_rounded, color: AppColors.biruSedang),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.biruTua,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '$place - $time',
                style: const TextStyle(
                  color: AppColors.abuTeks,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
