import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../pages/admin/admin_navbar.dart' show withAdminReadableText;
import '../pages/admin/admin_sidebar.dart';
import '../pages/admin/riwayat_tugas_staff.dart';
import '../services/penugasan_workflow.dart';
import '../widgets/admin_header.dart';
import 'detail_tugas_admin_page.dart';

class AppColors {
  static const Color biruTua = Color(0xFF1A1464);
  static const Color biruSedang = Color(0xFF1D5FA0);
  static const Color cyan = Color(0xFF4FA6DE);
  static const Color hijauSelesai = Color(0xFF2E8B57);
  static const Color putih = Colors.white;
  static const Color abuTeks = Color(0xFF5A6472);
  static const Color latarAbu = Color(0xFFF4F7FB);
  static const Color merahHapus = Color(0xFFE5484D);
  static const Color oranyeWarning = Color(0xFFFF9800);
}

enum SortBy { terbaru, namaAZ, tanggal }

enum FilterStatus {
  semua,
  pending,
  berlangsung,
  terkendala,
  dikumpulkan,
  revisi,
  disetujui,
}

const List<String> _shortMonths = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

String _fmtDate(DateTime? d) =>
    d == null ? '-' : '${d.day} ${_shortMonths[d.month - 1]} ${d.year}';

Widget _pill(String text, Color color, {IconData? icon}) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
  decoration: BoxDecoration(
    color: color.withOpacity(.12),
    borderRadius: BorderRadius.circular(20),
  ),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (icon != null) ...[
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
      ],
      Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  ),
);

BoxDecoration _card([double r = 16]) => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(r),
  boxShadow: [
    BoxShadow(
      color: AppColors.biruTua.withOpacity(.05),
      blurRadius: 14,
      offset: const Offset(0, 4),
    ),
  ],
);

Color _statusColor(String status) {
  switch (status) {
    case 'disetujui':
      return AppColors.hijauSelesai;
    case 'dikumpulkan':
      return Colors.deepPurple.shade400;
    case 'berlangsung':
      return Colors.orange.shade800;
    case 'terkendala':
      return Colors.red.shade700;
    case 'revisi':
      return Colors.deepOrange.shade600;
    default:
      return Colors.blueGrey.shade500;
  }
}

String _statusText(String status) {
  switch (status) {
    case 'disetujui':
      return 'Disetujui';
    case 'dikumpulkan':
      return 'Dikumpulkan';
    case 'berlangsung':
      return 'Berlangsung';
    case 'terkendala':
      return 'Terkendala';
    case 'revisi':
      return 'Revisi';
    default:
      return 'Pending';
  }
}

Color _priorityColor(String priority) {
  switch (priority.toLowerCase()) {
    case 'tinggi':
      return Colors.red.shade600;
    case 'rendah':
      return Colors.green.shade600;
    default:
      return Colors.amber.shade700;
  }
}

String _priorityText(String priority) {
  final p = priority.toLowerCase();
  if (p == 'tinggi') return 'Tinggi';
  if (p == 'rendah') return 'Rendah';
  return 'Sedang';
}

class KelolaTugasPage extends StatefulWidget {
  const KelolaTugasPage({super.key});

  @override
  State<KelolaTugasPage> createState() => _KelolaTugasPageState();
}

class _KelolaTugasPageState extends State<KelolaTugasPage> {
  static const double _sidebarBreakpoint = 900;
  static const int _sidebarIndex = 2; // posisi menu Kelola Tugas di sidebar
  static const int _perPage = 10;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  int _page = 0;
  final Map<String, List<String>> _statusesByTugas = {};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _assignmentSubscription;

  SortBy _sortBy = SortBy.terbaru;
  FilterStatus _filterStatus = FilterStatus.semua;
  DateTime? _selectedDate;

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _tugasStream =
      _firestore
          .collection('tugas')
          .orderBy('tanggal_tugas_diberikan', descending: true)
          .snapshots();

  @override
  void initState() {
    super.initState();
    _assignmentSubscription = _firestore
        .collection('penugasan')
        .snapshots()
        .listen(
          (snapshot) {
            if (!mounted) return;
            setState(() {
              _statusesByTugas.clear();
              for (final doc in snapshot.docs) {
                final data = doc.data();
                final taskId = (data['tugas_id'] ?? '').toString();
                (_statusesByTugas[taskId] ??= []).add(
                  (data['status'] ?? 'pending').toString().toLowerCase(),
                );
              }
            });
          },
          onError: (Object error) {
            if (mounted) {
              _tampilkanSnackbar(
                'Gagal memperbarui status: $error',
                error: true,
              );
            }
          },
        );
  }

  @override
  void dispose() {
    _assignmentSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // ───────────────────────────── Aksi ─────────────────────────────

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
      setState(() {
        _selectedDate = picked;
        _page = 0;
      });
    }
  }

  Future<void> _bukaTambahTugas() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DetailTugasAdminPage()),
    );
  }

  Future<void> _bukaEditTugas(String tugasId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DetailTugasAdminPage(tugasId: tugasId)),
    );
  }

  Future<void> _bukaDetailTugas(String tugasId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetailTugasAdminPage(tugasId: tugasId, modeLihat: true),
      ),
    );
  }

  Future<void> _konfirmasiHapus(String tugasId, String judul) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Hapus Tugas?',
            style: TextStyle(
              color: AppColors.biruTua,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'Tugas "$judul" akan dihapus secara permanen beserta penugasannya.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Batal',
                style: TextStyle(color: AppColors.abuTeks),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.merahHapus,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      final assignments = await _firestore
          .collection('penugasan')
          .where('tugas_id', isEqualTo: tugasId)
          .get();

      final batch = _firestore.batch();
      for (final doc in assignments.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(_firestore.collection('tugas').doc(tugasId));
      await batch.commit();

      if (!mounted) return;
      _tampilkanSnackbar('Tugas "$judul" telah dihapus');
    } catch (e) {
      if (!mounted) return;
      _tampilkanSnackbar('Gagal menghapus tugas: $e', error: true);
    }
  }

  // ───────────────────────────── Data ─────────────────────────────

  String _groupStatus(String tugasId) =>
      assignmentGroupStatus(_statusesByTugas[tugasId] ?? const ['pending']);

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filterDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final query = _searchQuery.trim().toLowerCase();

    final result = docs.where((doc) {
      final data = doc.data();
      final judul = (data['judul'] ?? '').toString().toLowerCase();
      final tempat = (data['tempat_tugas'] ?? '').toString().toLowerCase();

      final cocokSearch =
          query.isEmpty || judul.contains(query) || tempat.contains(query);

      final start = _asDate(data['tanggal_mulai_tugas']);
      final cocokTanggal =
          _selectedDate == null ||
          (start != null && DateUtils.isSameDay(start, _selectedDate!));

      final statuses = _statusesByTugas[doc.id] ?? ['pending'];
      final sudahDisetujui = assignmentGroupStatus(statuses) == 'disetujui';
      final cocokStatus =
          _filterStatus == FilterStatus.semua ||
          statuses.contains(_filterStatus.name);

      return cocokSearch && cocokTanggal && cocokStatus && !sudahDisetujui;
    }).toList();

    if (_sortBy == SortBy.namaAZ) {
      result.sort(
        (a, b) => (a.data()['judul'] ?? '').toString().compareTo(
          (b.data()['judul'] ?? '').toString(),
        ),
      );
    } else if (_sortBy == SortBy.tanggal) {
      result.sort(
        (a, b) => (_asDate(a.data()['tanggal_mulai_tugas']) ?? DateTime(1900))
            .compareTo(
              _asDate(b.data()['tanggal_mulai_tugas']) ?? DateTime(1900),
            ),
      );
    }

    return result;
  }

  DateTime? _asDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  void _tampilkanSnackbar(String pesan, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(pesan),
        backgroundColor: error ? Colors.red.shade700 : AppColors.biruTua,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ───────────────────────────── Build ─────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bool wide = MediaQuery.of(context).size.width >= _sidebarBreakpoint;

    return withAdminReadableText(
      context,
      Scaffold(
        backgroundColor: AppColors.latarAbu,
        drawer: wide
            ? null
            : const AdminSidebar(currentIndex: _sidebarIndex, isDrawer: true),
        floatingActionButton: wide
            ? null
            : FloatingActionButton.extended(
                onPressed: _bukaTambahTugas,
                backgroundColor: AppColors.biruTua,
                icon: const Icon(Icons.add_rounded, color: Colors.white),
                label: const Text(
                  'Tambah Tugas',
                  style: TextStyle(color: Colors.white),
                ),
              ),
        body: Row(
          children: [
            if (wide) const AdminSidebar(currentIndex: _sidebarIndex),
            Expanded(
              child: Column(
                children: [
                  AdminHeader(title: 'Kelola Tugas', showSidebar: wide),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _tugasStream,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text(
                                'Gagal memuat tugas:\n${snapshot.error}',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        }
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        return _content(snapshot.data?.docs ?? [], wide);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> allDocs,
    bool wide,
  ) {
    final filtered = _filterDocs(allDocs);
    final pages = math.max(1, (filtered.length / _perPage).ceil());
    final pg = _page.clamp(0, pages - 1);
    final shown = filtered.skip(pg * _perPage).take(_perPage).toList();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.all(wide ? 24 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _summary(allDocs, compact: !wide),
          SizedBox(height: wide ? 16 : 12),
          _toolbar(wide),
          const SizedBox(height: 14),
          if (shown.isEmpty)
            _EmptyState(query: _searchQuery)
          else if (wide)
            _tableCard(shown, pg, pages)
          else
            Column(
              children: [
                for (final doc in shown) _mobileCard(doc),
                _pager(pg, pages),
              ],
            ),
          if (!wide) const SizedBox(height: 70), // ruang untuk tombol tambah
        ],
      ),
    );
  }

  // ───────────────────────────── Ringkasan ─────────────────────────────

  Widget _summary(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, {
    required bool compact,
  }) {
    final aktif = docs.where((d) => _groupStatus(d.id) != 'disetujui').toList();
    final review = aktif
        .where((d) => _groupStatus(d.id) == 'dikumpulkan')
        .length;
    final kendala = aktif
        .where((d) => _groupStatus(d.id) == 'terkendala')
        .length;

    final items = [
      [
        'Tugas Aktif',
        '${aktif.length} Tugas',
        Icons.assignment_rounded,
        AppColors.biruSedang,
        const Color(0xFFEAF3FC),
      ],
      [
        'Perlu Direview',
        '$review Tugas',
        Icons.rate_review_rounded,
        Colors.deepPurple.shade400,
        const Color(0xFFF1ECFA),
      ],
      [
        'Terkendala',
        '$kendala Tugas',
        Icons.report_problem_rounded,
        Colors.red.shade700,
        const Color(0xFFFDEDED),
      ],
    ];

    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) SizedBox(width: compact ? 8 : 12),
          Expanded(
            child: Container(
              padding: EdgeInsets.all(compact ? 10 : 16),
              decoration: BoxDecoration(
                color: items[i][4] as Color,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: (items[i][3] as Color).withOpacity(.15),
                ),
              ),
              child: compact
                  ? Column(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: (items[i][3] as Color).withOpacity(
                            .15,
                          ),
                          child: Icon(
                            items[i][2] as IconData,
                            size: 16,
                            color: items[i][3] as Color,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          items[i][0] as String,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: items[i][3] as Color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          items[i][1] as String,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.biruTua,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: (items[i][3] as Color).withOpacity(
                            .15,
                          ),
                          child: Icon(
                            items[i][2] as IconData,
                            color: items[i][3] as Color,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                items[i][0] as String,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: items[i][3] as Color,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                items[i][1] as String,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.biruTua,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ],
    );
  }

  // ───────────────────────────── Toolbar ─────────────────────────────

  Widget _toolbar(bool wide) {
    final searchField = TextField(
      controller: _searchController,
      onChanged: (value) => setState(() {
        _searchQuery = value;
        _page = 0;
      }),
      style: const TextStyle(fontSize: 13.5),
      decoration: InputDecoration(
        hintText: 'Cari judul atau tempat tugas...',
        hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchQuery.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _page = 0;
                  });
                },
                icon: const Icon(Icons.close),
              ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
      ),
    );

    final chips = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterChip(
            label: _filterLabel(),
            selected: _filterStatus != FilterStatus.semua,
            onTap: _bukaFilterStatus,
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: _sortLabel(),
            selected: _sortBy != SortBy.terbaru,
            onTap: _bukaSort,
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: _selectedDate == null
                ? 'Tanggal'
                : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
            selected: _selectedDate != null,
            onTap: _pilihTanggal,
          ),
          if (_selectedDate != null) ...[
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Hapus filter tanggal',
              onPressed: () => setState(() {
                _selectedDate = null;
                _page = 0;
              }),
              icon: const Icon(Icons.close, size: 18),
            ),
          ],
        ],
      ),
    );

    if (wide) {
      return Row(
        children: [
          Expanded(child: searchField),
          const SizedBox(width: 12),
          chips,
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _bukaTambahTugas,
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('Tambah Tugas'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.biruTua,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [searchField, const SizedBox(height: 10), chips],
    );
  }

  // ───────────────────────────── Tabel (layar lebar) ─────────────────────────────

  Widget _tableCard(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> rows,
    int pg,
    int pages,
  ) {
    Widget head(String t, int flex) => Expanded(
      flex: flex,
      child: Text(
        t,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade600,
        ),
      ),
    );

    return Container(
      decoration: _card(),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                head('Judul Tugas', 28),
                head('Prioritas', 11),
                head('Status', 13),
                head('Tanggal Mulai', 13),
                head('Tenggat', 13),
                head('Staf', 7),
                head('Aksi', 15),
              ],
            ),
          ),
          for (final doc in rows) _tableRow(doc),
          _pager(pg, pages),
        ],
      ),
    );
  }

  Widget _tableRow(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final judul = (data['judul'] ?? 'Tanpa Judul').toString();
    final tempat = (data['tempat_tugas'] ?? '').toString();
    final priority = (data['prioritas'] ?? 'sedang').toString();
    final status = _groupStatus(doc.id);
    final jumlahStaf = (_statusesByTugas[doc.id] ?? const []).length;

    return InkWell(
      onTap: () => _bukaDetailTugas(doc.id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 28,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      judul,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        color: AppColors.biruTua,
                      ),
                    ),
                    if (tempat.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 12,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              tempat,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 11,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _pill(
                  _priorityText(priority),
                  _priorityColor(priority),
                  icon: Icons.flag_rounded,
                ),
              ),
            ),
            Expanded(
              flex: 13,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _pill(_statusText(status), _statusColor(status)),
              ),
            ),
            Expanded(
              flex: 13,
              child: Text(
                _fmtDate(_asDate(data['tanggal_mulai_tugas'])),
                style: const TextStyle(fontSize: 12),
              ),
            ),
            Expanded(
              flex: 13,
              child: Text(
                _fmtDate(_asDate(data['tanggal_selesai_tugas'])),
                style: const TextStyle(fontSize: 12),
              ),
            ),
            Expanded(
              flex: 7,
              child: Text(
                '$jumlahStaf',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.biruTua,
                ),
              ),
            ),
            Expanded(
              flex: 15,
              child: Row(
                children: [
                  _iconAction(
                    Icons.visibility_outlined,
                    'Lihat detail',
                    AppColors.biruSedang,
                    () => _bukaDetailTugas(doc.id),
                  ),
                  _iconAction(
                    Icons.edit_outlined,
                    'Edit',
                    Colors.orange.shade800,
                    () => _bukaEditTugas(doc.id),
                  ),
                  _iconAction(
                    Icons.delete_outline_rounded,
                    'Hapus',
                    AppColors.merahHapus,
                    () => _konfirmasiHapus(doc.id, judul),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconAction(
    IconData icon,
    String tooltip,
    Color color,
    VoidCallback onTap,
  ) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(icon, size: 20, color: color),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
    );
  }

  Widget _pager(int pg, int pages) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: Colors.grey.shade200)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: 'Halaman sebelumnya',
          onPressed: pg > 0 ? () => setState(() => _page = pg - 1) : null,
          icon: const Icon(Icons.chevron_left),
          color: Colors.grey.shade700,
          disabledColor: Colors.grey.shade300,
          visualDensity: VisualDensity.compact,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            '${pg + 1} / $pages',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.biruTua,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Halaman berikutnya',
          onPressed: pg < pages - 1
              ? () => setState(() => _page = pg + 1)
              : null,
          icon: const Icon(Icons.chevron_right),
          color: Colors.grey.shade700,
          disabledColor: Colors.grey.shade300,
          visualDensity: VisualDensity.compact,
        ),
      ],
    ),
  );

  // ───────────────────────────── Kartu (HP) ─────────────────────────────

  Widget _mobileCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final judul = (data['judul'] ?? 'Tanpa Judul').toString();
    final tempat = (data['tempat_tugas'] ?? '-').toString();
    final priority = (data['prioritas'] ?? 'sedang').toString();
    final status = _groupStatus(doc.id);
    final start = _asDate(data['tanggal_mulai_tugas']);
    final end = _asDate(data['tanggal_selesai_tugas']);
    final jumlahStaf = (_statusesByTugas[doc.id] ?? const []).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: _card(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _bukaDetailTugas(doc.id),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 5, color: _statusColor(status)),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  judul,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.biruTua,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              PopupMenuButton<String>(
                                padding: EdgeInsets.zero,
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _bukaEditTugas(doc.id);
                                  } else if (value == 'delete') {
                                    _konfirmasiHapus(doc.id, judul);
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Hapus'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              _pill(_statusText(status), _statusColor(status)),
                              _pill(
                                _priorityText(priority),
                                _priorityColor(priority),
                                icon: Icons.flag_rounded,
                              ),
                              _pill(
                                '$jumlahStaf staf',
                                AppColors.biruSedang,
                                icon: Icons.people_alt_rounded,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _InfoRow(
                            icon: Icons.calendar_today_outlined,
                            text: '${_fmtDate(start)}  –  ${_fmtDate(end)}',
                          ),
                          const SizedBox(height: 5),
                          _InfoRow(
                            icon: Icons.location_on_outlined,
                            text: tempat.isEmpty ? '-' : tempat,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────────── Filter & Sort ─────────────────────────────

  String _filterLabel() {
    switch (_filterStatus) {
      case FilterStatus.pending:
        return 'Pending';
      case FilterStatus.berlangsung:
        return 'Berlangsung';
      case FilterStatus.terkendala:
        return 'Terkendala';
      case FilterStatus.dikumpulkan:
        return 'Dikumpulkan';
      case FilterStatus.revisi:
        return 'Revisi';
      case FilterStatus.disetujui:
        return 'Disetujui';
      case FilterStatus.semua:
        return 'Status';
    }
  }

  String _sortLabel() {
    switch (_sortBy) {
      case SortBy.terbaru:
        return 'Terbaru';
      case SortBy.namaAZ:
        return 'Nama A-Z';
      case SortBy.tanggal:
        return 'Tanggal';
    }
  }

  Future<void> _bukaFilterStatus() async {
    final value = await showModalBottomSheet<FilterStatus>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: FilterStatus.values.map((status) {
              return ListTile(
                title: Text(_filterStatusName(status)),
                trailing: _filterStatus == status
                    ? const Icon(Icons.check, color: AppColors.biruTua)
                    : null,
                onTap: () => Navigator.pop(context, status),
              );
            }).toList(),
          ),
        );
      },
    );

    if (!mounted) return;
    if (value == FilterStatus.disetujui) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const RiwayatTugasStaffPage()),
      );
      return;
    }
    if (value != null) {
      setState(() {
        _filterStatus = value;
        _page = 0;
      });
    }
  }

  Future<void> _bukaSort() async {
    final value = await showModalBottomSheet<SortBy>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: SortBy.values.map((sort) {
              return ListTile(
                title: Text(_sortName(sort)),
                trailing: _sortBy == sort
                    ? const Icon(Icons.check, color: AppColors.biruTua)
                    : null,
                onTap: () => Navigator.pop(context, sort),
              );
            }).toList(),
          ),
        );
      },
    );

    if (value != null) {
      setState(() {
        _sortBy = value;
        _page = 0;
      });
    }
  }

  String _filterStatusName(FilterStatus value) {
    switch (value) {
      case FilterStatus.semua:
        return 'Semua';
      case FilterStatus.pending:
        return 'Pending';
      case FilterStatus.berlangsung:
        return 'Berlangsung';
      case FilterStatus.dikumpulkan:
        return 'Dikumpulkan';
      case FilterStatus.revisi:
        return 'Revisi';
      case FilterStatus.disetujui:
        return 'Disetujui';
      case FilterStatus.terkendala:
        return 'Terkendala';
    }
  }

  String _sortName(SortBy value) {
    switch (value) {
      case SortBy.terbaru:
        return 'Terbaru';
      case SortBy.namaAZ:
        return 'Nama A-Z';
      case SortBy.tanggal:
        return 'Tanggal Mulai';
    }
  }
}

// ───────────────────────────── Widget kecil ─────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

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
      borderRadius: BorderRadius.circular(30),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? AppColors.biruSedang : Colors.white,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.biruTua,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down,
              size: 18,
              color: selected ? Colors.white : AppColors.biruTua,
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: _card(),
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
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.abuTeks, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
