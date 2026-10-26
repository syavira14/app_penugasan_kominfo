import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../widgets/app_layout.dart';
import 'tugas_detail_page.dart';

class RekapanPribadiPage extends StatefulWidget {
  const RekapanPribadiPage({super.key});

  @override
  State<RekapanPribadiPage> createState() => _RekapanPribadiPageState();
}

class _RekapanPribadiPageState extends State<RekapanPribadiPage> {
  static const Color kBiruTua = Color(0xFF1A1464);
  static const Color kBiruSedang = Color(0xFF1D5FA0);
  static const Color kBiruMuda = Color(0xFF4FA6DE);
  static const Color kBgLight = Color(0xFFF7F9FB);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // State Filter Bulan & Tahun
  DateTime _selectedDate = DateTime.now();

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

  Stream<QuerySnapshot<Map<String, dynamic>>> get _assignmentStream {
    final user = _auth.currentUser;
    if (user == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('penugasan')
        .where('staff_id', isEqualTo: user.uid)
        .snapshots();
  }

  DateTime? _asDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    return null;
  }

  void _showMonthYearPicker() {
    int tempYear = _selectedDate.year;
    int tempMonth = _selectedDate.month;

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
                    setState(() {
                      _selectedDate = DateTime(tempYear, tempMonth, 1);
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

  Future<List<Map<String, dynamic>>> _loadFilteredTasks(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> assignments,
  ) async {
    final List<Map<String, dynamic>> list = [];

    for (final assignment in assignments) {
      try {
        final assignmentData = assignment.data();
        final tugasId = (assignmentData['tugas_id'] ?? '').toString();
        if (tugasId.isEmpty) continue;

        final tugasDoc = await _firestore
            .collection('tugas')
            .doc(tugasId)
            .get();
        final tugasData = tugasDoc.data() ?? {};

        // Ambil tanggal penugasan (mulai/diberikan)
        final DateTime? tglTugas =
            _asDate(tugasData['tanggal_mulai_tugas']) ??
            _asDate(tugasData['tanggal_tugas_diberikan']) ??
            _asDate(assignmentData['created_at']);

        // Filter berdasarkan Bulan & Tahun terpilih
        if (tglTugas != null) {
          if (tglTugas.year != _selectedDate.year ||
              tglTugas.month != _selectedDate.month) {
            continue; // Lompati data yang beda bulan/tahun
          }
        }

        list.add({
          'penugasan_id': assignment.id,
          'tugas_id': tugasId,
          'judul': tugasData['judul'] ?? '-',
          'deskripsi': tugasData['deskripsi'] ?? '-',
          'status': (assignmentData['status'] ?? 'pending').toString(),
          'tanggal_diberikan': tglTugas,
          'tanggal_selesai': _asDate(tugasData['tanggal_selesai_tugas']),
        });
      } catch (_) {}
    }

    return list;
  }

  Map<String, dynamic> _hitungStatusKesibukan(int tugasAktif) {
    if (tugasAktif >= 5) {
      return {
        'label': 'Sangat Sibuk / Padat',
        'sub': 'Menerima $tugasAktif tugas aktif pada periode ini',
        'color': Colors.red.shade700,
        'bg': Colors.red.shade50,
        'icon': Icons.warning_amber_rounded,
      };
    } else if (tugasAktif >= 3) {
      return {
        'label': 'Cukup Sibuk',
        'sub': 'Menangani $tugasAktif tugas berjalan pada periode ini',
        'color': Colors.orange.shade800,
        'bg': Colors.orange.shade50,
        'icon': Icons.access_time_filled_rounded,
      };
    } else if (tugasAktif >= 1) {
      return {
        'label': 'Beban Normal',
        'sub': 'Memiliki $tugasAktif tugas aktif pada periode ini',
        'color': kBiruSedang,
        'bg': Colors.blue.shade50,
        'icon': Icons.check_circle_rounded,
      };
    } else {
      return {
        'label': 'Senggang / Siap Tugas',
        'sub': 'Tidak ada beban tugas aktif pada periode ini',
        'color': Colors.green.shade700,
        'bg': Colors.green.shade50,
        'icon': Icons.sentiment_very_satisfied_rounded,
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final double scale = (width / 375).clamp(0.85, 1.25);

    return Scaffold(
      backgroundColor: kBgLight,
      body: Column(
        children: [
          // HEADER GRADIENT
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
                            "Rekapan & Monitoring Kinerja",
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

          // BODY CONTENT
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _assignmentStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      "Gagal memuat data rekapan:\n${snapshot.error}",
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final assignments = snapshot.data?.docs ?? [];

                return FutureBuilder<List<Map<String, dynamic>>>(
                  future: _loadFilteredTasks(assignments),
                  builder: (context, taskSnapshot) {
                    if (taskSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final allTasks = taskSnapshot.data ?? [];

                    int total = allTasks.length;
                    int selesai = 0;
                    int terkendala = 0;
                    int pending = 0;
                    int berlangsung = 0;

                    for (final item in allTasks) {
                      final st = item['status'].toString().toLowerCase();
                      if (st == 'disetujui' || st == 'selesai') {
                        selesai++;
                      } else if (st == 'terkendala') {
                        terkendala++;
                      } else if (st == 'pending') {
                        pending++;
                      } else {
                        berlangsung++;
                      }
                    }

                    int tugasAktif = pending + berlangsung + terkendala;
                    final infoKesibukan = _hitungStatusKesibukan(tugasAktif);
                    double persentaseSelesai = total > 0
                        ? (selesai / total) * 100
                        : 0.0;

                    return ResponsiveContent(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          0,
                          16 * scale,
                          0,
                          12 * scale,
                        ),
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // BAR FILTER PERIODE BULAN & TAHUN
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Periode Laporan",
                                    style: TextStyle(
                                      fontSize: 15 * scale,
                                      fontWeight: FontWeight.bold,
                                      color: kBiruTua,
                                    ),
                                  ),
                                  InkWell(
                                    onTap: _showMonthYearPicker,
                                    borderRadius: BorderRadius.circular(
                                      12 * scale,
                                    ),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 12 * scale,
                                        vertical: 6 * scale,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(
                                          12 * scale,
                                        ),
                                        border: Border.all(
                                          color: kBiruSedang,
                                          width: 1.2,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.calendar_month,
                                            size: 16 * scale,
                                            color: kBiruSedang,
                                          ),
                                          SizedBox(width: 6 * scale),
                                          Text(
                                            "${_monthNames[_selectedDate.month - 1]} ${_selectedDate.year}",
                                            style: TextStyle(
                                              fontSize: 12.5 * scale,
                                              fontWeight: FontWeight.bold,
                                              color: kBiruSedang,
                                            ),
                                          ),
                                          SizedBox(width: 4 * scale),
                                          Icon(
                                            Icons.arrow_drop_down,
                                            size: 18 * scale,
                                            color: kBiruSedang,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              SizedBox(height: 14 * scale),

                              // KARTU MONITORING INDIKATOR KESIBUKAN
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(16 * scale),
                                decoration: BoxDecoration(
                                  color: infoKesibukan['bg'] as Color,
                                  borderRadius: BorderRadius.circular(
                                    20 * scale,
                                  ),
                                  border: Border.all(
                                    color: (infoKesibukan['color'] as Color)
                                        .withOpacity(0.4),
                                    width: 1.2,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(12 * scale),
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        infoKesibukan['icon'] as IconData,
                                        color: infoKesibukan['color'] as Color,
                                        size: 28 * scale,
                                      ),
                                    ),
                                    SizedBox(width: 14 * scale),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Status Kesibukan Staff",
                                            style: TextStyle(
                                              fontSize: 11 * scale,
                                              color: Colors.grey.shade700,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          SizedBox(height: 2 * scale),
                                          Text(
                                            infoKesibukan['label'] as String,
                                            style: TextStyle(
                                              fontSize: 16 * scale,
                                              fontWeight: FontWeight.bold,
                                              color:
                                                  infoKesibukan['color']
                                                      as Color,
                                            ),
                                          ),
                                          SizedBox(height: 2 * scale),
                                          Text(
                                            infoKesibukan['sub'] as String,
                                            style: TextStyle(
                                              fontSize: 11.5 * scale,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              SizedBox(height: 18 * scale),

                              // KARTU RINGKASAN PRODUKTIVITAS
                              Text(
                                'Ringkasan Produktivitas',
                                style: TextStyle(
                                  fontSize: 16 * scale,
                                  fontWeight: FontWeight.bold,
                                  color: kBiruTua,
                                ),
                              ),
                              SizedBox(height: 10 * scale),

                              Container(
                                padding: EdgeInsets.all(16 * scale),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(
                                    20 * scale,
                                  ),
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
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          "Tingkat Penyelesaian",
                                          style: TextStyle(
                                            fontSize: 12.5 * scale,
                                            fontWeight: FontWeight.bold,
                                            color: kBiruTua,
                                          ),
                                        ),
                                        Text(
                                          "${persentaseSelesai.toStringAsFixed(0)}%",
                                          style: TextStyle(
                                            fontSize: 14 * scale,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 8 * scale),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: LinearProgressIndicator(
                                        value: total > 0 ? selesai / total : 0,
                                        minHeight: 8 * scale,
                                        backgroundColor: Colors.grey.shade200,
                                        color: Colors.green.shade600,
                                      ),
                                    ),
                                    SizedBox(height: 16 * scale),
                                    const Divider(height: 1),
                                    SizedBox(height: 16 * scale),
                                    Row(
                                      children: [
                                        _itemGridStat(
                                          "Total Tugas",
                                          "$total",
                                          kBiruTua,
                                          scale,
                                        ),
                                        _itemGridStat(
                                          "Selesai",
                                          "$selesai",
                                          Colors.green.shade700,
                                          scale,
                                        ),
                                        _itemGridStat(
                                          "Dalam Proses",
                                          "$tugasAktif",
                                          Colors.orange.shade800,
                                          scale,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              SizedBox(height: 20 * scale),

                              // LIST CATATAN PEKERJAAN PADA BULAN INI
                              Text(
                                'Catatan Pekerjaan Periode Ini ($total)',
                                style: TextStyle(
                                  fontSize: 16 * scale,
                                  fontWeight: FontWeight.bold,
                                  color: kBiruTua,
                                ),
                              ),
                              SizedBox(height: 10 * scale),

                              allTasks.isEmpty
                                  ? Center(
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 30 * scale,
                                        ),
                                        child: Text(
                                          "Tidak ada data tugas pada ${_monthNames[_selectedDate.month - 1]} ${_selectedDate.year}.",
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                    )
                                  : ListView.builder(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      itemCount: allTasks.length,
                                      itemBuilder: (context, index) {
                                        final item = allTasks[index];
                                        final st = item['status']
                                            .toString()
                                            .toLowerCase();

                                        Color colorStatus = Colors.blueGrey;
                                        String labelStatus = st.toUpperCase();

                                        if (st == 'disetujui' ||
                                            st == 'selesai') {
                                          colorStatus = Colors.green;
                                          labelStatus = 'SELESAI';
                                        } else if (st == 'terkendala') {
                                          colorStatus = Colors.red;
                                          labelStatus = 'TERKENDALA';
                                        } else if (st == 'berlangsung') {
                                          colorStatus = kBiruSedang;
                                          labelStatus = 'BERLANGSUNG';
                                        } else if (st == 'dikumpulkan') {
                                          colorStatus = Colors.blue;
                                          labelStatus = 'REVIEW ATASAN';
                                        }

                                        return InkWell(
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => TugasDetailPage(
                                                  penugasanId:
                                                      item['penugasan_id'],
                                                ),
                                              ),
                                            );
                                          },
                                          borderRadius: BorderRadius.circular(
                                            16 * scale,
                                          ),
                                          child: Container(
                                            margin: EdgeInsets.only(
                                              bottom: 10 * scale,
                                            ),
                                            padding: EdgeInsets.all(14 * scale),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    16 * scale,
                                                  ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(.03),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 3),
                                                ),
                                              ],
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        item['judul'],
                                                        style: TextStyle(
                                                          fontSize: 14 * scale,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: kBiruTua,
                                                        ),
                                                      ),
                                                      SizedBox(
                                                        height: 4 * scale,
                                                      ),
                                                      Text(
                                                        item['deskripsi'],
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: TextStyle(
                                                          fontSize:
                                                              11.5 * scale,
                                                          color: Colors
                                                              .grey
                                                              .shade600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Container(
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: 8 * scale,
                                                    vertical: 4 * scale,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: colorStatus
                                                        .withOpacity(0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8 * scale,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    labelStatus,
                                                    style: TextStyle(
                                                      fontSize: 10 * scale,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: colorStatus,
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
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemGridStat(String label, String value, Color color, double scale) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18 * scale,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 2 * scale),
          Text(
            label,
            style: TextStyle(fontSize: 11 * scale, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
