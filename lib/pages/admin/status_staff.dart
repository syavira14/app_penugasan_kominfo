import 'package:flutter/material.dart';

class StatusStaffPage extends StatefulWidget {
  const StatusStaffPage({super.key});

  @override
  State<StatusStaffPage> createState() => _StatusStaffPageState();
}

class _StatusStaffPageState extends State<StatusStaffPage> {
  String selectedFilter = "Semua";

  // Data Dummy Staf
  final List<Map<String, String>> staffList = [
    {
      "nama": "Syavira Fitri",
      "jabatan": "Pranata Humas",
      "wa": "081234567890",
      "status": "Tersedia",
    },
    {
      "nama": "Ahmad Dahlan",
      "jabatan": "Staf IT",
      "wa": "081398765432",
      "status": "Sibuk",
    },
    {
      "nama": "Budi Prayitno",
      "jabatan": "Desainer Grafis",
      "wa": "081122334455",
      "status": "Tersedia",
    },
    {
      "nama": "Siti Nurhaliza",
      "jabatan": "Pengelola Data",
      "wa": "085711223344",
      "status": "Cuti",
    },
  ];

  @override
  Widget build(BuildContext context) {
    // Filter Data Berdasarkan Filter Chip
    final filteredList = staffList.where((staff) {
      if (selectedFilter == "Semua") return true;
      return staff['status'] == selectedFilter;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FC),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- HEADER DENGAN GRADASI ---
            Container(
              padding: const EdgeInsets.fromLTRB(20, 50, 20, 25),
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
              child: const Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Status & Ketersediaan Staff",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Pantau kondisi staff secara real-time",
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // --- 1. SEARCH BAR DI ATAS FILTER ---
                  Container(
                    height: 45,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: const TextField(
                      decoration: InputDecoration(
                        hintText: "Cari nama atau jabatan...",
                        prefixIcon: Icon(
                          Icons.search,
                          size: 20,
                          color: Colors.grey,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.only(top: 10),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // --- 2. FILTER CHIPS (Semua, Tersedia, Sibuk, Cuti) ---
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ["Semua", "Tersedia", "Sibuk", "Cuti"].map((
                        filter,
                      ) {
                        final isSelected = selectedFilter == filter;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(filter),
                            selected: isSelected,
                            selectedColor: const Color(0xFF0066B3),
                            backgroundColor: Colors.white,
                            side: BorderSide(
                              color: isSelected
                                  ? const Color(0xFF0066B3)
                                  : Colors.grey.shade300,
                            ),
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : Colors.black87,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 12,
                            ),
                            onSelected: (val) {
                              setState(() => selectedFilter = filter);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // --- 3. GRID STAFF CARD (2 KOLOM BERSAMPINGAN) ---
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.68, // Menyesuaikan proporsi card
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      final staff = filteredList[index];
                      bool isTersedia = staff['status'] == "Tersedia";
                      bool isSibuk = staff['status'] == "Sibuk";

                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            // --- BADGE STATUS DI POJOK KANAN ATAS ---
                            Positioned(
                              top: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: isTersedia
                                      ? Colors.green.shade100
                                      : (isSibuk
                                            ? Colors.orange.shade100
                                            : Colors.red.shade100),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  staff['status']!,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: isTersedia
                                        ? Colors.green.shade800
                                        : (isSibuk
                                              ? Colors.orange.shade800
                                              : Colors.red.shade800),
                                  ),
                                ),
                              ),
                            ),

                            // --- ISI KONTEN CARD ---
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const SizedBox(height: 10),
                                // Foto Profil Lingkaran
                                const CircleAvatar(
                                  radius: 26,
                                  backgroundColor: Color(0xFF0066B3),
                                  child: Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Text Detail Staf
                                SizedBox(
                                  width: double.infinity,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        staff['nama']!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        staff['jabatan']!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF0066B3),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "WA: ${staff['wa']}",
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const Spacer(),

                                // --- SIMBOL IKON TAMBAH TUGAS (KHUSUS STATUS TERSEDIA) ---
                                if (isTersedia)
                                  SizedBox(
                                    width: double.infinity,
                                    height: 32,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF0066B3,
                                        ),
                                        padding: EdgeInsets.zero,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                      onPressed: () {
                                        // Aksi Beri Perintah Tugas
                                      },
                                      child: const Icon(
                                        Icons
                                            .add_task_rounded, // Simbol Ikon Tambah
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                  )
                                else
                                  const SizedBox(
                                    height: 32,
                                  ), // Spacer transparan agar tinggi card tetap sama
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
          ],
        ),
      ),
    );
  }
}
