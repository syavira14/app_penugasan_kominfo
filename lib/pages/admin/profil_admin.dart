import 'package:flutter/material.dart';

class ProfilAdminPage extends StatefulWidget {
  const ProfilAdminPage({super.key});

  @override
  State<ProfilAdminPage> createState() => _ProfilAdminPageState();
}

class _ProfilAdminPageState extends State<ProfilAdminPage> {
  // Data Profil Admin (Bisa Dinamis)
  String namaAdmin = "Budi Santoso, S.Kom.";
  String nipAdmin = "198803202015031001";
  String jabatanAdmin = "Kepala Bidang Humas & Informasi";
  String emailAdmin = "budi.santoso@kominfo.go.id";
  String noHpAdmin = "0812-9876-5432";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FC),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- HEADER GRADASI DENGAN FOTO PROFIL ---
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  height: 220,
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 50, 20, 0),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF1B267B),
                        Color(0xFF0066B3),
                        Color(0xFF00A8E8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(30),
                    ),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Profil Pengguna",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Administrator SITUGAS Kominfo",
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),

                // Avatar Foto Profil Melayang (Floating)
                Positioned(
                  bottom: -45,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const CircleAvatar(
                      radius: 45,
                      backgroundColor: Color(0xFF0066B3),
                      child: Icon(Icons.person, size: 50, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 55),

            // Nama & Jabatan Utama
            Text(
              namaAdmin,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B267B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              jabatanAdmin,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),

            const SizedBox(height: 25),

            // --- CARD DETAIL INFORMASI ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildInfoTile(
                      icon: Icons.badge_outlined,
                      label: "NIP",
                      value: nipAdmin,
                    ),
                    const Divider(height: 20),
                    _buildInfoTile(
                      icon: Icons.email_outlined,
                      label: "Email",
                      value: emailAdmin,
                    ),
                    const Divider(height: 20),
                    _buildInfoTile(
                      icon: Icons.phone_android_outlined,
                      label: "No. WhatsApp",
                      value: noHpAdmin,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // --- TOMBOL LOGOUT ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade50,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    // Logika Keluar/Logout
                  },
                  icon: const Icon(
                    Icons.logout,
                    color: Colors.redAccent,
                    size: 20,
                  ),
                  label: const Text(
                    "Keluar Akun",
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // Widget Pembantu untuk Baris Informasi
  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF0066B3).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFF0066B3), size: 20),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
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
