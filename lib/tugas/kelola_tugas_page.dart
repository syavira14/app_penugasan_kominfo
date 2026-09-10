import 'package:flutter/material.dart';
import '../pages/admin/admin_navbar.dart';
import 'tugas_model.dart';
import 'detail_tugas_admin_page.dart';

/// ============================================================
/// KELOLA TUGAS (ADMIN)
/// Sistem Penjadwalan Penugasan Pegawai — Dinas Kominfo
/// ============================================================
/// Fitur:
///  - Kolom pencarian (judul / staff / tempat)
///  - Filter & sorting (Nama, Tanggal, Status)
///  - List tugas + tombol Edit & Delete
///  - Tombol (+) mengarah ke Detail Tugas Admin (mode tambah)
///  - Tombol Edit mengarah ke Detail Tugas Admin (mode ubah)
/// ============================================================

class AppColors {
  static const Color biruTua = Color(0xFF0011CC);
  static const Color biruSedang = Color(0xFF0066FF);
  static const Color cyan = Color(0xFF00CCFF);
  static const Color hijauSelesai = Color(0xFF2E8B57);
  static const Color putih = Colors.white;
  static const Color abuTeks = Color(0xFF5A6472);
  static const Color latarAbu = Color(0xFFF4F6FB);
  static const Color merahHapus = Color(0xFFE5484D);
  static const Color oranyeWarning = Color(0xFFFF9800);
}

enum SortBy { terbaru, namaAZ, tanggal }

enum FilterStatus { semua, belumSelesai, dikerjakan, selesai }

class KelolaTugasPage extends StatefulWidget {
  const KelolaTugasPage({super.key});

  @override
  State<KelolaTugasPage> createState() => _KelolaTugasPageState();
}

class _KelolaTugasPageState extends State<KelolaTugasPage> {
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  SortBy _sortBy = SortBy.terbaru;
  FilterStatus _filterStatus = FilterStatus.semua;
  DateTime? _selectedDate;

  Future<void> _pilihTanggal() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Pilih tanggal tugas',
      cancelText: 'Batal',
      confirmText: 'Pilih',
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  // Data contoh — ganti dengan data dari backend/API
  final List<TugasModel> _daftarTugas = [
    TugasModel(
      id: '1',
      judul: 'Pemeliharaan Server Data Center',
      deskripsi: 'Pengecekan rutin dan pemeliharaan server utama.',
      tempat: 'Ruang Server, Kantor Dinas Kominfo',
      tanggal: DateTime(2026, 8, 22),
      jam: const TimeOfDay(hour: 9, minute: 0),
      staff: const ['Ahmad Fauzi'],
      prioritas: 'Tinggi',
      selesai: false,
    ),
    TugasModel(
      id: '2',
      judul: 'Update Konten Portal Layanan Publik',
      deskripsi: 'Memperbarui informasi layanan pada portal resmi.',
      tempat: 'Kantor Dinas Kominfo Lt. 2',
      tanggal: DateTime(2026, 8, 24),
      jam: const TimeOfDay(hour: 13, minute: 30),
      staff: const ['Siti Nurhaliza'],
      prioritas: 'Sedang',
      selesai: false,
    ),
    TugasModel(
      id: '3',
      judul: 'Audit Keamanan Jaringan',
      deskripsi: 'Pemeriksaan celah keamanan pada jaringan internal.',
      tempat: 'Ruang IT, Kantor Dinas Kominfo',
      tanggal: DateTime(2026, 8, 18),
      jam: const TimeOfDay(hour: 10, minute: 0),
      staff: const ['Budi Santoso', 'Ahmad Fauzi'],
      prioritas: 'Tinggi',
      selesai: true,
    ),
    TugasModel(
      id: '4',
      judul: 'Dokumentasi Rapat Koordinasi',
      deskripsi: 'Menyusun notulen dan dokumentasi hasil rapat.',
      tempat: 'Ruang Rapat Utama',
      tanggal: DateTime(2026, 8, 15),
      jam: const TimeOfDay(hour: 14, minute: 0),
      staff: const ['Siti Nurhaliza'],
      prioritas: 'Rendah',
      selesai: true,
    ),
  ];

  List<TugasModel> get _tugasTertampil {
    List<TugasModel> hasil = _daftarTugas.where((tugas) {
      final query = _searchQuery.toLowerCase();
      final cocokPencarian =
          tugas.judul.toLowerCase().contains(query) ||
          tugas.tempat.toLowerCase().contains(query) ||
          tugas.staff.any((s) => s.toLowerCase().contains(query));

      final cocokStatus = switch (_filterStatus) {
        FilterStatus.semua => true,
        FilterStatus.belumSelesai => tugas.status == TugasStatus.belumSelesai,
        FilterStatus.dikerjakan => tugas.status == TugasStatus.dikerjakan,
        FilterStatus.selesai => tugas.status == TugasStatus.selesai,
      };

      final cocokTanggal =
          _selectedDate == null ||
          DateUtils.isSameDay(tugas.tanggal, _selectedDate!);

      return cocokPencarian && cocokStatus && cocokTanggal;
    }).toList();

    switch (_sortBy) {
      case SortBy.namaAZ:
        hasil.sort((a, b) => a.judul.compareTo(b.judul));
        break;
      case SortBy.tanggal:
        hasil.sort((a, b) => a.tanggal.compareTo(b.tanggal));
        break;
      case SortBy.terbaru:
        hasil.sort((a, b) => b.tanggal.compareTo(a.tanggal));
        break;
    }
    return hasil;
  }

  Future<void> _bukaTambahTugas() async {
    final hasil = await Navigator.push<TugasModel>(
      context,
      MaterialPageRoute(builder: (_) => const DetailTugasAdminPage()),
    );
    if (hasil != null) {
      setState(() => _daftarTugas.add(hasil));
      _tampilkanSnackbar('Tugas "${hasil.judul}" berhasil ditambahkan');
    }
  }

  Future<void> _bukaEditTugas(TugasModel tugas) async {
    final hasil = await Navigator.push<TugasModel>(
      context,
      MaterialPageRoute(builder: (_) => DetailTugasAdminPage(tugas: tugas)),
    );
    if (hasil != null) {
      setState(() {
        final index = _daftarTugas.indexWhere((t) => t.id == hasil.id);
        if (index != -1) _daftarTugas[index] = hasil;
      });
      _tampilkanSnackbar('Tugas "${hasil.judul}" berhasil diperbarui');
    }
  }

  void _konfirmasiHapus(TugasModel tugas) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Hapus Tugas?',
          style: TextStyle(
            color: AppColors.biruTua,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text('Tugas "${tugas.judul}" akan dihapus secara permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Batal',
              style: TextStyle(color: AppColors.abuTeks),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.merahHapus,
              foregroundColor: AppColors.putih,
              elevation: 0,
            ),
            onPressed: () {
              setState(() => _daftarTugas.removeWhere((t) => t.id == tugas.id));
              Navigator.pop(context);
              _tampilkanSnackbar('Tugas "${tugas.judul}" telah dihapus');
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  void _tampilkanSnackbar(String pesan) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(pesan),
        backgroundColor: AppColors.biruTua,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return withAdminReadableText(
      context,
      Scaffold(
        backgroundColor: AppColors.latarAbu,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          toolbarHeight: 96,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
          ),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF1B267B),
                  Color(0xFF0066B3),
                  Color(0xFF00A8E8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
            ),
          ),
          title: const Text(
            'Kelola Tugas',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
        ),
        body: Column(
          children: [
            const SizedBox(height: 8),

            // ================= PENCARIAN & FILTER =================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              color: AppColors.latarAbu,
              child: Column(
                children: [
                  // ---------- KOLOM PENCARIAN ----------
                  TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _searchQuery = value),
                    style: const TextStyle(fontSize: 13.5),
                    decoration: InputDecoration(
                      hintText: 'Cari judul, tempat, atau staf...',
                      hintStyle: const TextStyle(
                        color: AppColors.abuTeks,
                        fontSize: 13,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: AppColors.biruSedang,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: AppColors.abuTeks,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: AppColors.putih,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 0,
                        horizontal: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ---------- FILTER STATUS DAN SORT ----------
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 130,
                          height: 36,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: AppColors.biruSedang.withOpacity(0.35),
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<FilterStatus>(
                                isExpanded: true,
                                value: _filterStatus,
                                icon: const Icon(
                                  Icons.arrow_drop_down_rounded,
                                  color: AppColors.biruTua,
                                ),
                                dropdownColor: Colors.white,
                                style: const TextStyle(
                                  color: AppColors.biruTua,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: FilterStatus.semua,
                                    child: Text('Semua'),
                                  ),
                                  DropdownMenuItem(
                                    value: FilterStatus.belumSelesai,
                                    child: Text('Belum'),
                                  ),
                                  DropdownMenuItem(
                                    value: FilterStatus.dikerjakan,
                                    child: Text('Dikerjakan'),
                                  ),
                                  DropdownMenuItem(
                                    value: FilterStatus.selesai,
                                    child: Text('Selesai'),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _filterStatus = value);
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _SortChip(
                          icon: Icons.access_time_rounded,
                          label: 'Terbaru',
                          selected: _sortBy == SortBy.terbaru,
                          onTap: () => setState(() => _sortBy = SortBy.terbaru),
                        ),
                        const SizedBox(width: 8),
                        _SortChip(
                          icon: Icons.sort_by_alpha_rounded,
                          label: 'Nama',
                          selected: _sortBy == SortBy.namaAZ,
                          onTap: () => setState(() => _sortBy = SortBy.namaAZ),
                        ),
                        const SizedBox(width: 8),
                        _DateChip(
                          label: _selectedDate == null
                              ? 'Tanggal'
                              : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                          selected: _selectedDate != null,
                          onTap: _pilihTanggal,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ================= LIST TUGAS =================
            Expanded(
              child: _tugasTertampil.isEmpty
                  ? _EmptyState(query: _searchQuery)
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _tugasTertampil.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final tugas = _tugasTertampil[index];
                        return _TugasCard(
                          tugas: tugas,
                          onEdit: () => _bukaEditTugas(tugas),
                          onDelete: () => _konfirmasiHapus(tugas),
                        );
                      },
                    ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _bukaTambahTugas,
          backgroundColor: AppColors.biruTua,
          icon: const Icon(Icons.add_rounded, color: AppColors.putih),
          label: const Text(
            'Tambah Tugas',
            style: TextStyle(color: AppColors.putih),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        bottomNavigationBar: const AdminBottomNavigationBar(currentIndex: 1),
      ),
    );
  }
}

/// ---------------------------------------------------------
/// KARTU TUGAS
/// ---------------------------------------------------------
class _TugasCard extends StatelessWidget {
  final TugasModel tugas;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TugasCard({
    required this.tugas,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final Color warnaPrioritas = switch (tugas.prioritas) {
      'Tinggi' => AppColors.oranyeWarning,
      'Rendah' => AppColors.cyan,
      _ => AppColors.biruSedang,
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.putih,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.biruTua.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Garis status di sisi kiri
          Container(
            width: 4,
            height: 68,
            decoration: BoxDecoration(
              color: switch (tugas.status) {
                TugasStatus.belumSelesai => AppColors.oranyeWarning,
                TugasStatus.dikerjakan => AppColors.biruSedang,
                TugasStatus.selesai => AppColors.hijauSelesai,
              },
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        tugas.judul,
                        style: const TextStyle(
                          color: AppColors.biruTua,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: warnaPrioritas.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        tugas.prioritas,
                        style: TextStyle(
                          color: warnaPrioritas,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _IconText(icon: Icons.place_outlined, text: tugas.tempat),
                const SizedBox(height: 3),
                _IconText(
                  icon: Icons.event_outlined,
                  text:
                      '${formatTanggalIndo(tugas.tanggal)} · ${formatJam(tugas.jam)}',
                ),
                const SizedBox(height: 3),
                _IconText(
                  icon: Icons.person_outline_rounded,
                  text: tugas.staff.join(', '),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: switch (tugas.status) {
                      TugasStatus.belumSelesai =>
                        AppColors.oranyeWarning.withOpacity(0.10),
                      TugasStatus.dikerjakan =>
                        AppColors.biruSedang.withOpacity(0.10),
                      TugasStatus.selesai => AppColors.hijauSelesai.withOpacity(
                        0.10,
                      ),
                    },
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tugas.status.label,
                    style: TextStyle(
                      color: switch (tugas.status) {
                        TugasStatus.belumSelesai => AppColors.oranyeWarning,
                        TugasStatus.dikerjakan => AppColors.biruSedang,
                        TugasStatus.selesai => AppColors.hijauSelesai,
                      },
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ---------- TOMBOL EDIT & DELETE ----------
          Column(
            children: [
              IconButton(
                onPressed: onEdit,
                icon: const Icon(
                  Icons.edit_outlined,
                  color: AppColors.biruSedang,
                  size: 20,
                ),
                tooltip: 'Edit Tugas',
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(6),
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.merahHapus,
                  size: 20,
                ),
                tooltip: 'Hapus Tugas',
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(6),
              ),
            ],
          ),
        ],
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 13, color: AppColors.abuTeks),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.abuTeks, fontSize: 11.5),
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
      borderRadius: BorderRadius.circular(18),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.biruSedang : Colors.white,
          border: Border.all(
            color: selected
                ? AppColors.biruSedang
                : AppColors.biruSedang.withOpacity(0.35),
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.biruSedang.withOpacity(0.18),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.putih : AppColors.biruTua,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SortChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        alignment: Alignment.center,
        height: 36,
        constraints: const BoxConstraints(maxWidth: 118),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.biruTua : Colors.white,
          border: Border.all(
            color: selected
                ? AppColors.biruTua
                : AppColors.biruSedang.withOpacity(0.35),
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: selected ? AppColors.putih : AppColors.biruTua,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  color: selected ? AppColors.putih : AppColors.biruTua,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DateChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        alignment: Alignment.center,
        height: 36,
        constraints: const BoxConstraints(maxWidth: 118),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.biruTua : Colors.white,
          border: Border.all(
            color: selected
                ? AppColors.biruTua
                : AppColors.biruSedang.withOpacity(0.35),
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 13,
              color: selected ? AppColors.putih : AppColors.biruTua,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  color: selected ? AppColors.putih : AppColors.biruTua,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
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
                ? 'Belum ada tugas'
                : 'Tugas "$query" tidak ditemukan',
            style: const TextStyle(color: AppColors.abuTeks, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
