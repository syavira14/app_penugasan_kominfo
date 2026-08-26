import 'package:flutter/material.dart';
import 'admin_navbar.dart';
import 'status_staff.dart';

class KelolaStaffPage extends StatefulWidget {
  const KelolaStaffPage({super.key});

  @override
  State<KelolaStaffPage> createState() => _KelolaStaffPageState();
}

class _KelolaStaffPageState extends State<KelolaStaffPage> {
  // Data dummy staf
  final List<Map<String, String>> staffList = [
    {
      "nama": "Syavira Fitri",
      "nip": "199508122026",
      "jabatan": "Pranata Humas",
      "wa": "081234567890",
      "status": "Tersedia",
    },
    {
      "nama": "Ahmad Dahlan",
      "nip": "199203152026",
      "jabatan": "Staf IT",
      "wa": "081398765432",
      "status": "Sibuk",
    },
    {
      "nama": "Budi Prayitno",
      "nip": "199001012026",
      "jabatan": "Desainer Grafis",
      "wa": "081122334455",
      "status": "Tersedia",
    },
  ];

  // Pop up Form Tambah Staff
  void _showTambahStaffModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Tambah Staff Baru",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B267B),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Center(
                child: CircleAvatar(
                  radius: 35,
                  backgroundColor: const Color(0xFF0066B3).withOpacity(0.1),
                  child: const Icon(
                    Icons.add_a_photo,
                    color: Color(0xFF0066B3),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              _buildModalTextField("Nama Lengkap"),
              _buildModalTextField("NIP"),
              _buildModalTextField("Jabatan"),
              _buildModalTextField("No. WhatsApp"),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0066B3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "Simpan Data Staff",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModalTextField(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FC),
      appBar: AppBar(
        title: const Text(
          "Kelola Staff",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1B267B), Color(0xFF0066B3)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // --- 1. SEARCH BAR & TOMBOL CARI (SESUAI SKETSA) ---
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 45,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: const TextField(
                      decoration: InputDecoration(
                        hintText: "Pencarian...",
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.only(top: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0066B3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onPressed: () {},
                  child: const Text(
                    "Cari",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // --- 2. TOMBOL + TAMBAH STAFF (KANAN BOTTOM SEARCH) ---
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B267B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                ),
                onPressed: _showTambahStaffModal,
                icon: const Icon(Icons.add, color: Colors.white, size: 18),
                label: const Text(
                  "Tambah Staff",
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // --- 3. GRID CARD STAF (2 KOLOM BERSAMPINGAN) ---
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, // 2 Card Bersampingan
                childAspectRatio: 0.58, // Menyesuaikan rasio tinggi card
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: staffList.length,
              itemBuilder: (context, index) {
                final staff = staffList[index];
                bool isTersedia = staff['status'] == "Tersedia";

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Foto Profil Lingkaran Atas
                      const CircleAvatar(
                        radius: 30,
                        backgroundColor: Color(0xFF0066B3),
                        child: Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Detail Data Staf
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Nama : ${staff['nama']}",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              "NIP : ${staff['nip']}",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              "Jabatan : ${staff['jabatan']}",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              "WA : ${staff['wa']}",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Divider(height: 12, thickness: 1),

                      // Status Aktif
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const StatusStaffPage(),
                          ),
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          decoration: BoxDecoration(
                            color: isTersedia
                                ? Colors.green.shade50
                                : Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            "Status : ${staff['status']}",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isTersedia
                                  ? Colors.green.shade800
                                  : Colors.orange.shade800,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Tombol Edit dan Hapus Bersampingan
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 30,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  side: const BorderSide(color: Colors.amber),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () {},
                                child: const Text(
                                  "Edit",
                                  style: TextStyle(
                                    color: Colors.amber,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: SizedBox(
                              height: 30,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  side: const BorderSide(
                                    color: Colors.redAccent,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () {},
                                child: const Text(
                                  "Hapus",
                                  style: TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AdminBottomNavigationBar(currentIndex: 2),
    );
  }
}
