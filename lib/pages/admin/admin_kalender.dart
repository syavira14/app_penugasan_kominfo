import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../tugas/kelola_tugas_page.dart';
import '../../widgets/admin_header.dart';
import 'admin_sidebar.dart';

class AdminKalenderPage extends StatefulWidget {
  const AdminKalenderPage({super.key});

  @override
  State<AdminKalenderPage> createState() => _AdminKalenderPageState();
}

class _AdminKalenderPageState extends State<AdminKalenderPage> {
  // Palet warna (sama dengan kalender staff)
  static const Color kBiruTua = AppPalette.navy;
  static const Color kBiruSedang = AppPalette.blue;
  static const Color accentGold = Color(0xFFFFC107);
  static const Color kBgLight = AppPalette.background;

  static const double _sidebarBreakpoint = 900;
  static const int _sidebarIndex = 4; // posisi menu Kalender di sidebar

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  Stream<QuerySnapshot<Map<String, dynamic>>>? _assignmentStream;

  // Cache supaya data tugas & nama staff tidak diambil berulang kali
  final Map<String, Map<String, dynamic>> _tugasCache = {};
  final Map<String, String> _staffNameCache = {};

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
    // Admin membaca seluruh penugasan dari semua staff
    _assignmentStream = _firestore.collection('penugasan').snapshots();
  }

  // ------------------------------------------------------------------
  // HELPER
  // ------------------------------------------------------------------
  String _dateKey(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  DateTime? _asDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    return null;
  }

  // Tanggal penyerahan/pengumpulan hasil oleh staff (nama field bisa beragam)
  DateTime? _tglDiserahkan(Map<String, dynamic> a) {
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

  Color _getStatusColor(String rawStatus) {
    switch (rawStatus.toLowerCase()) {
      case 'disetujui':
        return AppTaskStatus.color('disetujui');
      case 'dikumpulkan':
        return AppTaskStatus.color('dikumpulkan');
      case 'revisi':
        return Colors.amber.shade900;
      case 'terkendala':
        return AppTaskStatus.color('terkendala');
      case 'berlangsung':
        return AppTaskStatus.color('berlangsung');
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

  void _goToMonth(DateTime newMonth) {
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

  void _changeMonth(int offset) {
    _goToMonth(DateTime(_focusedDay.year, _focusedDay.month + offset, 1));
  }

  // ------------------------------------------------------------------
  // DATA
  // ------------------------------------------------------------------
  Future<String> _getStaffName(String staffId) async {
    if (staffId.isEmpty) return 'Belum ditentukan';

    final cached = _staffNameCache[staffId];
    if (cached != null) return cached;

    String name = 'Staff tidak dikenal';
    try {
      final doc = await _firestore.collection('users').doc(staffId).get();
      if (doc.exists) {
        final d = doc.data() ?? {};
        final nama = (d['nama'] ?? d['name'] ?? '').toString().trim();
        final email = (d['email'] ?? '').toString().trim();
        if (nama.isNotEmpty) {
          name = nama;
        } else if (email.isNotEmpty) {
          name = email.split('@').first;
        }
      }
    } catch (_) {}

    _staffNameCache[staffId] = name;
    return name;
  }

  Future<Map<String, dynamic>?> _getTugas(String tugasId) async {
    final cached = _tugasCache[tugasId];
    if (cached != null) return cached;

    final doc = await _firestore.collection('tugas').doc(tugasId).get();
    if (!doc.exists) return null;

    final data = doc.data() ?? {};
    _tugasCache[tugasId] = data;
    return data;
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

        final tugasData = await _getTugas(tugasId);
        if (tugasData == null) continue;

        final String staffId =
            (assignmentData['staff_id'] ?? assignmentData['staff_uid'] ?? '')
                .toString();
        final String staffNama = await _getStaffName(staffId);

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
          events.putIfAbsent(_dateKey(tglMulai), () => []).add({
            "penugasan_id": assignment.id,
            "title": judulTugas,
            "time": _jam(tglMulai),
            "type": "Tugas Diberikan",
            "is_deadline": false,
            "status": statusTampil,
            "raw_status": rawStatus,
            "staff_nama": staffNama,
            "tenggat": tenggatText,
            "diberikan": diberikanText,
            "diserahkan": diserahkanText,
            "sudah_serah": sudahSerah,
          });
        }

        if (tglDeadline != null) {
          events.putIfAbsent(_dateKey(tglDeadline), () => []).add({
            "penugasan_id": assignment.id,
            "title": judulTugas,
            "time": _jam(tglDeadline),
            "type": "Batas Selesai ($statusTampil)",
            "is_deadline": true,
            "status": statusTampil,
            "raw_status": rawStatus,
            "staff_nama": staffNama,
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

  // ------------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double scale = (screenWidth / 375).clamp(0.85, 1.25);
    final bool showSidebar = screenWidth >= _sidebarBreakpoint;

    final Widget content = StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _assignmentStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Column(
            children: [
              AdminHeader(
                title: 'Kalender Penugasan',
                showSidebar: showSidebar,
              ),
              Expanded(
                child: Center(
                  child: Text("Gagal memuat data: ${snapshot.error}"),
                ),
              ),
            ],
          );
        }

        final assignments = snapshot.data?.docs ?? [];

        return FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
          future: _fetchTaskEvents(assignments),
          builder: (context, taskSnapshot) {
            final Map<String, List<Map<String, dynamic>>> events =
                taskSnapshot.data ?? {};

            final List<Map<String, dynamic>> currentEvents = List.from(
              events[_dateKey(_selectedDay)] ?? [],
            );
            currentEvents.sort((a, b) {
              final bool aD = a["is_deadline"] ?? false;
              final bool bD = b["is_deadline"] ?? false;
              if (aD && !bD) return -1;
              if (!aD && bD) return 1;
              return 0;
            });

            final bool isLoading =
                (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) ||
                taskSnapshot.data == null;

            return Column(
              children: [
                AdminHeader(
                  title: 'Kalender Penugasan',
                  showSidebar: showSidebar,
                ),
                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : LayoutBuilder(
                          builder: (context, c) {
                            final bool twoCol = c.maxWidth >= 700;
                            return SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              // Margin sama dengan halaman Status Karyawan
                              padding: EdgeInsets.all(showSidebar ? 24 : 16),
                              child: twoCol
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
                                        const SizedBox(width: 20),
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
                                        const SizedBox(height: 16),
                                        _buildTaskList(currentEvents, scale),
                                      ],
                                    ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );

    return Scaffold(
      backgroundColor: kBgLight,
      drawer: showSidebar
          ? null
          : const AdminSidebar(currentIndex: _sidebarIndex, isDrawer: true),
      body: showSidebar
          ? Row(
              children: [
                const AdminSidebar(currentIndex: _sidebarIndex),
                Expanded(child: content),
              ],
            )
          : content,
    );
  }

  // ------------------------------------------------------------------
  // KALENDER
  // ------------------------------------------------------------------
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
      padding: EdgeInsets.all(14 * scale),
      decoration: _cardDeco(),
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
                      fontSize: AppTypography.body * scale,
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
                    fontSize: AppTypography.small * scale,
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

              final bool isSelected =
                  date.year == _selectedDay.year &&
                  date.month == _selectedDay.month &&
                  date.day == _selectedDay.day;

              final bool isSunday = date.weekday == DateTime.sunday;
              final List<Map<String, dynamic>> dayEvents =
                  events[_dateKey(date)] ?? [];

              // Satu titik biru = ada jadwal tugas pada tanggal ini
              final bool hasEvent = dayEvents.isNotEmpty;

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
                          fontSize: AppTypography.small * scale,
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
                      if (hasEvent) ...[
                        SizedBox(height: 2 * scale),
                        _dot(
                          isSelected
                              ? accentGold
                              : (isCurrentMonth
                                    ? kBiruSedang
                                    : kBiruSedang.withOpacity(0.4)),
                          scale,
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

  BoxDecoration _cardDeco() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: kBiruTua.withOpacity(.05),
        blurRadius: 14,
        offset: const Offset(0, 4),
      ),
    ],
  );

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
                fontSize: AppTypography.small * scale,
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

  Widget _dot(Color color, double scale) {
    return Container(
      width: 4 * scale,
      height: 4 * scale,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }

  Widget _legendDot(Color color, String label, double scale) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7 * scale,
          height: 7 * scale,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: 5 * scale),
        Text(
          label,
          style: TextStyle(
            fontSize: AppTypography.caption * scale,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // DAFTAR TUGAS PADA TANGGAL TERPILIH
  // ------------------------------------------------------------------
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
                fontSize: AppTypography.section * scale,
                fontWeight: FontWeight.bold,
                color: kBiruTua,
              ),
            ),
            Text(
              "${_selectedDay.day}/${_selectedDay.month}/${_selectedDay.year}",
              style: TextStyle(
                fontSize: AppTypography.small * scale,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        SizedBox(height: 12 * scale),
        if (events.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: _cardDeco(),
            child: Center(
              child: Text(
                "Tidak ada jadwal pekerjaan pada tanggal ini",
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: AppTypography.body * scale,
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
              final String staffNama = (item["staff_nama"] ?? '-').toString();

              return InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const KelolaTugasPage()),
                ),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: EdgeInsets.all(16 * scale),
                  decoration: _cardDeco().copyWith(
                    border: Border(
                      left: BorderSide(
                        color: item["sudah_serah"] == true
                            ? Colors.green.shade600
                            : Colors.red.shade600,
                        width: 4 * scale,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Judul
                            Text(
                              item["title"]!,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: AppTypography.body * scale,
                                color: kBiruTua,
                              ),
                            ),
                            SizedBox(height: 6 * scale),

                            // Nama staff yang mengerjakan
                            Row(
                              children: [
                                Icon(
                                  Icons.person_outline_rounded,
                                  size: 14 * scale,
                                  color: kBiruSedang,
                                ),
                                SizedBox(width: 4 * scale),
                                Expanded(
                                  child: Text(
                                    staffNama,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: AppTypography.small * scale,
                                      fontWeight: FontWeight.w600,
                                      color: kBiruTua,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 4 * scale),

                            // Tanggal diberikan, tenggat & diserahkan
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
                          color: _getStatusBgColor(rawStatus),
                          borderRadius: BorderRadius.circular(8 * scale),
                        ),
                        child: Text(
                          item["status"]!,
                          style: TextStyle(
                            color: _getStatusColor(rawStatus),
                            fontSize: AppTypography.caption * scale,
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

  // ------------------------------------------------------------------
  // PICKER BULAN & TAHUN
  // ------------------------------------------------------------------
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
                    onPressed: () => setDialogState(() => tempYear--),
                  ),
                  Text(
                    "$tempYear",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: AppTypography.subtitle,
                      color: kBiruTua,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, color: kBiruSedang),
                    onPressed: () => setDialogState(() => tempYear++),
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
                      onTap: () => setDialogState(() => tempMonth = index + 1),
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
                            fontSize: AppTypography.body,
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
                    backgroundColor: AppPalette.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    _goToMonth(DateTime(tempYear, tempMonth, 1));
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
}
