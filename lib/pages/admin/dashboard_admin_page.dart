
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

// Import halaman admin
import '../../tugas/kelola_tugas_page.dart';
import 'admin_kalender.dart';
import 'admin_sidebar.dart';
import 'kelola_staff.dart';
import 'laporan_kendala_admin_page.dart';
import 'profil_admin.dart';
import 'riwayat_tugas_staff.dart';
import 'status_staff.dart';

class DashboardAdminPage extends StatefulWidget {
  const DashboardAdminPage({super.key});

  @override
  State<DashboardAdminPage> createState() => _DashboardAdminPageState();
}

class _DashboardAdminPageState extends State<DashboardAdminPage> {
  // Palet warna
  static const Color biruTua = Color(0xFF1A1464);
  static const Color biruMid = Color(0xFF1D5FA0);
  static const Color biruMuda = Color(0xFF4FA6DE);
  static const Color accentGold = Color(0xFFFFC107);
  static const Color hijau = Color(0xFF43D18B);
  static const Color merah = Color(0xFFFF5252);
  static const Color bgLight = Color(0xFFF7F9FB);

  static const double _sidebarBreakpoint = 900;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _localeReady = false;

  int _selectedYear = DateTime.now().year;

  static const List<String> _namaBulanSingkat = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null).then((_) {
      if (mounted) setState(() => _localeReady = true);
    });
  }

  String get _dateText => _localeReady
      ? DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(DateTime.now())
      : 'Memuat tanggal...';

  String _fmt(int n) => n < 10 ? '0$n' : '$n';

  void _buka(Widget halaman) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => halaman));
  }

  DateTime? _parseDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    final double scale = (width / 375).clamp(0.85, 1.25);
    final bool isMobile = width < 700;

    final double bgHeight = isMobile ? 330 * scale : 320;
    final int menuColumns = width >= 700 ? 4 : 2;
    final double maxContent = width > 1050 ? 1000 : double.infinity;
    final double sidePad = width < 400 ? 16 : 20;

    final bool isWide = width >= _sidebarBreakpoint;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: bgLight,
      drawer: isWide
          ? null
          : const AdminSidebar(currentIndex: 0, isDrawer: true),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('penugasan').snapshots(),
        builder: (context, snapshotPenugasan) {
          return StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('tugas').snapshots(),
            builder: (context, snapshotTugas) {
              final docsPenugasan = snapshotPenugasan.data?.docs ?? [];
              final docsTugas = snapshotTugas.data?.docs ?? [];

              int totalTugasCount = docsPenugasan.length;
              int belumSelesaiCount = 0;
              int dikerjakanCount = 0;
              int selesaiCount = 0;

              // Mengumpulkan daftar tahun yang tersedia dari data Firestore
              final Set<int> availableYears = {DateTime.now().year};

              for (final doc in docsPenugasan) {
                final data = doc.data() as Map<String, dynamic>;
                final tgl = _parseDate(
                  data['updated_at'] ?? data['created_at'],
                );
                if (tgl != null) availableYears.add(tgl.year);
              }
              for (final doc in docsTugas) {
                final data = doc.data() as Map<String, dynamic>;
                final tgl = _parseDate(
                  data['tanggal_selesai_tugas'] ??
                      data['tanggal_mulai_tugas'] ??
                      data['created_at'],
                );
                if (tgl != null) availableYears.add(tgl.year);
              }

              final List<int> sortedYears = availableYears.toList()..sort();

              // Inisialisasi array 12 bulan (Jan - Des) dengan nilai 0
              final List<int> tugasBulanan12 = List.filled(12, 0);

              for (final doc in docsPenugasan) {
                final data = doc.data() as Map<String, dynamic>;
                final status = (data['status'] ?? '').toString().toLowerCase();

                if (status == 'disetujui' || status == 'selesai') {
                  selesaiCount++;
                } else if (status == 'berlangsung' ||
                    status == 'revisi' ||
                    status == 'dikumpulkan') {
                  dikerjakanCount++;
                } else {
                  belumSelesaiCount++;
                }

                // Kalkulasi data per bulan berdasarkan filter tahun terpilih
                final tgl = _parseDate(
                  data['updated_at'] ?? data['created_at'],
                );
                if (tgl != null &&
                    tgl.year == _selectedYear &&
                    (status == 'disetujui' || status == 'selesai')) {
                  tugasBulanan12[tgl.month - 1]++;
                }
              }

              // Fallback kalkulasi jika koleksi penugasan kosong
              if (totalTugasCount == 0 && docsTugas.isNotEmpty) {
                totalTugasCount = docsTugas.length;
                for (final doc in docsTugas) {
                  final data = doc.data() as Map<String, dynamic>;
                  final status = (data['status'] ?? '')
                      .toString()
                      .toLowerCase();

                  if (status == 'disetujui' || status == 'selesai') {
                    selesaiCount++;
                  } else if (status == 'berlangsung' || status == 'revisi') {
                    dikerjakanCount++;
                  } else {
                    belumSelesaiCount++;
                  }

                  final tgl = _parseDate(
                    data['tanggal_selesai_tugas'] ??
                        data['tanggal_mulai_tugas'] ??
                        data['created_at'],
                  );
                  if (tgl != null &&
                      tgl.year == _selectedYear &&
                      (status == 'disetujui' || status == 'selesai')) {
                    tugasBulanan12[tgl.month - 1]++;
                  }
                }
              }

              final Widget content = Stack(
                children: [
                  // LAYER 1: BACKGROUND GRADIENT
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: _buildHeaderBackground(scale, bgHeight),
                  ),

                  // LAYER 2: KONTEN
                  SafeArea(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.only(bottom: 30 * scale),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxContent),
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: sidePad),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildGreeting(scale),
                                SizedBox(height: 22 * scale),
                                _buildStatsCard(
                                  scale,
                                  total: totalTugasCount,
                                  belum: belumSelesaiCount,
                                  dikerjakan: dikerjakanCount,
                                  selesai: selesaiCount,
                                ),
                                SizedBox(height: 28 * scale),

                                // GRAFIK 12 BULAN DENGAN FILTER TAHUN
                                _buildChartCard(
                                  scale,
                                  tugasBulanan: tugasBulanan12,
                                  namaBulan: _namaBulanSingkat,
                                  availableYears: sortedYears,
                                ),
                                SizedBox(height: 30 * scale),

                                // MENU UTAMA
                                Text(
                                  'Menu Utama',
                                  style: TextStyle(
                                    fontSize: 17 * scale,
                                    fontWeight: FontWeight.bold,
                                    color: biruTua,
                                  ),
                                ),
                                SizedBox(height: 14 * scale),
                                _buildMenuGrid(
                                  scale,
                                  menuColumns,
                                  belumSelesai: belumSelesaiCount,
                                  selesai: selesaiCount,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );

              return isWide
                  ? Row(
                      children: [
                        const AdminSidebar(currentIndex: 0),
                        Expanded(child: content),
                      ],
                    )
                  : content;
            },
          );
        },
      ),
    );
  }

  // ==============================================
  // HEADER
  // ==============================================
  Widget _buildHeaderBackground(double scale, double height) {
    return ClipPath(
      clipper: HeaderCurveClipper(),
      child: Container(
        width: double.infinity,
        height: height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [biruMuda, biruMid, biruTua],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -40 * scale,
              right: -30 * scale,
              child: CircleAvatar(
                radius: 90 * scale,
                backgroundColor: Colors.white.withOpacity(0.06),
              ),
            ),
            Positioned(
              top: 70 * scale,
              left: -50 * scale,
              child: CircleAvatar(
                radius: 65 * scale,
                backgroundColor: accentGold.withOpacity(0.10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGreeting(double scale) {
    return Padding(
      padding: EdgeInsets.only(top: 16 * scale),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (MediaQuery.sizeOf(context).width < _sidebarBreakpoint) ...[
            Material(
              color: Colors.white.withOpacity(0.18),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _scaffoldKey.currentState?.openDrawer(),
                child: Padding(
                  padding: EdgeInsets.all(10 * scale),
                  child: Icon(
                    Icons.menu_rounded,
                    color: Colors.white,
                    size: 24 * scale,
                  ),
                ),
              ),
            ),
            SizedBox(width: 12 * scale),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dashboard Atasan',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22 * scale,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4 * scale),
                Text(
                  _dateText,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 12.5 * scale,
                  ),
                ),
                SizedBox(height: 14 * scale),
                Text(
                  'Pantau tugas & staff',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15 * scale,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 3 * scale),
                Text(
                  'Ringkasan kinerja tim hari ini',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 12 * scale,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12 * scale),
          Material(
            color: Colors.white.withOpacity(0.18),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Halaman notifikasi belum tersedia.'),
                  ),
                );
              },
              child: Padding(
                padding: EdgeInsets.all(10 * scale),
                child: Icon(
                  Icons.notifications_none_rounded,
                  color: Colors.white,
                  size: 24 * scale,
                ),
              ),
            ),
          ),
          SizedBox(width: 8 * scale),
          Material(
            color: Colors.white.withOpacity(0.18),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => _buka(const ProfilAdminPage()),
              child: Padding(
                padding: EdgeInsets.all(10 * scale),
                child: Icon(
                  Icons.person_outline_rounded,
                  color: Colors.white,
                  size: 24 * scale,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================
  // STATISTIK
  // ==============================================
  Widget _buildStatsCard(
    double scale, {
    required int total,
    required int belum,
    required int dikerjakan,
    required int selesai,
  }) {
    void keTugas() => _buka(const KelolaTugasPage());

    return Container(
      padding: EdgeInsets.symmetric(
        vertical: 16 * scale,
        horizontal: 6 * scale,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(22 * scale),
        border: Border.all(color: Colors.white.withOpacity(0.28)),
      ),
      child: Row(
        children: [
          _buildStatItem(_fmt(total), 'Total', Colors.white, scale, keTugas),
          _buildStatDivider(scale),
          _buildStatItem(_fmt(belum), 'Belum', accentGold, scale, keTugas),
          _buildStatDivider(scale),
          _buildStatItem(
            _fmt(dikerjakan),
            'Dikerjakan',
            biruMuda,
            scale,
            keTugas,
          ),
          _buildStatDivider(scale),
          _buildStatItem(_fmt(selesai), 'Selesai', hijau, scale, keTugas),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String value,
    String label,
    Color dotColor,
    double scale,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14 * scale),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 2 * scale),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24 * scale,
                  fontWeight: FontWeight.bold,
                  height: 1.1,
                ),
              ),
              SizedBox(height: 6 * scale),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7 * scale,
                      height: 7 * scale,
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.6),
                          width: 0.8,
                        ),
                      ),
                    ),
                    SizedBox(width: 5 * scale),
                    Text(
                      label,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 11 * scale,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatDivider(double scale) {
    return Container(
      width: 1,
      height: 34 * scale,
      color: Colors.white.withOpacity(0.25),
    );
  }

  // ==============================================
  // GRAFIK 12 BULAN + FILTER TAHUN
  // ==============================================
  Widget _buildChartCard(
    double scale, {
    required List<int> tugasBulanan,
    required List<String> namaBulan,
    required List<int> availableYears,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        16 * scale,
        18 * scale,
        16 * scale,
        16 * scale,
      ),
      decoration: _cardDecoration(scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8 * scale),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(12 * scale),
                ),
                child: Icon(
                  Icons.bar_chart_rounded,
                  color: biruMid,
                  size: 20 * scale,
                ),
              ),
              SizedBox(width: 10 * scale),
              Expanded(
                child: Text(
                  'Tugas Selesai per Bulan',
                  style: TextStyle(
                    fontSize: 15 * scale,
                    fontWeight: FontWeight.bold,
                    color: biruTua,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Dropdown Filter Tahun
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _selectedYear,
                    icon: const Icon(Icons.arrow_drop_down, color: biruMid),
                    style: TextStyle(
                      fontSize: 12.5 * scale,
                      fontWeight: FontWeight.bold,
                      color: biruTua,
                    ),
                    items: availableYears.map((y) {
                      return DropdownMenuItem<int>(value: y, child: Text('$y'));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedYear = val);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 22 * scale),
          SizedBox(
            height: 210 * scale,
            child: _GrafikBulanan(
              data: tugasBulanan,
              bulan: namaBulan,
              scale: scale,
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================
  // MENU
  // ==============================================
  Widget _buildMenuGrid(
    double scale,
    int columns, {
    required int belumSelesai,
    required int selesai,
  }) {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 14 * scale,
        mainAxisSpacing: 14 * scale,
        mainAxisExtent: 135 * scale,
      ),
      children: [
        _buildMenuCard(
          title: 'Kelola Staff',
          subtitle: 'Data & akun staff',
          icon: Icons.groups_rounded,
          iconColor: biruMid,
          bgColor: const Color(0xFFE8EAF6),
          scale: scale,
          onTap: () => _buka(const KelolaStaffPage()),
        ),
        _buildMenuCard(
          title: 'Kelola Tugas',
          subtitle: 'Buat & atur tugas',
          icon: Icons.edit_note_rounded,
          iconColor: Colors.teal,
          bgColor: const Color(0xFFE0F2F1),
          badge: belumSelesai > 0 ? '$belumSelesai belum' : null,
          scale: scale,
          onTap: () => _buka(const KelolaTugasPage()),
        ),
        _buildMenuCard(
          title: 'Status Staff',
          subtitle: 'Pantau aktivitas',
          icon: Icons.supervisor_account_rounded,
          iconColor: Colors.blue,
          bgColor: const Color(0xFFE3F2FD),
          scale: scale,
          onTap: () => _buka(const StatusStaffPage()),
        ),
        _buildMenuCard(
          title: 'Kalender',
          subtitle: 'Jadwal kegiatan',
          icon: Icons.calendar_month_rounded,
          iconColor: const Color(0xFF8E24AA),
          bgColor: const Color(0xFFF3E5F5),
          scale: scale,
          onTap: () => _buka(const AdminKalenderPage()),
        ),
        _buildMenuCard(
          title: 'Riwayat Tugas',
          subtitle: 'Laporan tugas staff',
          icon: Icons.history_rounded,
          iconColor: const Color(0xFFEF6C00),
          bgColor: const Color(0xFFFFF3E0),
          badge: selesai > 0 ? '$selesai selesai' : null,
          scale: scale,
          onTap: () => _buka(const RiwayatTugasStaffPage()),
        ),
        _buildMenuCard(
          title: 'Laporan Kendala',
          subtitle: 'Kendala dari staff',
          icon: Icons.warning_amber_rounded,
          iconColor: merah,
          bgColor: const Color(0xFFFFEBEE),
          scale: scale,
          onTap: () => _buka(const LaporanKendalaAdminPage()),
        ),
        _buildMenuCard(
          title: 'Profil Admin',
          subtitle: 'Pengaturan akun',
          icon: Icons.manage_accounts_rounded,
          iconColor: Colors.purple,
          bgColor: const Color(0xFFF3E5F5),
          scale: scale,
          onTap: () => _buka(const ProfilAdminPage()),
        ),
      ],
    );
  }

  Widget _buildMenuCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required double scale,
    required VoidCallback onTap,
    String? badge,
  }) {
    return Container(
      decoration: _cardDecoration(scale),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20 * scale),
          child: Padding(
            padding: EdgeInsets.all(16 * scale),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: EdgeInsets.all(10 * scale),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(14 * scale),
                      ),
                      child: Icon(icon, color: iconColor, size: 24 * scale),
                    ),
                    if (badge != null)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8 * scale,
                          vertical: 4 * scale,
                        ),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            fontSize: 10 * scale,
                            fontWeight: FontWeight.bold,
                            color: iconColor,
                          ),
                        ),
                      ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15 * scale,
                        color: biruTua,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 3 * scale),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12 * scale,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration(double scale) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20 * scale),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}

// ==============================================
// WIDGET GRAFIK TUGAS 12 BULAN
// ==============================================
class _GrafikBulanan extends StatelessWidget {
  final List<int> data;
  final List<String> bulan;
  final double scale;

  const _GrafikBulanan({
    required this.data,
    required this.bulan,
    required this.scale,
  });

  static const double labelH = 14;
  static const double yAxisW = 26;

  @override
  Widget build(BuildContext context) {
    const biruTua = Color(0xFF1A1464);
    const biruMuda = Color(0xFF4FA6DE);

    final int maxVal = data.isEmpty
        ? 10
        : (data.reduce((a, b) => a > b ? a : b));
    final double batas = maxVal == 0 ? 10.0 : (maxVal * 1.25).ceilToDouble();

    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              // Skala sumbu Y
              SizedBox(
                width: yAxisW,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (int i = 4; i >= 0; i--)
                      SizedBox(
                        height: labelH,
                        child: Text(
                          '${((batas / 4) * i).round()}',
                          style: TextStyle(
                            fontSize: 10 * scale,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(width: 6 * scale),

              // Area 12 Batang Bulan
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: labelH / 2),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Garis horizontal latar belakang
                      Positioned.fill(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(
                            5,
                            (_) => Container(
                              height: 1,
                              color: const Color(0xFFE6E9EF),
                            ),
                          ),
                        ),
                      ),

                      // 12 Batang Bulan
                      Positioned.fill(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: List.generate(data.length, (i) {
                            return Expanded(
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 3 * scale,
                                ),
                                child: FractionallySizedBox(
                                  heightFactor: (data[i] / batas).clamp(
                                    0.0,
                                    1.0,
                                  ),
                                  alignment: Alignment.bottomCenter,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Positioned.fill(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: i.isEven
                                                  ? const [
                                                      biruMuda,
                                                      Color(0xFF1D5FA0),
                                                    ]
                                                  : const [
                                                      Color(0xFF1D5FA0),
                                                      biruTua,
                                                    ],
                                            ),
                                            borderRadius:
                                                const BorderRadius.vertical(
                                                  top: Radius.circular(4),
                                                ),
                                          ),
                                        ),
                                      ),
                                      if (data[i] > 0)
                                        Positioned(
                                          top: -15 * scale,
                                          left: -6,
                                          right: -6,
                                          child: Text(
                                            '${data[i]}',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 9.5 * scale,
                                              fontWeight: FontWeight.bold,
                                              color: biruTua,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 6 * scale),

        // Label 12 Bulan (Jan - Des)
        Padding(
          padding: EdgeInsets.only(left: yAxisW + 6 * scale),
          child: Row(
            children: bulan
                .map(
                  (b) => Expanded(
                    child: Text(
                      b,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10.5 * scale,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

// ==============================================
// CLIPPER HEADER
// ==============================================
class HeaderCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final double h = size.height;
    final double w = size.width;

    final path = Path()..lineTo(0, h * 0.82);
    path.quadraticBezierTo(w / 2, h * 1.02, w, h * 0.82);
    path.lineTo(w, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
