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
  static const Color putih = Colors.white;
  static const Color abuTeks = Color(0xFF5A6472);
  static const Color latarAbu = Color(0xFFF4F6FB);
  static const Color merahHapus = Color(0xFFE5484D);
  static const Color oranyeWarning = Color(0xFFFF9800);
}

enum SortBy { terbaru, namaAZ, tanggal }

enum FilterStatus { semua, belumSelesai, selesai }

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
      final cocokPencarian = tugas.judul.toLowerCase().contains(query) ||
          tugas.tempat.toLowerCase().contains(query) ||
          tugas.staff.any((s) => s.toLowerCase().contains(query));

      final cocokStatus = switch (_filterStatus) {
        FilterStatus.semua => true,
        FilterStatus.belumSelesai => !tugas.selesai,
        FilterStatus.selesai => tugas.selesai,
      };

      return cocokPencarian && cocokStatus;
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
          style: TextStyle(color: AppColors.biruTua, fontWeight: FontWeight.w700),
        ),
        content: Text('Tugas "${tugas.judul}" akan dihapus secara permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: AppColors.abuTeks)),
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
    return Scaffold(
      backgroundColor: AppColors.latarAbu,
      appBar: AppBar(
        backgroundColor: AppColors.biruTua,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Kelola Tugas',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          // ================= PENCARIAN & FILTER =================
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            decoration: const BoxDecoration(
              color: AppColors.biruTua,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                // ---------- KOLOM PENCARIAN ----------
                TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  style: const TextStyle(fontSize: 13.5),
                  decoration: InputDecoration(
                    hintText: 'Cari judul, tempat, atau staf...',
                    hintStyle: const TextStyle(color: AppColors.abuTeks, fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.biruSedang),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.abuTeks),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.putih,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ---------- FILTER STATUS ----------
                SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _FilterChip(
                        label: 'Semua',
                        selected: _filterStatus == FilterStatus.semua,
                        onTap: () => setState(() => _filterStatus = FilterStatus.semua),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Belum Selesai',
                        selected: _filterStatus == FilterStatus.belumSelesai,
                        onTap: () => setState(() => _filterStatus = FilterStatus.belumSelesai),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Selesai',
                        selected: _filterStatus == FilterStatus.selesai,
                        onTap: () => setState(() => _filterStatus = FilterStatus.selesai),
                      ),
                      const SizedBox(width: 14),
                      Container(width: 1, height: 20, color: AppColors.putih.withOpacity(0.25)),
                      const SizedBox(width: 14),
                      _SortChip(
                        icon: Icons.access_time_rounded,
                        label: 'Terbaru',
                        selected: _sortBy == SortBy.terbaru,
                        onTap: () => setState(() => _sortBy = SortBy.terbaru),
                      ),
                      const SizedBox(width: 8),
                      _SortChip(
                        icon: Icons.sort_by_alpha_rounded,
                        label: 'Nama A-Z',
                        selected: _sortBy == SortBy.namaAZ,
                        onTap: () => setState(() => _sortBy = SortBy.namaAZ),
                      ),
                      const SizedBox(width: 8),
                      _SortChip(
                        icon: Icons.calendar_today_rounded,
                        label: 'Tanggal',
                        selected: _sortBy == SortBy.tanggal,
                        onTap: () => setState(() => _sortBy = SortBy.tanggal),
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
        label: const Text('Tambah Tugas', style: TextStyle(color: AppColors.putih)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: const AdminBottomNavigationBar(currentIndex: 1),
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

  const _TugasCard({required this.tugas, required this.onEdit, required this.onDelete});

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
              color: tugas.selesai ? AppColors.biruSedang : AppColors.oranyeWarning,
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: warnaPrioritas.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        tugas.prioritas,
                        style: TextStyle(color: warnaPrioritas, fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _IconText(icon: Icons.place_outlined, text: tugas.tempat),
                const SizedBox(height: 3),
                _IconText(
                  icon: Icons.event_outlined,
                  text: '${formatTanggalIndo(tugas.tanggal)} · ${formatJam(tugas.jam)}',
                ),
                const SizedBox(height: 3),
                _IconText(icon: Icons.person_outline_rounded, text: tugas.staff.join(', ')),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (tugas.selesai ? AppColors.biruSedang : AppColors.oranyeWarning).withOpacity(0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tugas.selesai ? 'Selesai' : 'Belum Selesai',
                    style: TextStyle(
                      color: tugas.selesai ? AppColors.biruSedang : AppColors.oranyeWarning,
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
                icon: const Icon(Icons.edit_outlined, color: AppColors.biruSedang, size: 20),
                tooltip: 'Edit Tugas',
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(6),
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.merahHapus, size: 20),
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

  const _FilterChip({required this.label, required this.selected, required this.onTap});

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
            fontWeight: FontWeight.w600,
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
      borderRadius: BorderRadius.circular(20),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.putih.withOpacity(selected ? 0.9 : 0.3)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: AppColors.putih.withOpacity(selected ? 1 : 0.6)),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: AppColors.putih.withOpacity(selected ? 1 : 0.6),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
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
          const Icon(Icons.assignment_late_outlined, size: 48, color: AppColors.abuTeks),
          const SizedBox(height: 12),
          Text(
            query.isEmpty ? 'Belum ada tugas' : 'Tugas "$query" tidak ditemukan',
            style: const TextStyle(color: AppColors.abuTeks, fontSize: 13),
          ),
        ],
      ),
    );
  }
}