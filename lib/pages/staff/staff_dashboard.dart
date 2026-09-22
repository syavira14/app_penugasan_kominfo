import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

// ---- IMPORT FILE HALAMAN SESUAI STRUKTUR PROYEKMU ----
import '../../models/user_model.dart';
import 'riwayat_tugas.dart';
import 'staff_kalender.dart';
import 'staff_profil_page.dart';
import 'tugas_staff_page.dart';

class StaffDashboardPage extends StatefulWidget {
  const StaffDashboardPage({super.key});

  @override
  State<StaffDashboardPage> createState() => _StaffDashboardPageState();
}

class _StaffDashboardPageState extends State<StaffDashboardPage> {
  // Warna tetap
  static const Color redDark = Color(0xFF1A1464);
  static const Color redMid = Color(0xFF1D5FA0);
  static const Color redLight = Color(0xFF4FA6DE);
  static const Color accentGold = Color(0xFFFFC107);
  static const Color bgLight = Color(0xFFF7F9FB);

  UserModel? currentUser;
  bool _isLoading = true;
  String _formattedDate = '';

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    // Format tanggal ke Bahasa Indonesia
    await initializeDateFormatting('id_ID', null);
    if (mounted) {
      setState(() {
        _formattedDate = DateFormat(
          'EEEE, d MMM yyyy',
          'id_ID',
        ).format(DateTime.now());
      });
    }

    // Ambil data user dari Firestore
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

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double screenWidth = MediaQuery.of(context).size.width;
    final double scale = (screenWidth / 375).clamp(0.85, 1.25);

    final String displayName = currentUser?.nama.isNotEmpty == true
        ? currentUser!.nama
        : FirebaseAuth.instance.currentUser?.email?.split('@').first ?? 'User';

    final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: bgLight,
      body: Stack(
        children: [
          // LAYER 1: BACKGROUND GRADIENT
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipPath(
              clipper: HeaderCurveClipper(),
              child: Container(
                width: double.infinity,
                height: screenHeight * 0.45,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [redLight, redMid, redDark],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: -30 * scale,
                      right: -20 * scale,
                      child: CircleAvatar(
                        radius: 80 * scale,
                        backgroundColor: Colors.white.withOpacity(0.05),
                      ),
                    ),
                    Positioned(
                      top: 40 * scale,
                      left: -40 * scale,
                      child: CircleAvatar(
                        radius: 60 * scale,
                        backgroundColor: accentGold.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // LAYER 2: KONTEN UTAMA
          SafeArea(
            child: Column(
              children: [
                // HEADER: GREETING & NOTIF
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    25 * scale,
                    15 * scale,
                    25 * scale,
                    0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _isLoading
                                ? Container(
                                    width: 140 * scale,
                                    height: 24 * scale,
                                    decoration: BoxDecoration(
                                      color: Colors.white24,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  )
                                : Text(
                                    "Halo, $displayName",
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
                              _formattedDate.isNotEmpty
                                  ? _formattedDate
                                  : "Memuat tanggal...",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 13 * scale,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.notifications_none,
                        color: Colors.white,
                        size: 28,
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 35 * scale),

                // --- STATS ROW (REALTIME FIRESTORE & BAHASA INDONESIA) ---
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 25 * scale),
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('tugas')
                        .where('assignedTo', isEqualTo: currentUserId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      int countPending = 0;
                      int countBerlangsung = 0;
                      int countSelesai = 0;

                      if (snapshot.hasData) {
                        for (var doc in snapshot.data!.docs) {
                          final data = doc.data() as Map<String, dynamic>;
                          final status = (data['statusTugas'] ?? '')
                              .toString()
                              .toLowerCase();

                          if (status == 'pending' ||
                              status == 'belum dimulai') {
                            countPending++;
                          } else if (status == 'berlangsung' ||
                              status == 'in progress' ||
                              status == 'terkendala' ||
                              status == 'revisi') {
                            countBerlangsung++;
                          } else if (status == 'selesai' ||
                              status == 'completed' ||
                              status == 'disetujui') {
                            countSelesai++;
                          }
                        }
                      }

                      String fmt(int num) => num < 10 ? '0$num' : '$num';

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildHeaderStat(
                            fmt(countPending),
                            "Tugas\nPending",
                            scale,
                          ),
                          _buildHeaderStat(
                            fmt(countBerlangsung),
                            "Tugas\nBerlangsung",
                            scale,
                          ),
                          _buildHeaderStat(
                            fmt(countSelesai),
                            "Tugas\nSelesai",
                            scale,
                          ),
                        ],
                      );
                    },
                  ),
                ),

                SizedBox(height: 40 * scale),

                // MENU GRID
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 20 * scale),
                    child: GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 18 * scale,
                      mainAxisSpacing: 18 * scale,
                      childAspectRatio: 0.95,
                      children: [
                        _buildMenuCard(
                          title: "Tugasku",
                          subtitle: "Kelola tugas anda",
                          icon: Icons.assignment_outlined,
                          iconColor: redMid,
                          bgColor: const Color(0xFFE8EAF6),
                          scale: scale,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TugasStaffPage(),
                            ),
                          ),
                        ),
                        _buildMenuCard(
                          title: "Kalender",
                          subtitle: "Jadwal kegiatan",
                          icon: Icons.confirmation_number_outlined,
                          iconColor: Colors.teal,
                          bgColor: const Color(0xFFE0F2F1),
                          scale: scale,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const StaffKalenderPage(),
                            ),
                          ),
                        ),
                        _buildMenuCard(
                          title: "Riwayat Tugas",
                          subtitle: "Laporan tugas selesai",
                          icon: Icons.insert_chart_outlined,
                          iconColor: Colors.blue,
                          bgColor: const Color(0xFFE3F2FD),
                          scale: scale,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RiwayatTugasPage(),
                            ),
                          ),
                        ),
                        _buildMenuCard(
                          title: "Profil",
                          subtitle: "Pengaturan akun",
                          icon: Icons.person_outline,
                          iconColor: Colors.purple,
                          bgColor: const Color(0xFFF3E5F5),
                          scale: scale,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const StaffProfilPage(),
                              ),
                            );
                            _fetchUserData();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderStat(String val, String label, double scale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          val,
          style: TextStyle(
            color: Colors.white,
            fontSize: 32 * scale,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12 * scale,
            height: 1.2,
          ),
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
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25 * scale),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(25 * scale),
          child: Padding(
            padding: EdgeInsets.all(20 * scale),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.all(8 * scale),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(12 * scale),
                  ),
                  child: Icon(icon, color: iconColor, size: 28 * scale),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16 * scale,
                      ),
                    ),
                    SizedBox(height: 4 * scale),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 11 * scale,
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
}

class HeaderCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    double h = size.height;
    double w = size.width;

    path.lineTo(0, h * 0.75);

    var controlPoint = Offset(w / 2, h);
    var endPoint = Offset(w, h * 0.75);

    path.quadraticBezierTo(
      controlPoint.dx,
      controlPoint.dy,
      endPoint.dx,
      endPoint.dy,
    );
    path.lineTo(w, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
