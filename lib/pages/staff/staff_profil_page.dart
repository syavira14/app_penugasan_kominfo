import 'package:flutter/material.dart';
import '../auth/welcome_page.dart';

class StaffProfilPage extends StatelessWidget {
  const StaffProfilPage({super.key});

  // Skema warna disamakan dengan Dashboard Staff
  static const Color redDark = Color(0xFF1A1464);
  static const Color redMid = Color(0xFF1D5FA0);
  static const Color redLight = Color(0xFF4FA6DE);
  static const Color accentGold = Color(0xFFFFC107);
  static const Color bgLight = Color(0xFFF7F9FB);

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double screenWidth = MediaQuery.of(context).size.width;
    final double scale = (screenWidth / 375).clamp(0.85, 1.25);

    return Scaffold(
      backgroundColor: bgLight,
      body: Stack(
        children: [
          // ==========================================
          // 1. LAYER BACKGROUND GRADIENT DENGAN LENGKUNGAN
          // ==========================================
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipPath(
              clipper: HeaderCurveClipper(),
              child: Container(
                width: double.infinity,
                height: screenHeight * 0.38,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [redLight, redMid, redDark],
                  ),
                ),
                child: Stack(
                  children: [
                    // Dekorasi lingkaran halus (Blobs)
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

          // ==========================================
          // 2. KONTEN UTAMA
          // ==========================================
          SafeArea(
            child: Column(
              children: [
                // --- TOP BAR (Navigasi Back & Judul) ---
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16 * scale,
                    vertical: 10 * scale,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Text(
                        "Profil Saya",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20 * scale,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 10 * scale),

                // --- ISi PROFIL (Scrollable) ---
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20 * scale),
                      child: Column(
                        children: [
                          // FOTO PROFIL & NAMA
                          Center(
                            child: Column(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(4 * scale),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 10,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: CircleAvatar(
                                    radius: 50 * scale,
                                    backgroundColor: redMid,
                                    child: Icon(
                                      Icons.person,
                                      size: 55 * scale,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 12 * scale),
                                Text(
                                  "Syavira Fitri",
                                  style: TextStyle(
                                    fontSize: 20 * scale,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                SizedBox(height: 4 * scale),
                                Text(
                                  "Staff Kominfo",
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13 * scale,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: 25 * scale),

                          // KARTU INFORMASI PROFIL
                          Container(
                            padding: EdgeInsets.all(16 * scale),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22 * scale),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 15,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                _buildProfileItem(
                                  icon: Icons.email_outlined,
                                  title: "Email",
                                  value: "syavira@kominfo.go.id",
                                  scale: scale,
                                ),
                                Divider(
                                  height: 20 * scale,
                                  color: Colors.grey.shade200,
                                ),
                                _buildProfileItem(
                                  icon: Icons.phone_outlined,
                                  title: "WhatsApp",
                                  value: "081234567890",
                                  scale: scale,
                                ),
                                Divider(
                                  height: 20 * scale,
                                  color: Colors.grey.shade200,
                                ),
                                _buildProfileItem(
                                  icon: Icons.business_outlined,
                                  title: "Departemen",
                                  value: "Komunikasi & Informatika",
                                  scale: scale,
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: 30 * scale),

                          // TOMBOL KELUAR / LOGOUT
                          SizedBox(
                            width: double.infinity,
                            height: 52 * scale,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFEBEE),
                                foregroundColor: Colors.red.shade700,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    16 * scale,
                                  ),
                                ),
                              ),
                              onPressed: () => Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const WelcomePage(),
                                ),
                                (_) => false,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.logout, size: 20 * scale),
                                  SizedBox(width: 8 * scale),
                                  Text(
                                    "KELUAR",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14 * scale,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          SizedBox(height: 20 * scale),
                        ],
                      ),
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

  // Widget Item Profil
  Widget _buildProfileItem({
    required IconData icon,
    required String title,
    required String value,
    required double scale,
  }) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(10 * scale),
          decoration: BoxDecoration(
            color: const Color(0xFFE3EEFA),
            borderRadius: BorderRadius.circular(12 * scale),
          ),
          child: Icon(icon, color: redMid, size: 22 * scale),
        ),
        SizedBox(width: 14 * scale),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 11 * scale,
                  color: Colors.grey.shade500,
                ),
              ),
              SizedBox(height: 2 * scale),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14 * scale,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Custom Clipper Lengkungan Header
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
