import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/admin_header.dart';
import 'admin_sidebar.dart';

class LaporanKendalaAdminPage extends StatefulWidget {
  const LaporanKendalaAdminPage({super.key});

  @override
  State<LaporanKendalaAdminPage> createState() =>
      _LaporanKendalaAdminPageState();
}

class _LaporanKendalaAdminPageState extends State<LaporanKendalaAdminPage> {
  // Palet warna (sama dengan halaman Kelola Staff)
  static const Color _biruTua = AppPalette.navy;
  static const Color _biru = AppPalette.blue;
  static const Color _biruMuda = AppPalette.sky;
  static const Color _bg = AppPalette.background;

  // Posisi menu "Laporan Kendala" di AdminSidebar.
  // Sesuaikan jika urutan menu di sidebar Anda berbeda.
  static const int _sidebarIndex = 6;

  static const List<String> _statusList = [
    'Menunggu Respon',
    'Sedang Diproses',
    'Selesai',
  ];

  static const List<String> _bulan = [
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

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'Semua'; // 'Semua', 'Perlu Direspon', 'Selesai'

  // Stream dibuat sekali supaya tidak berkedip saat mengetik di kolom cari.
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _laporanStream =
      _firestore
          .collection('laporan_kendala')
          .orderBy('created_at', descending: true)
          .snapshots();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ===== HELPER =====
  // Ubah nilai apa pun dari Firestore menjadi String (anti error tipe data).
  String _str(dynamic v, [String fallback = '']) {
    if (v == null) return fallback;
    final t = v.toString().trim();
    return t.isEmpty ? fallback : t;
  }

  String _statusOf(Map<String, dynamic> data) {
    final s = _str(data['status'], 'Menunggu Respon');
    return _statusList.contains(s) ? s : 'Menunggu Respon';
  }

  bool _perluDirespon(String status) =>
      status == 'Menunggu Respon' || status == 'Sedang Diproses';

  String _tanggal(dynamic v) {
    DateTime? d;
    if (v is Timestamp) {
      d = v.toDate();
    } else if (v is String) {
      d = DateTime.tryParse(v);
    }
    if (d == null) return '';
    return '${d.day} ${_bulan[d.month - 1]} ${d.year}';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Selesai':
        return AppReportStatus.color('Selesai');
      case 'Sedang Diproses':
        return AppReportStatus.color('Sedang Diproses');
      default:
        return AppReportStatus.color('Menunggu Respon');
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'Selesai':
        return Icons.check_circle_rounded;
      case 'Sedang Diproses':
        return Icons.autorenew_rounded;
      default:
        return Icons.schedule_rounded;
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  // Gaya input mengikuti form login / form Kelola Staff.
  InputDecoration _inputDecoration({String? hint}) {
    const Color borderColor = Color(0xFFE2E8F0);
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: c, width: w),
    );
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Color(0xFF94A3B8),
        fontSize: AppTypography.body,
      ),
      filled: true,
      fillColor: AppPalette.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: border(borderColor),
      border: border(borderColor),
      focusedBorder: border(_biru, 1.5),
    );
  }

  Widget _fieldLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: AppTypography.body,
        fontWeight: FontWeight.w600,
        color: Color(0xFF334155),
      ),
    ),
  );

  // ===== MODAL BERI / UBAH TANGGAPAN =====
  void _showTanggapanModal(String docId, Map<String, dynamic> data) {
    final tanggapanController = TextEditingController(
      text: _str(data['tanggapan_admin']),
    );
    String statusSelected = _statusOf(data);
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      constraints: const BoxConstraints(maxWidth: 560),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            Future<void> kirim() async {
              final tanggapan = tanggapanController.text.trim();

              if (tanggapan.isEmpty) {
                _snack('Tanggapan admin tidak boleh kosong.');
                return;
              }

              setModalState(() => isSaving = true);

              try {
                await _firestore
                    .collection('laporan_kendala')
                    .doc(docId)
                    .update({
                      'tanggapan_admin': tanggapan,
                      'status': statusSelected,
                      'updated_at': FieldValue.serverTimestamp(),
                    });

                if (modalContext.mounted) Navigator.pop(modalContext);
                _snack('Tanggapan berhasil dikirimkan ke staf.');
              } catch (e) {
                if (modalContext.mounted) {
                  setModalState(() => isSaving = false);
                }
                _snack('Gagal menyimpan tanggapan: $e');
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalContext).viewInsets.bottom + 20,
                top: 18,
                left: 22,
                right: 22,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Tanggapi Laporan Kendala',
                                style: TextStyle(
                                  fontSize: AppTypography.subtitle,
                                  fontWeight: FontWeight.bold,
                                  color: _biruTua,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Berikan solusi dan perbarui status penanganan',
                                style: TextStyle(
                                  fontSize: AppTypography.small,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: isSaving
                              ? null
                              : () => Navigator.pop(modalContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Detail kendala dari staf
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppPalette.background,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pelapor: ${_str(data['nama_staf'], 'Staf')} '
                            '(${_str(data['nip_staf'], '-')})',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: AppTypography.body,
                              color: _biruTua,
                            ),
                          ),
                          if (_str(data['judul_tugas']).isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              'Tugas: ${_str(data['judul_tugas'])}',
                              style: const TextStyle(
                                fontSize: AppTypography.small,
                                color: _biru,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const Divider(height: 18),
                          Text(
                            'DESKRIPSI KENDALA',
                            style: TextStyle(
                              fontSize: AppTypography.caption,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _str(data['deskripsi_kendala'], '-'),
                            style: const TextStyle(
                              fontSize: AppTypography.body,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    _fieldLabel('Status Penanganan'),
                    DropdownButtonFormField<String>(
                      value: statusSelected,
                      isExpanded: true,
                      decoration: _inputDecoration(),
                      borderRadius: BorderRadius.circular(14),
                      items: const [
                        DropdownMenuItem(
                          value: 'Menunggu Respon',
                          child: Text('Menunggu Respon'),
                        ),
                        DropdownMenuItem(
                          value: 'Sedang Diproses',
                          child: Text('Sedang Diproses'),
                        ),
                        DropdownMenuItem(
                          value: 'Selesai',
                          child: Text('Selesai / Teratasi'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => statusSelected = val);
                        }
                      },
                    ),

                    const SizedBox(height: 16),

                    _fieldLabel('Tanggapan / Solusi Admin'),
                    TextField(
                      controller: tanggapanController,
                      maxLines: 4,
                      style: const TextStyle(fontSize: AppTypography.body),
                      decoration: _inputDecoration(
                        hint:
                            'Masukkan saran, instruksi, atau solusi untuk staf...',
                      ),
                    ),

                    const SizedBox(height: 20),

                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton(
                              onPressed: isSaving
                                  ? null
                                  : () => Navigator.pop(modalContext),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text('Batal'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppPalette.blue,
                                disabledBackgroundColor: _biru.withOpacity(0.6),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: isSaving ? null : kirim,
                              child: isSaving
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : const Text(
                                      'Kirim Tanggapan',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: AppTypography.body,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ===== KOMPONEN UI =====
  Widget _buildSearchBar() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Cari nama staf, NIP, tugas, atau kendala...',
          hintStyle: TextStyle(
            color: Colors.grey.shade500,
            fontSize: AppTypography.body,
          ),
          prefixIcon: const Icon(Icons.search_rounded, color: _biru),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildStat(String label, int value, IconData icon, Color color) {
    return Expanded(
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
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '$value',
                      style: TextStyle(
                        fontSize: AppTypography.section,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Label boleh turun ke baris kedua, tidak dipotong.
            Text(
              label,
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
    );
  }

  // Gaya chip sama dengan Kelola Tugas: tinggi 36, tanpa border, font 12.
  Widget _buildFilterChip(String label) {
    final bool selected = _selectedFilter == label;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = label),
      borderRadius: BorderRadius.circular(30),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _biru : Colors.white,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : _biruTua,
            fontSize: AppTypography.small,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildToolbar(bool wide) {
    final chips = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip('Semua'),
          const SizedBox(width: 8),
          _buildFilterChip('Perlu Direspon'),
          const SizedBox(width: 8),
          _buildFilterChip('Selesai'),
        ],
      ),
    );

    if (wide) {
      return Row(
        children: [
          Expanded(child: _buildSearchBar()),
          const SizedBox(width: 12),
          chips,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_buildSearchBar(), const SizedBox(height: 10), chips],
    );
  }

  // Tampilan kosong, sama dengan _EmptyState di Kelola Tugas.
  Widget _buildEmpty(bool belumAda) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _biruTua.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.assignment_turned_in_outlined,
            size: 48,
            color: Color(0xFF5A6472),
          ),
          const SizedBox(height: 12),
          Text(
            belumAda
                ? 'Belum ada laporan kendala dari staf'
                : 'Laporan kendala tidak ditemukan',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF5A6472),
              fontSize: AppTypography.body,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(IconData icon, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _biru.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44, color: _biru),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: AppTypography.section,
                fontWeight: FontWeight.bold,
                color: _biruTua,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: AppTypography.body,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLaporanCard(String docId, Map<String, dynamic> data) {
    final String namaStaf = _str(data['nama_staf'], 'Staf');
    final String nipStaf = _str(data['nip_staf'], '-');
    final String judulTugas = _str(data['judul_tugas']);
    final String deskripsi = _str(data['deskripsi_kendala'], '-');
    final String tanggapan = _str(data['tanggapan_admin']);
    final String status = _statusOf(data);
    final String tanggal = _tanggal(data['created_at']);
    final Color statusColor = _statusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _biruTua.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Garis warna status di sisi kiri
            Container(width: 5, color: statusColor),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Staf + badge status
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppPalette.blue.withOpacity(0.1),
                          child: const Icon(
                            Icons.person_rounded,
                            color: _biru,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                namaStaf,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: AppTypography.body,
                                  color: _biruTua,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                tanggal.isEmpty
                                    ? 'NIP: $nipStaf'
                                    : 'NIP: $nipStaf  •  $tanggal',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: AppTypography.caption,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _statusIcon(status),
                                size: 12,
                                color: statusColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                status,
                                style: TextStyle(
                                  fontSize: AppTypography.caption,
                                  fontWeight: FontWeight.w700,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    if (judulTugas.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: _biruMuda.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.assignment_outlined,
                              size: 13,
                              color: _biru,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                judulTugas,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: AppTypography.caption,
                                  color: _biru,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 10),
                    Text(
                      deskripsi,
                      style: const TextStyle(
                        fontSize: AppTypography.body,
                        height: 1.4,
                        color: Colors.black87,
                      ),
                    ),

                    // Tanggapan admin jika sudah direspon
                    if (tanggapan.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F6FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFCFE0F7)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.reply_rounded,
                                  size: 16,
                                  color: _biru,
                                ),
                                SizedBox(width: 5),
                                Text(
                                  'Tanggapan Admin',
                                  style: TextStyle(
                                    fontSize: AppTypography.caption,
                                    fontWeight: FontWeight.bold,
                                    color: _biru,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(
                              tanggapan,
                              style: const TextStyle(
                                fontSize: AppTypography.small,
                                height: 1.35,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 38,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: _biru),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => _showTanggapanModal(docId, data),
                        icon: Icon(
                          tanggapan.isEmpty
                              ? Icons.reply_rounded
                              : Icons.edit_note_rounded,
                          size: 18,
                          color: _biru,
                        ),
                        label: Text(
                          tanggapan.isEmpty
                              ? 'Beri Tanggapan'
                              : 'Ubah Tanggapan',
                          style: const TextStyle(
                            color: _biru,
                            fontWeight: FontWeight.bold,
                            fontSize: AppTypography.small,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(bool wide) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _laporanStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildMessage(
            Icons.error_outline_rounded,
            'Gagal memuat laporan kendala',
            '${snapshot.error}',
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];

        final total = docs.length;
        final perlu = docs
            .where((d) => _perluDirespon(_statusOf(d.data())))
            .length;
        final selesai = total - perlu;

        final query = _searchQuery.trim().toLowerCase();
        final filtered = docs.where((doc) {
          final data = doc.data();
          final status = _statusOf(data);

          final matchesSearch =
              query.isEmpty ||
              _str(data['nama_staf']).toLowerCase().contains(query) ||
              _str(data['nip_staf']).toLowerCase().contains(query) ||
              _str(data['judul_tugas']).toLowerCase().contains(query) ||
              _str(data['deskripsi_kendala']).toLowerCase().contains(query);

          bool matchesFilter = true;
          if (_selectedFilter == 'Perlu Direspon') {
            matchesFilter = _perluDirespon(status);
          } else if (_selectedFilter == 'Selesai') {
            matchesFilter = status == 'Selesai';
          }

          return matchesSearch && matchesFilter;
        }).toList();

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildStat(
                      'Total Laporan',
                      total,
                      Icons.report_gmailerrorred_rounded,
                      _biru,
                    ),
                    const SizedBox(width: 10),
                    _buildStat(
                      'Perlu Direspon',
                      perlu,
                      Icons.pending_actions_rounded,
                      Colors.orange.shade800,
                    ),
                    const SizedBox(width: 10),
                    _buildStat(
                      'Selesai',
                      selesai,
                      Icons.check_circle_rounded,
                      Colors.green.shade700,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildToolbar(wide),
              const SizedBox(height: 14),
              if (filtered.isEmpty)
                _buildEmpty(docs.isEmpty)
              else
                for (final doc in filtered)
                  _buildLaporanCard(doc.id, doc.data()),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool wide = constraints.maxWidth >= 900;
        return Scaffold(
          backgroundColor: _bg,
          drawer: wide
              ? null
              : const AdminSidebar(currentIndex: _sidebarIndex, isDrawer: true),
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (wide) const AdminSidebar(currentIndex: _sidebarIndex),
              Expanded(
                child: Column(
                  children: [
                    AdminHeader(title: 'Laporan Kendala', showSidebar: wide),
                    Expanded(child: _buildContent(wide)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
