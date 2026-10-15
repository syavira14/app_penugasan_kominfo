import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'tugas_detail_page.dart';

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

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  Stream<QuerySnapshot<Map<String, dynamic>>>? _assignmentStream;

  static const List<String> _monthNames = [
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

  @override
  void initState() {
    super.initState();
    _initStream();
  }

  void _initStream() {
    final user = _auth.currentUser;
    if (user != null) {
      _assignmentStream = _firestore
          .collection('penugasan')
          .where('staff_id', isEqualTo: user.uid)
          .snapshots();
    }
  }

  String _dateKey(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  DateTime? _asDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    return null;
  }

  // Mengubah status DB menjadi label bahasa Indonesia yang ramah UI
  String _statusUi(String rawStatus) {
    switch (rawStatus.toLowerCase()) {
      case 'berlangsung':
        return 'Berlangsung';
      case 'dikumpulkan':
        return 'Menunggu Disetujui';
      case 'revisi':
        return 'Revisi';
      case 'disetujui':
        return 'Selesai';
      case 'terkendala':
        return 'Terkendala';
      default:
        return 'Pending';
    }
  }

  void _changeMonth(int offset) {
    final DateTime newMonth = DateTime(
      _focusedDay.year,
      _focusedDay.month + offset,
      1,
    );
    final DateTime now = DateTime.now();

    setState(() {
      _focusedDay = newMonth;
      if (newMonth.year == now.year && newMonth.month == now.month) {
        _selectedDay = DateTime(now.year, now.month, now.day);
      } else {
        _selectedDay = DateTime(newMonth.year, newMonth.month, 1);
      }
    });
  }

  Future<Map<String, List<Map<String, dynamic>>>> _fetchTaskEvents(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> assignments,
  ) async {
    final Map<String, List<Map<String, dynamic>>> events = {};

    for (final assignment in assignments) {
      try {
        final assignmentData = assignment.data();
        final tugasId = (assignmentData['tugas_id'] ?? '').toString();

        if (tugasId.isEmpty) continue;

        final tugasDoc = await _firestore
            .collection('tugas')
            .doc(tugasId)
            .get();
        if (!tugasDoc.exists) continue;

        final tugasData = tugasDoc.data() ?? {};

        final DateTime? tglMulai =
            _asDate(tugasData['tanggal_mulai_tugas']) ??
            _asDate(tugasData['tanggal_tugas_diberikan']);
        final DateTime? tglDeadline = _asDate(
          tugasData['tanggal_selesai_tugas'],
        );

        final String judulTugas = (tugasData['judul'] ?? 'Tugas Baru')
            .toString();

        // Membaca status real-time dari Firestore penugasan
        final String rawStatus = (assignmentData['status'] ?? 'pending')
            .toString();
        final String statusTampil = _statusUi(rawStatus);

        // 1. Tanggal Mulai Tugas Diberikan
        if (tglMulai != null) {
          final String keyMulai = _dateKey(tglMulai);
          events.putIfAbsent(keyMulai, () => []).add({
            "penugasan_id": assignment.id,
            "title": judulTugas,
            "time":
                "${tglMulai.hour.toString().padLeft(2, '0')}:${tglMulai.minute.toString().padLeft(2, '0')} WIB",
            "type": "Tugas Diberikan",
            "is_deadline": false,
            "status": statusTampil,
            "raw_status": rawStatus,
          });
        }

        // 2. Tanggal Deadline / Batas Selesai
        if (tglDeadline != null) {
          final String keyDeadline = _dateKey(tglDeadline);
          events.putIfAbsent(keyDeadline, () => []).add({
            "penugasan_id": assignment.id,
            "title": "DEADLINE: $judulTugas",
            "time":
                "${tglDeadline.hour.toString().padLeft(2, '0')}:${tglDeadline.minute.toString().padLeft(2, '0')} WIB",
            "type":
                "Batas Selesai ($statusTampil)", // Status real-time disisipkan
            "is_deadline": true,
            "status": statusTampil,
            "raw_status": rawStatus,
          });
        }
      } catch (_) {}
    }

    return events;
  }

  void _showMonthYearPicker() {
    int tempYear = _focusedDay.year;
    int tempMonth = _focusedDay.month;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              titlePadding: const EdgeInsets.all(16),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, color: redMid),
                    onPressed: () {
                      setDialogState(() {
                        tempYear--;
                      });
                    },
                  ),
                  Text(
                    "$tempYear",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: redDark,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, color: redMid),
                    onPressed: () {
                      setDialogState(() {
                        tempYear++;
                      });
                    },
                  ),
                ],
              ),
              content: SizedBox(
                width: 300,
                height: 220,
                child: GridView.builder(
                  shrinkWrap: true,
                  itemCount: 12,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 2.0,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemBuilder: (context, index) {
                    final isSelected = (index + 1) == tempMonth;
                    return InkWell(
                      onTap: () {
                        setDialogState(() {
                          tempMonth = index + 1;
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? redMid : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? redMid : Colors.transparent,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _monthNames[index].substring(0, 3),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isSelected ? Colors.white : redDark,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text(
                    "Batal",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: redMid,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    final DateTime newMonth = DateTime(tempYear, tempMonth, 1);
                    final DateTime now = DateTime.now();

                    setState(() {
                      _focusedDay = newMonth;
                      if (newMonth.year == now.year &&
                          newMonth.month == now.month) {
                        _selectedDay = DateTime(now.year, now.month, now.day);
                      } else {
                        _selectedDay = DateTime(
                          newMonth.year,
                          newMonth.month,
                          1,
                        );
                      }
                    });
                    Navigator.pop(dialogContext);
                  },
                  child: const Text("Pilih"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Menentukan warna badge status berdasarkan kondisi pengerjaan staf
  Color _getStatusColor(String rawStatus) {
    switch (rawStatus.toLowerCase()) {
      case 'disetujui':
        return Colors.green.shade700;
      case 'dikumpulkan':
        return Colors.blue.shade700;
      case 'revisi':
        return Colors.amber.shade900;
      case 'terkendala':
        return Colors.red.shade700;
      case 'berlangsung':
        return Colors.orange.shade800;
      default:
        return Colors.grey.shade700;
    }
  }

  Color _getStatusBgColor(String rawStatus) {
    switch (rawStatus.toLowerCase()) {
      case 'disetujui':
        return Colors.green.shade50;
      case 'dikumpulkan':
        return Colors.blue.shade50;
      case 'revisi':
        return Colors.amber.shade50;
      case 'terkendala':
        return Colors.red.shade50;
      case 'berlangsung':
        return Colors.orange.shade50;
      default:
        return const Color(0xFFE3EEFA);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double scale = (screenWidth / 375).clamp(0.85, 1.25);

    return Scaffold(
      backgroundColor: bgLight,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _assignmentStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Gagal memuat data: ${snapshot.error}"));
          }

          final assignments = snapshot.data?.docs ?? [];

          return FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
            future: _fetchTaskEvents(assignments),
            builder: (context, taskSnapshot) {
              final Map<String, List<Map<String, dynamic>>> events =
                  taskSnapshot.data ?? {};

              final String selectedKey = _dateKey(_selectedDay);
              final List<Map<String, dynamic>> currentEvents = List.from(
                events[selectedKey] ?? [],
              );

              // URUTAN DEADLINE DITARUH PALING ATAS
              currentEvents.sort((a, b) {
                final bool aIsDeadline = a["is_deadline"] ?? false;
                final bool bIsDeadline = b["is_deadline"] ?? false;
                if (aIsDeadline && !bIsDeadline) return -1;
                if (!aIsDeadline && bIsDeadline) return 1;
                return 0;
              });

              final bool isLoading =
                  snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData;

              return Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: ClipPath(
                      clipper: HeaderCurveClipper(
                        curveHeightOffset: 150 * scale,
                      ),
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
                  SafeArea(
                    child: Column(
                      children: [
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
                                "Kalender Penugasan",
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
                        Expanded(
                          child: isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : SingleChildScrollView(
                                  physics: const BouncingScrollPhysics(),
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 18 * scale,
                                    ),
                                    child: Column(
                                      children: [
                                        _buildCalendarCard(events, scale),
                                        SizedBox(height: 20 * scale),
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
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCalendarCard(
    Map<String, List<Map<String, dynamic>>> events,
    double scale,
  ) {
    final int daysInMonth = DateTime(
      _focusedDay.year,
      _focusedDay.month + 1,
      0,
    ).day;

    final int firstWeekday = DateTime(
      _focusedDay.year,
      _focusedDay.month,
      1,
    ).weekday;

    final int prevMonthDays = DateTime(
      _focusedDay.year,
      _focusedDay.month,
      0,
    ).day;

    final int leadingPadding = firstWeekday - 1;
    final int totalCells = ((leadingPadding + daysInMonth) / 7).ceil() * 7;

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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.chevron_left, color: redMid, size: 26 * scale),
                onPressed: () => _changeMonth(-1),
              ),
              InkWell(
                onTap: _showMonthYearPicker,
                borderRadius: BorderRadius.circular(8 * scale),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 8 * scale,
                    vertical: 4 * scale,
                  ),
                  child: Text(
                    "${_monthNames[_focusedDay.month - 1]} ${_focusedDay.year}",
                    style: TextStyle(
                      fontSize: 16 * scale,
                      fontWeight: FontWeight.bold,
                      color: redDark,
                    ),
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.chevron_right,
                  color: redMid,
                  size: 26 * scale,
                ),
                onPressed: () => _changeMonth(1),
              ),
            ],
          ),
          SizedBox(height: 10 * scale),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ["Sen", "Sel", "Rab", "Kam", "Jum", "Sab", "Ming"].map((
              day,
            ) {
              final isMingguHeader = day == "Ming";
              return SizedBox(
                width: 35 * scale,
                child: Text(
                  day,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12 * scale,
                    color: isMingguHeader
                        ? Colors.red.shade600
                        : Colors.grey.shade600,
                  ),
                ),
              );
            }).toList(),
          ),
          Divider(height: 20 * scale),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: totalCells,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
            ),
            itemBuilder: (context, index) {
              DateTime date;
              bool isCurrentMonth = true;

              if (index < leadingPadding) {
                final int dayNum = prevMonthDays - (leadingPadding - index - 1);
                date = DateTime(
                  _focusedDay.year,
                  _focusedDay.month - 1,
                  dayNum,
                );
                isCurrentMonth = false;
              } else if (index >= leadingPadding + daysInMonth) {
                final int dayNum = index - (leadingPadding + daysInMonth) + 1;
                date = DateTime(
                  _focusedDay.year,
                  _focusedDay.month + 1,
                  dayNum,
                );
                isCurrentMonth = false;
              } else {
                final int dayNum = index - leadingPadding + 1;
                date = DateTime(_focusedDay.year, _focusedDay.month, dayNum);
              }

              final String key = _dateKey(date);

              final bool isSelected =
                  date.year == _selectedDay.year &&
                  date.month == _selectedDay.month &&
                  date.day == _selectedDay.day;

              final bool isSunday = date.weekday == DateTime.sunday;
              final List<Map<String, dynamic>> dayEvents = events[key] ?? [];

              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedDay = date;
                    if (!isCurrentMonth) {
                      _focusedDay = DateTime(date.year, date.month, 1);
                    }
                  });
                },
                borderRadius: BorderRadius.circular(12 * scale),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? redMid : Colors.transparent,
                    borderRadius: BorderRadius.circular(12 * scale),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "${date.day}",
                        style: TextStyle(
                          fontSize: 13 * scale,
                          fontWeight: isSelected || (isSunday && isCurrentMonth)
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected
                              ? Colors.white
                              : (!isCurrentMonth
                                    ? Colors.grey.shade400
                                    : (isSunday
                                          ? Colors.red.shade600
                                          : Colors.black87)),
                        ),
                      ),
                      if (dayEvents.isNotEmpty) ...[
                        SizedBox(height: 3 * scale),
                        Container(
                          width: 5 * scale,
                          height: 5 * scale,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? accentGold
                                : (isCurrentMonth
                                      ? redMid
                                      : redMid.withOpacity(0.4)),
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

  Widget _buildTaskList(List<Map<String, dynamic>> events, double scale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Pekerjaan Tanggal Ini",
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
                "Tidak ada jadwal pekerjaan pada tanggal ini",
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
              final bool isDeadline = item["is_deadline"] ?? false;
              final String rawStatus = item["raw_status"] ?? "pending";

              final Color statusTextColor = _getStatusColor(rawStatus);
              final Color statusBgColor = _getStatusBgColor(rawStatus);

              return InkWell(
                onTap: () {
                  if (item["penugasan_id"] != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            TugasDetailPage(penugasanId: item["penugasan_id"]),
                      ),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(16 * scale),
                child: Container(
                  margin: EdgeInsets.only(bottom: 10 * scale),
                  padding: EdgeInsets.all(14 * scale),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16 * scale),
                    border: Border(
                      left: BorderSide(
                        color: isDeadline ? Colors.red.shade600 : redMid,
                        width: 4 * scale,
                      ),
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
                                color: isDeadline
                                    ? Colors.red.shade900
                                    : Colors.black87,
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
                          color: statusBgColor,
                          borderRadius: BorderRadius.circular(8 * scale),
                        ),
                        child: Text(
                          item["type"]!,
                          style: TextStyle(
                            color: statusTextColor,
                            fontSize: 10 * scale,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
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
