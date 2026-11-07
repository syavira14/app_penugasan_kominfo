import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../widgets/app_layout.dart';
import 'tugas_detail_page.dart';

// Alias tipe data agar aman saat di-copy paste dan mudah dibaca
typedef JsonMap = Map<String, dynamic>;
typedef EventList = List<JsonMap>;
typedef EventMap = Map<String, EventList>;
typedef QuerySnap = QuerySnapshot<JsonMap>;
typedef QueryDoc = QueryDocumentSnapshot<JsonMap>;

class StaffKalenderPage extends StatefulWidget {
  const StaffKalenderPage({super.key});

  @override
  State<StaffKalenderPage> createState() => _StaffKalenderPageState();
}

class _StaffKalenderPageState extends State<StaffKalenderPage> {
  static const Color kBiruTua = Color(0xFF1A1464);
  static const Color kBiruSedang = Color(0xFF1D5FA0);
  static const Color kBiruMuda = Color(0xFF4FA6DE);
  static const Color accentGold = Color(0xFFFFC107);
  static const Color kBgLight = Color(0xFFF7F9FB);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  Stream<QuerySnap>? _assignmentStream;

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
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    return null;
  }

  DateTime? _tglDiserahkan(JsonMap a) {
    const keys = [
      'tanggal_dikumpulkan',
      'tanggal_pengumpulan',
      'tanggal_diserahkan',
      'tanggal_kumpul',
      'waktu_dikumpulkan',
      'dikumpulkan_pada',
      'submitted_at',
    ];
    for (final k in keys) {
      final d = _asDate(a[k]);
      if (d != null) return d;
    }
    return null;
  }

  String _jam(DateTime d) =>
      "${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} WIB";

  String _tanggalJam(DateTime d) =>
      "${d.day} ${_monthNames[d.month - 1].substring(0, 3)} ${d.year}, ${_jam(d)}";

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

  Future<EventMap> _fetchTaskEvents(List<QueryDoc> assignments) async {
    final EventMap events = {};

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

        final String rawStatus = (assignmentData['status'] ?? 'pending')
            .toString();
        final String statusTampil = _statusUi(rawStatus);
        final String tenggatText = tglDeadline != null
            ? _tanggalJam(tglDeadline)
            : '-';
        final String diberikanText = tglMulai != null
            ? _tanggalJam(tglMulai)
            : '-';

        final DateTime? tglSerah = _tglDiserahkan(assignmentData);
        final bool sudahSerah = const [
          'dikumpulkan',
          'revisi',
          'disetujui',
          'selesai',
        ].contains(rawStatus.toLowerCase());
        final String diserahkanText = tglSerah != null
            ? _tanggalJam(tglSerah)
            : (sudahSerah
                  ? 'Sudah diserahkan (tanggal tidak tercatat)'
                  : 'Belum diserahkan');

        if (tglMulai != null) {
          final String keyMulai = _dateKey(tglMulai);
          events.putIfAbsent(keyMulai, () => []).add({
            "penugasan_id": assignment.id,
            "title": judulTugas,
            "time": _jam(tglMulai),
            "type": "Tugas Diberikan",
            "is_deadline": false,
            "status": statusTampil,
            "raw_status": rawStatus,
            "tenggat": tenggatText,
            "diberikan": diberikanText,
            "diserahkan": diserahkanText,
            "sudah_serah": sudahSerah,
          });
        }

        if (tglDeadline != null) {
          final String keyDeadline = _dateKey(tglDeadline);
          events.putIfAbsent(keyDeadline, () => []).add({
            "penugasan_id": assignment.id,
            "title": judulTugas,
            "time": _jam(tglDeadline),
            "type": "Batas Selesai ($statusTampil)",
            "is_deadline": true,
            "status": statusTampil,
            "raw_status": rawStatus,
            "tenggat": tenggatText,
            "diberikan": diberikanText,
            "diserahkan": diserahkanText,
            "sudah_serah": sudahSerah,
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
                    icon: const Icon(Icons.chevron_left, color: kBiruSedang),
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
                      color: kBiruTua,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, color: kBiruSedang),
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
                          color: isSelected
                              ? kBiruSedang
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? kBiruSedang
                                : Colors.transparent,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _monthNames[index].substring(0, 3),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isSelected ? Colors.white : kBiruTua,
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
                    backgroundColor: kBiruSedang,
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

  Widget _infoRow(
    IconData icon,
    Color color,
    String label,
    String value,
    double scale,
  ) {
    return Padding(
      padding: EdgeInsets.only(top: 4 * scale),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14 * scale, color: color),
          SizedBox(width: 5 * scale),
          Expanded(
            child: Text(
              '$label: $value',
              style: TextStyle(
                fontSize: 11.5 * scale,
                color: color == kBiruSedang ? Colors.grey.shade700 : color,
                fontWeight: color == kBiruSedang
                    ? FontWeight.normal
                    : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double scale = (screenWidth / 375).clamp(0.85, 1.25);
    final bool isWide = screenWidth >= 700;

    return Scaffold(
      backgroundColor: kBgLight,
      body: StreamBuilder<QuerySnap>(
        stream: _assignmentStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Gagal memuat data: ${snapshot.error}"));
          }

          final List<QueryDoc> assignments = snapshot.data?.docs ?? [];

          return FutureBuilder<EventMap>(
            future: _fetchTaskEvents(assignments),
            builder: (context, taskSnapshot) {
              final EventMap events = taskSnapshot.data ?? {};

              final String selectedKey = _dateKey(_selectedDay);
              final EventList currentEvents = List.from(
                events[selectedKey] ?? [],
              );

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

              return Column(
                children: [
                  // HEADER GRADIENT FLAT / LURUS
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [kBiruMuda, kBiruSedang, kBiruTua],
                        stops: [0.0, 0.5, 1.0],
                      ),
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 16 * scale),
                        child: ResponsiveContent(
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: () => Navigator.maybePop(context),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: Icon(
                                  Icons.arrow_back,
                                  color: Colors.white,
                                  size: 24 * scale,
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    "Kalender Penugasan",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18 * scale,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 24 * scale),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // CONTENT
                  Expanded(
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ResponsiveContent(
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                0,
                                16 * scale,
                                0,
                                12 * scale,
                              ),
                              child: SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                child: isWide
                                    ? Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            flex: 6,
                                            child: _buildCalendarCard(
                                              events,
                                              scale,
                                            ),
                                          ),
                                          SizedBox(width: 20 * scale),
                                          Expanded(
                                            flex: 5,
                                            child: _buildTaskList(
                                              currentEvents,
                                              scale,
                                            ),
                                          ),
                                        ],
                                      )
                                    : Column(
                                        children: [
                                          _buildCalendarCard(events, scale),
                                          SizedBox(height: 20 * scale),
                                          _buildTaskList(currentEvents, scale),
                                        ],
                                      ),
                              ),
                            ),
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

  Widget _buildCalendarCard(EventMap events, double scale) {
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
      padding: EdgeInsets.all(12 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20 * scale),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
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
                icon: Icon(
                  Icons.chevron_left,
                  color: kBiruSedang,
                  size: 26 * scale,
                ),
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
                      fontSize: 15 * scale,
                      fontWeight: FontWeight.bold,
                      color: kBiruTua,
                    ),
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.chevron_right,
                  color: kBiruSedang,
                  size: 26 * scale,
                ),
                onPressed: () => _changeMonth(1),
              ),
            ],
          ),
          SizedBox(height: 4 * scale),

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
          Divider(height: 12 * scale),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: totalCells,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.25,
              mainAxisSpacing: 3,
              crossAxisSpacing: 3,
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
              final EventList dayEvents = events[key] ?? [];

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
                    color: isSelected ? kBiruSedang : Colors.transparent,
                    borderRadius: BorderRadius.circular(12 * scale),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "${date.day}",
                        style: TextStyle(
                          fontSize: 12 * scale,
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
                        SizedBox(height: 2 * scale),
                        Container(
                          width: 4 * scale,
                          height: 4 * scale,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? accentGold
                                : (isCurrentMonth
                                      ? kBiruSedang
                                      : kBiruSedang.withOpacity(0.4)),
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

  Widget _buildTaskList(EventList events, double scale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Pekerjaan Tanggal Ini",
              style: TextStyle(
                fontSize: 17 * scale,
                fontWeight: FontWeight.bold,
                color: kBiruTua,
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
                borderRadius: BorderRadius.circular(20 * scale),
                child: Container(
                  margin: EdgeInsets.only(bottom: 12 * scale),
                  padding: EdgeInsets.all(16 * scale),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20 * scale),
                    border: Border(
                      left: BorderSide(
                        color: item["sudah_serah"] == true
                            ? Colors.green.shade600
                            : Colors.red.shade600,
                        width: 4 * scale,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
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
                                color: kBiruTua,
                              ),
                            ),
                            SizedBox(height: 4 * scale),
                            _infoRow(
                              Icons.play_circle_outline_rounded,
                              kBiruSedang,
                              'Diberikan',
                              item["diberikan"].toString(),
                              scale,
                            ),
                            _infoRow(
                              Icons.event_rounded,
                              Colors.red.shade700,
                              'Tenggat terakhir dikumpulkan',
                              item["tenggat"].toString(),
                              scale,
                            ),
                            _infoRow(
                              item["sudah_serah"] == true
                                  ? Icons.check_circle_rounded
                                  : Icons.warning_amber_rounded,
                              item["sudah_serah"] == true
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                              'Diserahkan',
                              item["diserahkan"].toString(),
                              scale,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8 * scale),
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
                          item["status"]!,
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
}
