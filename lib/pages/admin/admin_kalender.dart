import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../tugas/kelola_tugas_page.dart' hide AppColors;
import '../../tugas/tugas_model.dart';
import 'admin_navbar.dart';
import 'dashboard_admin_page.dart';

class AdminKalenderPage extends StatefulWidget {
  const AdminKalenderPage({super.key});

  @override
  State<AdminKalenderPage> createState() => _AdminKalenderPageState();
}

class _AdminKalenderPageState extends State<AdminKalenderPage> {
  static const _staffStorageKey = 'kelola_staff_list';
  DateTime _bulanAktif = DateTime.now();
  DateTime _tanggalTerpilih = DateTime.now();
  Map<String, String> _fotoStaff = {};

  final List<TugasModel> _daftarTugas = [
    TugasModel(
      id: '1',
      judul: 'Pemeliharaan Server Data Center',
      deskripsi: 'Pengecekan rutin dan pemeliharaan server utama.',
      tempat: 'Ruang Server, Kantor Dinas Kominfo',
      tanggal: DateTime(2026, 9, 10),
      jam: const TimeOfDay(hour: 9, minute: 0),
      staff: const ['Ahmad Fauzi'],
      prioritas: 'Tinggi',
    ),
    TugasModel(
      id: '2',
      judul: 'Update Konten Portal Layanan Publik',
      deskripsi: 'Memperbarui informasi layanan pada portal resmi.',
      tempat: 'Kantor Dinas Kominfo Lt. 2',
      tanggal: DateTime(2026, 9, 10),
      jam: const TimeOfDay(hour: 13, minute: 30),
      staff: const ['Siti Nurhaliza'],
      prioritas: 'Sedang',
    ),
    TugasModel(
      id: '3',
      judul: 'Audit Keamanan Jaringan',
      deskripsi: 'Pemeriksaan celah keamanan pada jaringan internal.',
      tempat: 'Ruang IT, Kantor Dinas Kominfo',
      tanggal: DateTime(2026, 9, 15),
      jam: const TimeOfDay(hour: 10, minute: 0),
      staff: const ['Budi Santoso', 'Ahmad Fauzi'],
      prioritas: 'Tinggi',
    ),
    TugasModel(
      id: '4',
      judul: 'Dokumentasi Rapat Koordinasi',
      deskripsi: 'Menyusun notulen dan dokumentasi hasil rapat.',
      tempat: 'Ruang Rapat Utama',
      tanggal: DateTime(2026, 9, 22),
      jam: const TimeOfDay(hour: 14, minute: 0),
      staff: const ['Siti Nurhaliza'],
      prioritas: 'Rendah',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadStaffPhotos();
  }

  Future<void> _loadStaffPhotos() async {
    final preferences = await SharedPreferences.getInstance();
    final storedStaff = preferences.getString(_staffStorageKey);
    if (!mounted || storedStaff == null) return;

    final decoded = jsonDecode(storedStaff);
    if (decoded is! List) return;

    final photos = <String, String>{};
    for (final item in decoded.whereType<Map>()) {
      final name = item['nama']?.toString();
      final photo = item['imageBase64']?.toString();
      if (name != null && photo != null && photo.isNotEmpty) {
        photos[name] = photo;
      }
    }
    if (mounted) setState(() => _fotoStaff = photos);
  }

  List<TugasModel> _tugasPadaTanggal(DateTime tanggal) {
    return _daftarTugas
        .where((tugas) => DateUtils.isSameDay(tugas.tanggal, tanggal))
        .toList();
  }

  void _ubahBulan(int jumlah) {
    setState(() {
      _bulanAktif = DateTime(_bulanAktif.year, _bulanAktif.month + jumlah);
      _tanggalTerpilih = DateTime(_bulanAktif.year, _bulanAktif.month, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tugasTerpilih = _tugasPadaTanggal(_tanggalTerpilih);
    return withAdminReadableText(
      context,
      Scaffold(
        backgroundColor: AppColors.latarAbu,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          toolbarHeight: 96,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
          ),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1B267B),
                  Color(0xFF0066B3),
                  Color(0xFF00A8E8),
                ],
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
            ),
          ),
          title: const Text(
            'Kalender Penugasan',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
          children: [
            _buildCalendarCard(),
            const SizedBox(height: 22),
            Text(
              'Detail ${formatTanggalIndo(_tanggalTerpilih)}',
              style: const TextStyle(
                color: AppColors.biruTua,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            if (tugasTerpilih.isEmpty)
              _EmptyCalendarState(tanggal: _tanggalTerpilih)
            else
              ...tugasTerpilih.map(_buildTaskDetail),
          ],
        ),
        bottomNavigationBar: const AdminBottomNavigationBar(currentIndex: 2),
      ),
    );
  }

  Widget _buildCalendarCard() {
    final firstDay = DateTime(_bulanAktif.year, _bulanAktif.month, 1);
    final daysInMonth = DateTime(
      _bulanAktif.year,
      _bulanAktif.month + 1,
      0,
    ).day;
    final leadingDays = firstDay.weekday - 1;
    final totalCells = ((leadingDays + daysInMonth + 6) ~/ 7) * 7;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.biruTua.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                tooltip: 'Bulan sebelumnya',
                onPressed: () => _ubahBulan(-1),
                icon: const Icon(Icons.chevron_left_rounded),
                color: AppColors.biruTua,
              ),
              Text(
                _namaBulan(_bulanAktif),
                style: const TextStyle(
                  color: AppColors.biruTua,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              IconButton(
                tooltip: 'Bulan berikutnya',
                onPressed: () => _ubahBulan(1),
                icon: const Icon(Icons.chevron_right_rounded),
                color: AppColors.biruTua,
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Row(
            children: [
              _WeekdayLabel('Sen'),
              _WeekdayLabel('Sel'),
              _WeekdayLabel('Rab'),
              _WeekdayLabel('Kam'),
              _WeekdayLabel('Jum'),
              _WeekdayLabel('Sab'),
              _WeekdayLabel('Min'),
            ],
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: totalCells,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 4,
              childAspectRatio: 0.78,
            ),
            itemBuilder: (context, index) {
              final day = index - leadingDays + 1;
              if (day < 1 || day > daysInMonth) return const SizedBox.shrink();

              final date = DateTime(_bulanAktif.year, _bulanAktif.month, day);
              final selected = DateUtils.isSameDay(date, _tanggalTerpilih);
              final today = DateUtils.isSameDay(date, DateTime.now());
              final tasks = _tugasPadaTanggal(date);

              return _CalendarDay(
                date: date,
                selected: selected,
                today: today,
                tasks: tasks,
                photos: _fotoStaff,
                onTap: () => setState(() => _tanggalTerpilih = date),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTaskDetail(TugasModel tugas) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const KelolaTugasPage()),
          ),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.assignment_rounded,
                  color: AppColors.biruSedang,
                  size: 27,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tugas.judul,
                        style: const TextStyle(
                          color: AppColors.biruTua,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        '${formatJam(tugas.jam)}  |  ${tugas.tempat}',
                        style: const TextStyle(
                          color: AppColors.abuTeks,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: tugas.staff
                            .map(
                              (staff) => _StaffChip(
                                name: staff,
                                photo: _fotoStaff[staff],
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.abuTeks,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _namaBulan(DateTime date) {
    const names = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return '${names[date.month - 1]} ${date.year}';
  }
}

class _CalendarDay extends StatelessWidget {
  final DateTime date;
  final bool selected;
  final bool today;
  final List<TugasModel> tasks;
  final Map<String, String> photos;
  final VoidCallback onTap;

  const _CalendarDay({
    required this.date,
    required this.selected,
    required this.today,
    required this.tasks,
    required this.photos,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final background = selected
        ? AppColors.biruSedang.withOpacity(0.22)
        : today
        ? AppColors.biruSedang
        : Colors.transparent;
    final foreground = today && !selected ? Colors.white : AppColors.biruTua;
    final staff = tasks.expand((task) => task.staff).toSet().take(3).toList();

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
          border: selected
              ? Border.all(color: AppColors.biruSedang, width: 1.5)
              : null,
        ),
        padding: const EdgeInsets.only(top: 5, left: 2, right: 2),
        child: Column(
          children: [
            Text(
              '${date.day}',
              style: TextStyle(
                color: foreground,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            if (staff.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: staff.map((name) {
                  final image = photos[name];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: CircleAvatar(
                      radius: 10,
                      backgroundColor: Colors.white,
                      backgroundImage: image == null
                          ? null
                          : MemoryImage(base64Decode(image)),
                      child: image == null
                          ? Text(
                              name.substring(0, 1),
                              style: const TextStyle(
                                color: AppColors.biruTua,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _StaffChip extends StatelessWidget {
  final String name;
  final String? photo;

  const _StaffChip({required this.name, required this.photo});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: CircleAvatar(
        radius: 11,
        backgroundColor: AppColors.biruSedang.withOpacity(0.12),
        backgroundImage: photo == null
            ? null
            : MemoryImage(base64Decode(photo!)),
        child: photo == null
            ? Text(
                name.substring(0, 1),
                style: const TextStyle(
                  color: AppColors.biruTua,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              )
            : null,
      ),
      label: Text(name),
      labelStyle: const TextStyle(
        color: AppColors.biruTua,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: AppColors.biruSedang.withOpacity(0.08),
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 5),
    );
  }
}

class _WeekdayLabel extends StatelessWidget {
  final String label;

  const _WeekdayLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.abuTeks,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _EmptyCalendarState extends StatelessWidget {
  final DateTime tanggal;

  const _EmptyCalendarState({required this.tanggal});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.event_available_rounded,
            color: AppColors.cyan,
            size: 38,
          ),
          const SizedBox(height: 8),
          Text(
            'Belum ada tugas pada ${formatTanggalIndo(tanggal)}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.abuTeks, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
