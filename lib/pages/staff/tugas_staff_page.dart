import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../tugas/tugas_model.dart';
import 'staff_navbar.dart';

class AppColors {
  static const Color biruTua = Color(0xFF0011CC);
  static const Color biruSedang = Color(0xFF0066FF);
  static const Color cyan = Color(0xFF00CCFF);
  static const Color putih = Colors.white;
  static const Color abuTeks = Color(0xFF5A6472);
  static const Color latarAbu = Color(0xFFF4F6FB);
  static const Color abuBorder = Color(0xFFE1E5F0);
  static const Color oranyeWarning = Color(0xFFFF9800);
}

enum StaffTaskFilter { semua, hariIni, belumSelesai, selesai }

enum StaffTaskSort { terdekat, terbaru, prioritas }

class TugasStaffPage extends StatefulWidget {
  const TugasStaffPage({super.key});

  @override
  State<TugasStaffPage> createState() => _TugasStaffPageState();
}

class _TugasStaffPageState extends State<TugasStaffPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  StaffTaskFilter _filter = StaffTaskFilter.semua;
  StaffTaskSort _sort = StaffTaskSort.terdekat;

  final List<TugasModel> _daftarTugas = [
    TugasModel(
      id: 'staff-1',
      judul: 'Monitoring Jaringan Kecamatan',
      deskripsi:
          'Cek stabilitas jaringan, dokumentasikan kendala, dan laporkan hasil monitoring ke koordinator.',
      tempat: 'Kantor Kecamatan Samarinda Ulu',
      latitude: -0.502106,
      longitude: 117.153709,
      tanggal: DateTime(2026, 8, 21),
      jam: const TimeOfDay(hour: 9, minute: 0),
      staff: const ['Ahmad Fauzi'],
      prioritas: 'Tinggi',
      selesai: false,
    ),
    TugasModel(
      id: 'staff-2',
      judul: 'Pemeliharaan Server Data Center',
      deskripsi:
          'Pengecekan rutin suhu ruangan, penggunaan storage, service utama, dan backup harian.',
      tempat: 'Ruang Server, Kantor Dinas Kominfo',
      latitude: -0.494823,
      longitude: 117.143615,
      tanggal: DateTime(2026, 8, 21),
      jam: const TimeOfDay(hour: 13, minute: 30),
      staff: const ['Ahmad Fauzi', 'Budi Santoso'],
      prioritas: 'Tinggi',
      selesai: false,
    ),
    TugasModel(
      id: 'staff-3',
      judul: 'Pendampingan Video Conference OPD',
      deskripsi:
          'Menyiapkan perangkat, jaringan, audio, dan memastikan sesi rapat berjalan stabil.',
      tempat: 'Ruang Rapat Utama Balai Kota',
      latitude: -0.501732,
      longitude: 117.149142,
      tanggal: DateTime(2026, 8, 22),
      jam: const TimeOfDay(hour: 10, minute: 0),
      staff: const ['Ahmad Fauzi'],
      prioritas: 'Sedang',
      selesai: false,
    ),
    TugasModel(
      id: 'staff-4',
      judul: 'Audit Keamanan Jaringan',
      deskripsi:
          'Pemeriksaan konfigurasi firewall, daftar perangkat aktif, dan celah akses jaringan internal.',
      tempat: 'Ruang IT, Kantor Dinas Kominfo',
      latitude: -0.494823,
      longitude: 117.143615,
      tanggal: DateTime(2026, 8, 24),
      jam: const TimeOfDay(hour: 8, minute: 30),
      staff: const ['Ahmad Fauzi', 'Budi Santoso'],
      prioritas: 'Sedang',
      selesai: false,
    ),
    TugasModel(
      id: 'staff-5',
      judul: 'Dokumentasi Rapat Koordinasi',
      deskripsi:
          'Membantu dokumentasi teknis, penyimpanan file, dan rekap kebutuhan perangkat rapat.',
      tempat: 'Kantor Dinas Kominfo Lt. 2',
      latitude: -0.494823,
      longitude: 117.143615,
      tanggal: DateTime(2026, 8, 19),
      jam: const TimeOfDay(hour: 14, minute: 0),
      staff: const ['Ahmad Fauzi'],
      prioritas: 'Rendah',
      selesai: true,
    ),
  ];

  List<TugasModel> get _tugasTertampil {
    final today = _dateOnly(DateTime.now());
    final query = _searchQuery.toLowerCase();
    final filtered = _daftarTugas.where((tugas) {
      final cocokPencarian =
          tugas.judul.toLowerCase().contains(query) ||
          tugas.deskripsi.toLowerCase().contains(query) ||
          tugas.tempat.toLowerCase().contains(query);
      final tanggal = _dateOnly(tugas.tanggal);
      final cocokFilter = switch (_filter) {
        StaffTaskFilter.semua => true,
        StaffTaskFilter.hariIni => tanggal == today,
        StaffTaskFilter.belumSelesai => !tugas.selesai,
        StaffTaskFilter.selesai => tugas.selesai,
      };
      return cocokPencarian && cocokFilter;
    }).toList();

    switch (_sort) {
      case StaffTaskSort.terdekat:
        filtered.sort((a, b) => _compareTerdekat(a, b, today));
        break;
      case StaffTaskSort.terbaru:
        filtered.sort((a, b) => _taskDateTime(b).compareTo(_taskDateTime(a)));
        break;
      case StaffTaskSort.prioritas:
        filtered.sort(
          (a, b) => _nilaiPrioritas(b).compareTo(_nilaiPrioritas(a)),
        );
        break;
    }
    return filtered;
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  DateTime _taskDateTime(TugasModel tugas) {
    return DateTime(
      tugas.tanggal.year,
      tugas.tanggal.month,
      tugas.tanggal.day,
      tugas.jam.hour,
      tugas.jam.minute,
    );
  }

  int _compareTerdekat(TugasModel a, TugasModel b, DateTime today) {
    final aDate = _dateOnly(a.tanggal);
    final bDate = _dateOnly(b.tanggal);
    final aIsToday = aDate == today;
    final bIsToday = bDate == today;
    if (aIsToday != bIsToday) return aIsToday ? -1 : 1;

    final aPast = aDate.isBefore(today);
    final bPast = bDate.isBefore(today);
    if (aPast != bPast) return aPast ? 1 : -1;

    if (aPast && bPast) return _taskDateTime(b).compareTo(_taskDateTime(a));
    return _taskDateTime(a).compareTo(_taskDateTime(b));
  }

  int _nilaiPrioritas(TugasModel tugas) {
    return switch (tugas.prioritas) {
      'Tinggi' => 3,
      'Sedang' => 2,
      _ => 1,
    };
  }

  void _showDetail(TugasModel tugas) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.putih,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _TaskDetailSheet(tugas: tugas),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.latarAbu,
      appBar: AppBar(
        backgroundColor: AppColors.biruTua,
        foregroundColor: AppColors.putih,
        automaticallyImplyLeading: false,
        title: const Text(
          'Tugas Staff',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: const BoxDecoration(
              color: AppColors.biruTua,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Cari judul, deskripsi, atau tempat...',
                    hintStyle: const TextStyle(
                      color: AppColors.abuTeks,
                      fontSize: 13,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.biruSedang,
                    ),
                    suffixIcon: _searchQuery.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: AppColors.abuTeks,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          ),
                    filled: true,
                    fillColor: AppColors.putih,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _FilterChip(
                        label: 'Semua',
                        selected: _filter == StaffTaskFilter.semua,
                        onTap: () =>
                            setState(() => _filter = StaffTaskFilter.semua),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Hari Ini',
                        selected: _filter == StaffTaskFilter.hariIni,
                        onTap: () =>
                            setState(() => _filter = StaffTaskFilter.hariIni),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Belum Selesai',
                        selected: _filter == StaffTaskFilter.belumSelesai,
                        onTap: () => setState(
                          () => _filter = StaffTaskFilter.belumSelesai,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Selesai',
                        selected: _filter == StaffTaskFilter.selesai,
                        onTap: () =>
                            setState(() => _filter = StaffTaskFilter.selesai),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.sort_rounded,
                      color: AppColors.putih,
                      size: 17,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<StaffTaskSort>(
                        value: _sort,
                        dropdownColor: AppColors.putih,
                        iconEnabledColor: AppColors.putih,
                        decoration: InputDecoration(
                          isDense: true,
                          filled: true,
                          fillColor: AppColors.putih.withOpacity(0.12),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: AppColors.putih.withOpacity(0.25),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.cyan),
                          ),
                        ),
                        selectedItemBuilder: (context) => const [
                          Text(
                            'Terdekat & hari ini di atas',
                            style: TextStyle(
                              color: AppColors.putih,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            'Tugas terbaru',
                            style: TextStyle(
                              color: AppColors.putih,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            'Prioritas tertinggi',
                            style: TextStyle(
                              color: AppColors.putih,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        items: const [
                          DropdownMenuItem(
                            value: StaffTaskSort.terdekat,
                            child: Text('Terdekat & hari ini di atas'),
                          ),
                          DropdownMenuItem(
                            value: StaffTaskSort.terbaru,
                            child: Text('Tugas terbaru'),
                          ),
                          DropdownMenuItem(
                            value: StaffTaskSort.prioritas,
                            child: Text('Prioritas tertinggi'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => _sort = value);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _tugasTertampil.isEmpty
                ? _EmptyState(query: _searchQuery)
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _tugasTertampil.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final tugas = _tugasTertampil[index];
                      return _StaffTaskCard(
                        tugas: tugas,
                        onTap: () => _showDetail(tugas),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: const StaffBottomNavigationBar(currentIndex: 1),
    );
  }
}

class _StaffTaskCard extends StatelessWidget {
  final TugasModel tugas;
  final VoidCallback onTap;

  const _StaffTaskCard({required this.tugas, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final Color priorityColor = switch (tugas.prioritas) {
      'Tinggi' => AppColors.oranyeWarning,
      'Rendah' => AppColors.cyan,
      _ => AppColors.biruSedang,
    };

    return Material(
      color: AppColors.putih,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.biruTua.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 78,
                decoration: BoxDecoration(
                  color: tugas.selesai ? AppColors.biruSedang : priorityColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            tugas.judul,
                            style: const TextStyle(
                              color: AppColors.biruTua,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _SmallBadge(
                          label: tugas.prioritas,
                          color: priorityColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _IconText(
                      icon: Icons.event_outlined,
                      text:
                          '${formatTanggalIndo(tugas.tanggal)} - ${formatJam(tugas.jam)}',
                    ),
                    const SizedBox(height: 4),
                    _IconText(icon: Icons.place_outlined, text: tugas.tempat),
                    const SizedBox(height: 8),
                    _SmallBadge(
                      label: tugas.selesai ? 'Selesai' : 'Belum Selesai',
                      color: tugas.selesai
                          ? AppColors.biruSedang
                          : AppColors.oranyeWarning,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: AppColors.abuTeks),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskDetailSheet extends StatelessWidget {
  final TugasModel tugas;

  const _TaskDetailSheet({required this.tugas});

  Future<void> _bukaPanduanMaps(BuildContext context) async {
    if (tugas.latitude == null || tugas.longitude == null) return;

    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=${tugas.latitude},${tugas.longitude}'
      '&travelmode=driving',
    );

    final berhasil = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!berhasil && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Google Maps tidak bisa dibuka di perangkat ini.',
          ),
          backgroundColor: AppColors.biruTua,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final gpsText = tugas.latitude == null || tugas.longitude == null
        ? 'Koordinat belum tersedia'
        : '${tugas.latitude!.toStringAsFixed(6)}, ${tugas.longitude!.toStringAsFixed(6)}';

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 18,
          right: 18,
          top: 10,
          bottom: 18 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.abuBorder,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                tugas.judul,
                style: const TextStyle(
                  color: AppColors.biruTua,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tugas.deskripsi,
                style: const TextStyle(
                  color: AppColors.abuTeks,
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              _DetailRow(
                icon: Icons.access_time_rounded,
                label: 'Waktu',
                value:
                    '${formatTanggalIndo(tugas.tanggal)} - ${formatJam(tugas.jam)}',
              ),
              _DetailRow(
                icon: Icons.place_rounded,
                label: 'Tempat',
                value: tugas.tempat,
              ),
              _DetailRow(
                icon: Icons.gps_fixed_rounded,
                label: 'GPS',
                value: gpsText,
              ),
              _DetailRow(
                icon: Icons.group_outlined,
                label: 'Petugas',
                value: tugas.staff.join(', '),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: tugas.latitude == null || tugas.longitude == null
                      ? null
                      : () => _bukaPanduanMaps(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.biruTua,
                    foregroundColor: AppColors.putih,
                    disabledBackgroundColor: AppColors.abuBorder,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: const Text('Panduan Google Maps'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.biruSedang.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.biruSedang, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.abuTeks,
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.biruTua,
                    fontSize: 13.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _SmallBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _IconText extends StatelessWidget {
  final IconData icon;
  final String text;

  const _IconText({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.abuTeks),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.abuTeks, fontSize: 11.8),
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.cyan : AppColors.putih.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.biruTua : AppColors.putih,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String query;

  const _EmptyState({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.assignment_late_outlined,
            size: 48,
            color: AppColors.abuTeks,
          ),
          const SizedBox(height: 12),
          Text(
            query.isEmpty
                ? 'Belum ada tugas staff'
                : 'Tugas "$query" tidak ditemukan',
            style: const TextStyle(color: AppColors.abuTeks, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
