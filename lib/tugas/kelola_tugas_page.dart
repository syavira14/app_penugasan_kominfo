import 'dart:async';
import '../services/penugasan_workflow.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../pages/admin/admin_navbar.dart';
import '../pages/admin/riwayat_tugas_staff.dart';
import 'detail_tugas_admin_page.dart';

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

enum FilterStatus {
  semua,
  pending,
  berlangsung,
  terkendala,
  dikumpulkan,
  revisi,
  disetujui,
}

class KelolaTugasPage extends StatefulWidget {
  const KelolaTugasPage({super.key});

  @override
  State<KelolaTugasPage> createState() => _KelolaTugasPageState();
}

class _KelolaTugasPageState extends State<KelolaTugasPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  final Map<String, List<String>> _statusesByTugas = {};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _assignmentSubscription;

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
            if (mounted)
              _tampilkanSnackbar(
                'Gagal memperbarui status: $error',
                error: true,
              );
          },
        );
  }

  SortBy _sortBy = SortBy.terbaru;

  FilterStatus _filterStatus = FilterStatus.semua;

  DateTime? _selectedDate;

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _tugasStream =
      _firestore
          .collection('tugas')
          .orderBy('tanggal_tugas_diberikan', descending: true)
          .snapshots();

  @override
  void dispose() {
    _assignmentSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

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
              onPressed: () {
                Navigator.pop(context, false);
              },
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
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

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

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filterDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final result = docs.where((doc) {
      final data = doc.data();

      final judul = (data['judul'] ?? '').toString().toLowerCase();

      final tempat = (data['tempat_tugas'] ?? '').toString().toLowerCase();

      final query = _searchQuery.trim().toLowerCase();

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
      result.sort((a, b) {
        return (a.data()['judul'] ?? '').toString().compareTo(
          (b.data()['judul'] ?? '').toString(),
        );
      });
    } else if (_sortBy == SortBy.tanggal) {
      result.sort((a, b) {
        return (_asDate(a.data()['tanggal_mulai_tugas']) ?? DateTime(1900))
            .compareTo(
              _asDate(b.data()['tanggal_mulai_tugas']) ?? DateTime(1900),
            );
      });
    }

    return result;
  }

  DateTime? _asDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

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

            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              color: AppColors.latarAbu,
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    style: const TextStyle(fontSize: 13.5),
                    decoration: InputDecoration(
                      hintText: 'Cari judul atau tempat tugas...',
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
                              onPressed: () {
                                _searchController.clear();

                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                              icon: const Icon(Icons.close),
                            ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  SingleChildScrollView(
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
                            onPressed: () {
                              setState(() {
                                _selectedDate = null;
                              });
                            },
                            icon: const Icon(Icons.close, size: 18),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _tugasStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Gagal memuat tugas:\n${snapshot.error}'),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = _filterDocs(snapshot.data?.docs ?? []);

                  if (docs.isEmpty) {
                    return _EmptyState(query: _searchQuery);
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final doc = docs[index];

                      return _TugasCard(
                        doc: doc,
                        firestore: _firestore,
                        onTap: () => _bukaDetailTugas(doc.id),
                        onEdit: () => _bukaEditTugas(doc.id),
                        onDelete: () => _konfirmasiHapus(
                          doc.id,
                          (doc.data()['judul'] ?? 'Tugas').toString(),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),

        floatingActionButton: FloatingActionButton.extended(
          onPressed: _bukaTambahTugas,
          backgroundColor: AppColors.biruTua,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text(
            'Tambah Tugas',
            style: TextStyle(color: Colors.white),
          ),
        ),

        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

        bottomNavigationBar: const AdminBottomNavigationBar(currentIndex: 1),
      ),
    );
  }

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
                onTap: () {
                  Navigator.pop(context, status);
                },
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
                onTap: () {
                  Navigator.pop(context, sort);
                },
              );
            }).toList(),
          ),
        );
      },
    );

    if (value != null) {
      setState(() {
        _sortBy = value;
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

class _TugasCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  final FirebaseFirestore firestore;

  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TugasCard({
    required this.doc,
    required this.firestore,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  DateTime? _date(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    return null;
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '-';

    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/'
        '${value.year}';
  }

  String _statusFromAssignments(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> assignments,
  ) {
    return assignmentGroupStatus(
      assignments.map(
        (assignment) =>
            (assignment.data()['status'] ?? 'pending').toString().toLowerCase(),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'disetujui':
        return AppColors.hijauSelesai;

      case 'dikumpulkan':
        return AppColors.cyan;

      case 'berlangsung':
        return AppColors.biruSedang;

      case 'terkendala':
        return Colors.red;

      case 'revisi':
        return Colors.orange;

      default:
        return AppColors.oranyeWarning;
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
        return AppColors.oranyeWarning;

      case 'rendah':
        return AppColors.cyan;

      default:
        return AppColors.biruSedang;
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = doc.data();

    final judul = (data['judul'] ?? 'Tanpa Judul').toString();

    final tempat = (data['tempat_tugas'] ?? '-').toString();

    final priority = (data['prioritas'] ?? 'sedang').toString();

    final start = _date(data['tanggal_mulai_tugas']);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: firestore
          .collection('penugasan')
          .where('tugas_id', isEqualTo: doc.id)
          .snapshots(),
      builder: (context, snapshot) {
        final assignments = snapshot.data?.docs ?? [];

        final status = _statusFromAssignments(assignments);

        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
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
                Container(
                  width: 4,
                  height: 80,
                  decoration: BoxDecoration(
                    color: _statusColor(status),
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
                              judul,
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
                                onEdit();
                              } else if (value == 'delete') {
                                onDelete();
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Hapus'),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 7),

                      Row(
                        children: [
                          _Badge(
                            text: _statusText(status),
                            color: _statusColor(status),
                          ),

                          const SizedBox(width: 7),

                          _Badge(
                            text: priority.toUpperCase(),
                            color: _priorityColor(priority),
                          ),
                        ],
                      ),

                      const SizedBox(height: 9),

                      _InfoRow(
                        icon: Icons.calendar_today_outlined,
                        text: _formatDate(start),
                      ),

                      const SizedBox(height: 5),

                      _InfoRow(icon: Icons.location_on_outlined, text: tempat),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;

  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

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
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: selected ? AppColors.biruTua : Colors.white,
          border: Border.all(
            color: selected
                ? AppColors.biruTua
                : AppColors.biruSedang.withOpacity(.35),
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.biruTua,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down,
              size: 16,
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
