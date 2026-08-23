import 'package:flutter/material.dart';

class StaffKalenderPage extends StatefulWidget {
  const StaffKalenderPage({super.key});

  @override
  State<StaffKalenderPage> createState() => _StaffKalenderPageState();
}

class _StaffKalenderPageState extends State<StaffKalenderPage> {
  int selectedDay = 19; // Hari yang terpilih (contoh default tgl 19)

  // Data Dummy Agenda Tugas/Kegiatan berdasarkan Tanggal
  final List<Map<String, dynamic>> agendaList = [
    {
      "tanggal": 19,
      "jam": "09:00 - 11:30 WIB",
      "judul": "Rapat Koordinasi Tim Humas",
      "tipe": "Rapat",
      "lokasi": "Ruang Rapat Kominfo Lt. 2",
      "warna": Colors.blue,
    },
    {
      "tanggal": 19,
      "jam": "23:59 WIB",
      "judul": "Deadline Input Data Pembaruan Website",
      "tipe": "Deadline Tugas",
      "lokasi": "Sistem Informasi",
      "warna": Colors.redAccent,
    },
    {
      "tanggal": 22,
      "jam": "13:00 - 15:00 WIB",
      "judul": "Peliputan Kunjungan Kerja Walkot",
      "tipe": "Tugas Lapangan",
      "lokasi": "Balai Kota",
      "warna": Colors.orange,
    },
  ];

  @override
  Widget build(BuildContext context) {
    // Filter agenda berdasarkan tanggal yang diklik
    final agendaHariIni = agendaList
        .where((a) => a['tanggal'] == selectedDay)
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FC),
      body: Column(
        children: [
          // --- 1. HEADER GRADASI ---
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1B267B), Color(0xFF0066B3)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(25)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Kalender & Agenda Staff",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "Agustus 2026",
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // --- 2. GRID KALENDER BULANAN (MINI) ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Nama Hari Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: ["Min", "Sen", "Sel", "Rab", "Kam", "Jum", "Sab"]
                        .map(
                          (hari) => Text(
                            hari,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const Divider(height: 20),

                  // Grid Tanggal
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                    itemCount: 31, // Contoh 31 Hari
                    itemBuilder: (context, index) {
                      int dayNum = index + 1;
                      bool isSelected = dayNum == selectedDay;
                      bool hasAgenda = agendaList.any(
                        (a) => a['tanggal'] == dayNum,
                      );

                      return InkWell(
                        onTap: () {
                          setState(() {
                            selectedDay = dayNum;
                          });
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF0066B3)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF0066B3)
                                  : Colors.grey.shade200,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "$dayNum",
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.black87,
                                  fontSize: 12,
                                ),
                              ),
                              if (hasAgenda)
                                Container(
                                  margin: const EdgeInsets.only(top: 2),
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected
                                        ? Colors.white
                                        : const Color(0xFF0066B3),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // --- 3. JUDUL AGENDA HARIAN ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Agenda $selectedDay Agustus",
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B267B),
                  ),
                ),
                Text(
                  "${agendaHariIni.length} Kegiatan",
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // --- 4. DAFTAR CARD AGENDA/DEADLINE ---
          Expanded(
            child: agendaHariIni.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_available,
                          size: 48,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Tidak ada agenda atau tugas di tanggal ini",
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: agendaHariIni.length,
                    itemBuilder: (context, index) {
                      final item = agendaHariIni[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border(
                            left: BorderSide(color: item['warna'], width: 4),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: (item['warna'] as Color).withOpacity(
                                      0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    item['tipe'],
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: item['warna'],
                                    ),
                                  ),
                                ),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.access_time,
                                      size: 12,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      item['jam'],
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item['judul'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 12,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  item['lokasi'],
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
