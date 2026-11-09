import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../pages/admin/admin_sidebar.dart';
import '../pages/admin/riwayat_tugas_staff.dart';
import '../services/backfill_staff_ids.dart';
import '../services/penugasan_workflow.dart';
import '../widgets/admin_header.dart';
import 'detail_tugas_admin_page.dart';

class AppColors {
  static const Color biruTua = AppPalette.navy;
  static const Color biruSedang = AppPalette.blue;
  static const Color cyan = AppPalette.sky;
  static const Color hijauSelesai = Color(0xFF2E8B57);
  static const Color putih = Colors.white;
  static const Color abuTeks = Color(0xFF5A6472);
  static const Color latarAbu = AppPalette.background;
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
          fontSize: AppTypography.caption,
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
      return AppTaskStatus.color('disetujui');
    case 'dikumpulkan':
      return AppTaskStatus.color('dikumpulkan');
    case 'berlangsung':
      return AppTaskStatus.color('berlangsung');
    case 'terkendala':
      return AppTaskStatus.color('terkendala');
    case 'revisi':
      return AppTaskStatus.color('revisi');
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
    // Melengkapi staff_ids pada tugas lama agar staff boleh membacanya.
    backfillStaffIds();
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

    return Scaffold(
      backgroundColor: AppColors.latarAbu,
      drawer: wide
          ? null
          : const AdminSidebar(currentIndex: _sidebarIndex, isDrawer: true),
      floatingActionButton: wide
          ? null
          : FloatingActionButton.extended(
              onPressed: _bukaTambahTugas,
              backgroundColor: AppPalette.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
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
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _summary(allDocs),
          const SizedBox(height: 12),
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

  Widget _summary(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
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
        aktif.length,
        Icons.assignment_rounded,
        AppColors.biruSedang,
        const Color(0xFFEAF3FC),
      ],
      [
        'Perlu Direview',
        review,
        Icons.rate_review_rounded,
        Colors.deepPurple.shade400,
        const Color(0xFFF1ECFA),
      ],
      [
        'Terkendala',
        kendala,
        Icons.report_problem_rounded,
        Colors.red.shade700,
        const Color(0xFFFDEDED),
      ],
    ];

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (items[i][3] as Color).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            items[i][2] as IconData,
                            size: 18,
                            color: (items[i][3] as Color),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${items[i][1]}',
                              style: TextStyle(
                                fontSize: AppTypography.section,
                                fontWeight: FontWeight.bold,
                                color: (items[i][3] as Color),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      items[i][0] as String,
                      maxLines: 2,
                      softWrap: true,
                      style: TextStyle(
                        fontSize: AppTypography.caption,
                        height: 1.2,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ───────────────────────────── Toolbar (Gaya Dropdown Riwayat Tugas Staff) ─────────────────────────────

  BoxDecoration _toolbarBoxDecoration({bool active = false}) {
    return BoxDecoration(
      color: active ? const Color(0xFFEAF3FC) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: active
          ? Border.all(color: AppColors.biruSedang.withOpacity(0.45))
          : null,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }

  Widget _statusDropdown({bool expanded = false}) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: _toolbarBoxDecoration(
        active: _filterStatus != FilterStatus.semua,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<FilterStatus>(
          value: _filterStatus,
          isExpanded: expanded,
          borderRadius: BorderRadius.circular(16),
          dropdownColor: Colors.white,
          icon: const Icon(Icons.arrow_drop_down, color: AppColors.biruSedang),
          style: const TextStyle(
            fontSize: AppTypography.body,
            fontWeight: FontWeight.w600,
            color: AppColors.biruTua,
          ),
          items: FilterStatus.values.map((status) {
            return DropdownMenuItem<FilterStatus>(
              value: status,
              child: Text(
                status == FilterStatus.semua
                    ? 'Semua Status'
                    : _filterStatusName(status),
              ),
            );
          }).toList(),
          onChanged: (value) async {
            if (value == null) return;
            if (value == FilterStatus.disetujui) {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const RiwayatTugasStaffPage(),
                ),
              );
              return;
            }
            setState(() {
              _filterStatus = value;
              _page = 0;
            });
          },
        ),
      ),
    );
  }

  Widget _sortDropdown({bool expanded = false}) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: _toolbarBoxDecoration(active: _sortBy != SortBy.terbaru),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<SortBy>(
          value: _sortBy,
          isExpanded: expanded,
          borderRadius: BorderRadius.circular(16),
          dropdownColor: Colors.white,
          icon: const Icon(Icons.arrow_drop_down, color: AppColors.biruSedang),
          style: const TextStyle(
            fontSize: AppTypography.body,
            fontWeight: FontWeight.w600,
            color: AppColors.biruTua,
          ),
          items: SortBy.values.map((sort) {
            return DropdownMenuItem<SortBy>(
              value: sort,
              child: Text(_sortName(sort)),
            );
          }).toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _sortBy = value;
              _page = 0;
            });
          },
        ),
      ),
    );
  }

  Widget _dateFilterButton({bool expanded = false}) {
    final bool hasDate = _selectedDate != null;
    final String label = hasDate
        ? '${_selectedDate!.day.toString().padLeft(2, '0')}/${_selectedDate!.month.toString().padLeft(2, '0')}/${_selectedDate!.year}'
        : 'Tanggal';

    return Container(
      height: 48,
      decoration: _toolbarBoxDecoration(active: hasDate),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _pilihTanggal,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 16,
                      color: AppColors.biruSedang,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: AppTypography.body,
                        fontWeight: FontWeight.w600,
                        color: AppColors.biruTua,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 6),
                if (hasDate)
                  GestureDetector(
                    onTap: () => setState(() {
                      _selectedDate = null;
                      _page = 0;
                    }),
                    child: const Tooltip(
                      message: 'Hapus filter tanggal',
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: AppColors.biruSedang,
                      ),
                    ),
                  )
                else
                  const Icon(
                    Icons.arrow_drop_down,
                    color: AppColors.biruSedang,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tambahTugasButton() {
    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        onPressed: _bukaTambahTugas,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text('Tambah Tugas'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppPalette.blue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: AppTypography.body,
          ),
        ),
      ),
    );
  }

  Widget _toolbar(bool wide) {
    final searchField = Container(
      height: 48,
      decoration: _toolbarBoxDecoration(),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() {
          _searchQuery = value;
          _page = 0;
        }),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Cari judul atau tempat tugas...',
          hintStyle: TextStyle(
            color: Colors.grey.shade500,
            fontSize: AppTypography.body,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.biruSedang,
          ),
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
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );

    if (wide) {
      return Row(
        children: [
          Expanded(child: searchField),
          const SizedBox(width: 10),
          SizedBox(width: 165, child: _statusDropdown(expanded: true)),
          const SizedBox(width: 10),
          SizedBox(width: 155, child: _sortDropdown(expanded: true)),
          const SizedBox(width: 10),
          _dateFilterButton(),
          const SizedBox(width: 10),
          _tambahTugasButton(),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        searchField,
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _statusDropdown(),
              const SizedBox(width: 8),
              _sortDropdown(),
              const SizedBox(width: 8),
              _dateFilterButton(),
            ],
          ),
        ),
      ],
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
          fontSize: AppTypography.caption,
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
                        fontSize: AppTypography.body,
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
                                fontSize: AppTypography.caption,
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
                style: const TextStyle(fontSize: AppTypography.small),
              ),
            ),
            Expanded(
              flex: 13,
              child: Text(
                _fmtDate(_asDate(data['tanggal_selesai_tugas'])),
                style: const TextStyle(fontSize: AppTypography.small),
              ),
            ),
            Expanded(
              flex: 7,
              child: Text(
                '$jumlahStaf',
                style: const TextStyle(
                  fontSize: AppTypography.small,
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
              fontSize: AppTypography.body,
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
                                    fontSize: AppTypography.body,
                                    fontWeight: FontWeight.bold,
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

  // ───────────────────────────── Label Filter & Sort ─────────────────────────────

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
            style: const TextStyle(
              color: AppColors.abuTeks,
              fontSize: AppTypography.caption,
            ),
          ),
        ),
      ],
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
            style: const TextStyle(
              color: AppColors.abuTeks,
              fontSize: AppTypography.body,
            ),
          ),
        ],
      ),
    );
  }
}
