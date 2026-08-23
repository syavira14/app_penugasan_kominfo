import 'package:flutter/material.dart';

class StaffDashboardPage extends StatefulWidget {
  const StaffDashboardPage({super.key});

  @override
  State<StaffDashboardPage> createState() => _StaffDashboardPageState();
}

class _StaffDashboardPageState extends State<StaffDashboardPage> {
  int tugasAktif = 3;
  int tugasSelesai = 12;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FC),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- HEADER GRADASI ---
            Container(
              padding: const EdgeInsets.fromLTRB(20, 50, 20, 30),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1B267B), Color(0xFF0066B3)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(25),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Halo, Syavira! 👋",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Staff - Pranata Humas",
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white24,
                    child: IconButton(
                      icon: const Icon(Icons.person, color: Colors.white),
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // --- 2 CARD STATISTIK DINAMIS ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      title: "Tugas Aktif",
                      value: "$tugasAktif",
                      icon: Icons.pending_actions_rounded,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0066B3), Color(0xFF00A8E8)],
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildStatCard(
                      title: "Total Selesai",
                      value: "$tugasSelesai",
                      icon: Icons.task_alt_rounded,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1B267B), Color(0xFF0066B3)],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            // --- TUGAS PRIORITAS ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Tugas Prioritas Hari Ini",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B267B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "#T048",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0066B3),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                "⏳ Tenggat: 2 Jam",
                                style: TextStyle(
                                  color: Colors.amber,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Upload Poster Literasi Digital",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "👤 Pemberi: Bpk. Budi (Kabid)",
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0066B3),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {},
                            icon: const Icon(
                              Icons.rocket_launch,
                              color: Colors.white,
                              size: 16,
                            ),
                            label: const Text(
                              "Kerjakan Tugas",
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Gradient gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
