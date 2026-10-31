import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../../models/user_model.dart';
import '../../widgets/app_layout.dart';
import 'rekapan_pribadi_page.dart';
import 'riwayat_tugas.dart';
import 'staff_kalender.dart';
import 'staff_profil_page.dart';
import 'tugas_staff_page.dart';

/// Ringkasan jumlah tugas milik staff (dihitung dari snapshot Firestore koleksi 'penugasan').
class _TugasStats {
  final int total;
  final int pending;
  final int berlangsung;
  final int terkendala;
  final int selesai;

  const _TugasStats({
    required this.total,
    required this.pending,
    required this.berlangsung,
    required this.terkendala,
    required this.selesai,
  });

  static const _TugasStats empty = _TugasStats(
    total: 0,
    pending: 0,
    berlangsung: 0,
    terkendala: 0,
    selesai: 0,
  );

  factory _TugasStats.fromSnapshot(QuerySnapshot? snap) {
    if (snap == null) return empty;

    int pending = 0, berlangsung = 0, terkendala = 0, selesai = 0;

    for (final doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final status = (data['status'] ?? '').toString().toLowerCase();

      if (status == 'pending' || status == 'belum dimulai') {
        pending++;
      } else if (status == 'terkendala') {
        terkendala++;
      } else if (status == 'berlangsung' ||
          status == 'dikumpulkan' ||
          status == 'in progress' ||
          status == 'revisi') {
        berlangsung++;
      } else if (status == 'selesai' ||
          status == 'completed' ||
          status == 'disetujui') {
        selesai++;
      }
    }

    return _TugasStats(
      total: snap.docs.length,
      pending: pending,
      berlangsung: berlangsung,
      terkendala: terkendala,
      selesai: selesai,
    );
  }

  int get aktif => pending + berlangsung + terkendala;
}

class StaffDashboardPage extends StatefulWidget {
  const StaffDashboardPage({super.key});

  @override
  State<StaffDashboardPage> createState() => _StaffDashboardPageState();
}

class _StaffDashboardPageState extends State<StaffDashboardPage> {
  // Palet warna
  static const Color biruTua = Color(0xFF1A1464);
  static const Color biruMid = Color(0xFF1D5FA0);
  static const Color biruMuda = Color(0xFF4FA6DE);
  static const Color accentGold = Color(0xFFFFC107);
  static const Color hijau = Color(0xFF43D18B);
  static const Color bgLight = Color(0xFFF7F9FB);

  UserModel? currentUser;
  bool _isLoading = true;
  bool _localeReady = false;

  late final String _currentUserId;
  late final Stream<QuerySnapshot> _tugasStream;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    _tugasStream = FirebaseFirestore.instance
        .collection('penugasan')
        .where('staff_id', isEqualTo: _currentUserId)
        .snapshots();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await initializeDateFormatting('id_ID', null);
    if (mounted) setState(() => _localeReady = true);
    await _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists && mounted) {
        setState(() {
          currentUser = UserModel.fromFirestore(doc);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal memuat data user: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String get _dateText => _localeReady
      ? DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(DateTime.now())
      : 'Memuat tanggal...';

  String _fmt(int n) => n < 10 ? '0$n' : '$n';

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final double scale = (width / 375).clamp(0.85, 1.25);
    final bool isMobile = width < AppLayout.tabletBreakpoint;

    final double bgHeight = isMobile ? 390 * scale : 360;
    final int menuColumns = width >= 700 ? 4 : 2;

    final String displayName = currentUser?.nama.isNotEmpty == true
        ? currentUser!.nama
        : FirebaseAuth.instance.currentUser?.email?.split('@').first ?? 'User';

    return Scaffold(
      backgroundColor: bgLight,
      body: StreamBuilder<QuerySnapshot>(
        stream: _tugasStream,
        builder: (context, snapshot) {
          final stats = _TugasStats.fromSnapshot(snapshot.data);

          return Stack(
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
                  padding: EdgeInsets.only(
                    top: isMobile ? 0 : 16 * scale,
                    bottom: 30 * scale,
                  ),
                  child: ResponsiveContent(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildGreeting(displayName, scale),
                        SizedBox(height: AppLayout.gapSection * scale),

                        // STATISTIK DINAMIS
                        _buildStatsCard(stats, scale),

                        SizedBox(height: 36 * scale),

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
                        _buildMenuGrid(stats, scale, menuColumns),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

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

  Widget _buildGreeting(String displayName, double scale) {
    return Padding(
      padding: EdgeInsets.only(top: 16 * scale),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _isLoading
                    ? Container(
                        width: 150 * scale,
                        height: 26 * scale,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      )
                    : Text(
                        'Halo, $displayName',
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
                SizedBox(height: 16 * scale),
                Text(
                  'Semangat hari ini!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15 * scale,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 3 * scale),
                Text(
                  'Jangan lupa selesaikan tugas sebelum tenggat yaa',
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
              onTap: () {},
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
        ],
      ),
    );
  }

  Widget _buildStatsCard(_TugasStats s, double scale) {
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
          _buildStatItem(_fmt(s.total), 'Total', Colors.white, scale),
          _buildStatDivider(scale),
          _buildStatItem(_fmt(s.pending), 'Pending', accentGold, scale),
          _buildStatDivider(scale),
          _buildStatItem(_fmt(s.berlangsung), 'Berlangsung', biruMuda, scale),
          _buildStatDivider(scale),
          _buildStatItem(_fmt(s.selesai), 'Selesai', hijau, scale),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String value,
    String label,
    Color dotColor,
    double scale,
  ) {
    return Expanded(
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
    );
  }

  Widget _buildStatDivider(double scale) {
    return Container(
      width: 1,
      height: 34 * scale,
      color: Colors.white.withOpacity(0.25),
    );
  }

  Widget _buildMenuGrid(_TugasStats s, double scale, int columns) {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: AppLayout.gapCard * scale,
        mainAxisSpacing: AppLayout.gapCard * scale,
        mainAxisExtent: 145 * scale,
      ),
      children: [
        _buildMenuCard(
          title: 'Tugasku',
          subtitle: 'Kelola tugas anda',
          icon: Icons.assignment_outlined,
          iconColor: biruMid,
          bgColor: const Color(0xFFE8EAF6),
          badge: s.aktif > 0 ? '${s.aktif} aktif' : null,
          scale: scale,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TugasStaffPage()),
          ),
        ),
        _buildMenuCard(
          title: 'Kalender',
          subtitle: 'Jadwal kegiatan',
          icon: Icons.calendar_month_outlined,
          iconColor: Colors.teal,
          bgColor: const Color(0xFFE0F2F1),
          scale: scale,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const StaffKalenderPage()),
          ),
        ),
        _buildMenuCard(
          title: 'Riwayat Tugas',
          subtitle: 'Laporan tugas selesai',
          icon: Icons.insert_chart_outlined,
          iconColor: Colors.blue,
          bgColor: const Color(0xFFE3F2FD),
          badge: s.selesai > 0 ? '${s.selesai} selesai' : null,
          scale: scale,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RiwayatTugasPage()),
          ),
        ),
        _buildMenuCard(
          title: 'Rekapan Pribadi',
          subtitle: 'Monitoring & Kinerja',
          icon: Icons.analytics_outlined,
          iconColor: const Color(0xFF8E24AA),
          bgColor: const Color(0xFFF3E5F5),
          scale: scale,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RekapanPribadiPage()),
          ),
        ),
        _buildMenuCard(
          title: 'Profil',
          subtitle: 'Pengaturan akun',
          icon: Icons.person_outline,
          iconColor: Colors.purple,
          bgColor: const Color(0xFFF3E5F5),
          scale: scale,
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StaffProfilPage()),
            );
            _fetchUserData();
          },
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
