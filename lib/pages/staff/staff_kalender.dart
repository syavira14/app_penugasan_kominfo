import 'package:flutter/material.dart';

class StaffKalenderPage extends StatefulWidget {
  const StaffKalenderPage({super.key});

  @override
  State<StaffKalenderPage> createState() => _StaffKalenderPageState();
}

class _StaffKalenderPageState extends State<StaffKalenderPage> {
  static const Color redDark = Color(0xFF1A1464);
  static const Color redMid = Color(0xFF1D5FA0);
  static const Color redLight = Color(0xFF4FA6DE);
  static const Color accentGold = Color(0xFFFFC107);
  static const Color bgLight = Color(0xFFF7F9FB);

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  // Data Dummy Tugas Berdasarkan Tanggal (Tahun-Bulan-Hari)
  final Map<String, List<Map<String, String>>> _events = {
    "2026-09-02": [
      {
        "title": "Meeting Progress Proyek UI/UX",
        "time": "09:00 - 10:30 WIB",
        "type": "Penting",
      },
      {
        "title": "Review Modul Kalender Staff",
        "time": "13:00 - 15:00 WIB",
        "type": "Tugas",
      },
    ],
    "2026-09-05": [
      {
        "title": "Penyerahan Laporan Bulanan",
        "time": "16:00 WIB",
        "type": "Deadline",
      },
    ],
    "2026-09-12": [
      {
        "title": "Koordinasi Tim Frontend",
        "time": "10:00 - 11:30 WIB",
        "type": "Meeting",
      },
    ],
  };

  // Helper Formatter Kunci Tanggal (yyyy-MM-dd)
  String _dateKey(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  // Pindah Bulan
  void _changeMonth(int offset) {
    setState(() {
      _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + offset, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double scale = (screenWidth / 375).clamp(0.85, 1.25);
    final String selectedKey = _dateKey(_selectedDay);
    final List<Map<String, String>> currentEvents = _events[selectedKey] ?? [];

    return Scaffold(
      backgroundColor: bgLight,
      body: Stack(
        children: [
          // ==========================================
          // 1. LAYER BACKGROUND BIRU GRADASI (HEADER)
          // ==========================================
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipPath(
              clipper: HeaderCurveClipper(curveHeightOffset: 150 * scale),
              child: Container(
                width: double.infinity,
                height: 170 * scale,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [redLight, redMid, redDark],
                    stops: [0.0, 0.45, 1.0],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: -30 * scale,
                      right: -30 * scale,
                      child: _decorCircle(
                        150 * scale,
                        Colors.white.withOpacity(0.08),
                      ),
                    ),
                    Positioned(
                      top: 40 * scale,
                      left: -40 * scale,
                      child: _decorCircle(
                        120 * scale,
                        accentGold.withOpacity(0.12),
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
                // --- TOP BAR (Navigasi Back & Judul Kalender) ---
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
                        "Kalender",
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

                // --- CONTAINER KALENDER & DAFTAR TUGAS ---
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 18 * scale),
                      child: Column(
                        children: [
                          // KARTU KALENDER INTERAKTIF
                          _buildCalendarCard(scale),

                          SizedBox(height: 20 * scale),

                          // DAFTAR PEKERJAAN PADA TANGGAL TERPILIH
                          _buildTaskList(currentEvents, scale),
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

  // ==========================================
  // WIDGET KALENDER INTERAKTIF
  // ==========================================
  Widget _buildCalendarCard(double scale) {
    final List<String> monthNames = [
      "Januari",
      "Februari",
      "Maret",
      "April",
      "Mei",
      "Juni",
      "Juli",
      "Agustus",
      "September",
      "Oktober",
      "November",
      "Desember",
    ];

    final int daysInMonth = DateTime(
      _focusedDay.year,
      _focusedDay.month + 1,
      0,
    ).day;
    final int firstWeekday = DateTime(
      _focusedDay.year,
      _focusedDay.month,
      1,
    ).weekday; // 1 = Senin

    return Container(
      padding: EdgeInsets.all(16 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22 * scale),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header Bulan & Panah Navigasi
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${monthNames[_focusedDay.month - 1]} ${_focusedDay.year}",
                style: TextStyle(
                  fontSize: 16 * scale,
                  fontWeight: FontWeight.bold,
                  color: redDark,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.chevron_left,
                      color: redMid,
                      size: 24 * scale,
                    ),
                    onPressed: () => _changeMonth(-1),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.chevron_right,
                      color: redMid,
                      size: 24 * scale,
                    ),
                    onPressed: () => _changeMonth(1),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 10 * scale),

          // Nama Hari (Sen, Sel, Rab, dst)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ["Sen", "Sel", "Rab", "Kam", "Jum", "Sab", "Ming"]
                .map(
                  (day) => SizedBox(
                    width: 35 * scale,
                    child: Text(
                      day,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12 * scale,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          Divider(height: 20 * scale),

          // Grid Tanggal
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: (firstWeekday - 1) + daysInMonth,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
            ),
            itemBuilder: (context, index) {
              if (index < firstWeekday - 1) {
                return const SizedBox.shrink(); // Empty space sebelum tanggal 1
              }

              final int dayNumber = index - (firstWeekday - 2);
              final DateTime date = DateTime(
                _focusedDay.year,
                _focusedDay.month,
                dayNumber,
              );
              final String key = _dateKey(date);

              final bool isSelected =
                  date.year == _selectedDay.year &&
                  date.month == _selectedDay.month &&
                  date.day == _selectedDay.day;

              final bool hasEvents =
                  _events.containsKey(key) && _events[key]!.isNotEmpty;

              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedDay = date;
                  });
                },
                borderRadius: BorderRadius.circular(12 * scale),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? redMid : Colors.transparent,
                    borderRadius: BorderRadius.circular(12 * scale),
                    border: isSelected
                        ? null
                        : Border.all(color: Colors.transparent),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "$dayNumber",
                        style: TextStyle(
                          fontSize: 13 * scale,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                      ),

                      // INDIKATOR TITIK TUGAS
                      if (hasEvents) ...[
                        SizedBox(height: 3 * scale),
                        Container(
                          width: 5 * scale,
                          height: 5 * scale,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected ? accentGold : redMid,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ==========================================
  // WIDGET DAFTAR PEKERJAAN
  // ==========================================
  Widget _buildTaskList(List<Map<String, String>> events, double scale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Pekerjaan Hari Ini",
              style: TextStyle(
                fontSize: 16 * scale,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Text(
              "${_selectedDay.day}/${_selectedDay.month}/${_selectedDay.year}",
              style: TextStyle(
                fontSize: 12 * scale,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        SizedBox(height: 12 * scale),

        if (events.isEmpty)
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20 * scale),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16 * scale),
            ),
            child: Center(
              child: Text(
                "Tidak ada jadwal pekerjaan hari ini",
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 13 * scale,
                ),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: events.length,
            itemBuilder: (context, index) {
              final item = events[index];
              return Container(
                margin: EdgeInsets.only(bottom: 10 * scale),
                padding: EdgeInsets.all(14 * scale),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16 * scale),
                  border: Border(
                    left: BorderSide(color: redMid, width: 4 * scale),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item["title"]!,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14 * scale,
                            ),
                          ),
                          SizedBox(height: 4 * scale),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 14 * scale,
                                color: Colors.grey,
                              ),
                              SizedBox(width: 4 * scale),
                              Text(
                                item["time"]!,
                                style: TextStyle(
                                  fontSize: 11 * scale,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10 * scale,
                        vertical: 4 * scale,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3EEFA),
                        borderRadius: BorderRadius.circular(8 * scale),
                      ),
                      child: Text(
                        item["type"]!,
                        style: TextStyle(
                          color: redMid,
                          fontSize: 10 * scale,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _decorCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

// Custom Clipper Header
class HeaderCurveClipper extends CustomClipper<Path> {
  final double curveHeightOffset;

  HeaderCurveClipper({required this.curveHeightOffset});

  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, curveHeightOffset - 20);

    final controlPoint = Offset(size.width / 2, curveHeightOffset + 25);
    final endPoint = Offset(size.width, curveHeightOffset - 20);

    path.quadraticBezierTo(
      controlPoint.dx,
      controlPoint.dy,
      endPoint.dx,
      endPoint.dy,
    );

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => true;
}
