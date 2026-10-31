import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'admin_navbar.dart';

class LaporanKendalaAdminPage extends StatefulWidget {
  const LaporanKendalaAdminPage({super.key});

  @override
  State<LaporanKendalaAdminPage> createState() =>
      _LaporanKendalaAdminPageState();
}

class _LaporanKendalaAdminPageState extends State<LaporanKendalaAdminPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'Semua'; // 'Semua', 'Perlu Direspon', 'Selesai'

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ==== MODAL / DIALOG MEMBERIKAN RESPON KENDALA ====
  void _showTanggapanModal(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
  ) {
    final tanggapanController = TextEditingController(
      text: data['tanggapan_admin'] ?? '',
    );
    String statusSelected = data['status'] ?? 'Menunggu Respon';
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalContext).viewInsets.bottom + 20,
                top: 20,
                left: 20,
                right: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Tanggapi Laporan Kendala',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1B267B),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(modalContext),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Detail Kendala dari Staf
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pelapor: ${data['nama_staf'] ?? 'Staf'} (${data['nip_staf'] ?? '-'})',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          if (data['judul_tugas'] != null &&
                              data['judul_tugas'].toString().isNotEmpty)
                            Text(
                              'Tugas: ${data['judul_tugas']}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade800,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          const Divider(height: 12),
                          const Text(
                            'Deskripsi Kendala:',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            data['deskripsi_kendala'] ?? '-',
                            style: const TextStyle(fontSize: 13, height: 1.3),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Pilih Status Kendala
                    const Text(
                      'Status Penanganan',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF1B267B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: statusSelected,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
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
                          setModalState(() {
                            statusSelected = val;
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 16),

                    // Inputan Solusi / Tanggapan Admin
                    const Text(
                      'Tanggapan / Solusi Admin',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF1B267B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: tanggapanController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText:
                            'Masukkan saran, instruksi, atau solusi untuk staf...',
                        hintStyle: const TextStyle(fontSize: 13),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Tombol Kirim Tanggapan
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0066B3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: isSaving
                            ? null
                            : () async {
                                final tanggapan = tanggapanController.text
                                    .trim();

                                if (tanggapan.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Tanggapan admin tidak boleh kosong.',
                                      ),
                                    ),
                                  );
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
                                        'updated_at':
                                            FieldValue.serverTimestamp(),
                                      });

                                  if (!mounted) return;
                                  Navigator.pop(modalContext);

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Tanggapan berhasil dikirimkan ke staf.',
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(
                                    modalContext,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Gagal menyimpan tanggapan: $e',
                                      ),
                                    ),
                                  );
                                } finally {
                                  setModalState(() => isSaving = false);
                                }
                              },
                        child: isSaving
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                'Kirim Tanggapan',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
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

  @override
  Widget build(BuildContext context) {
    return withAdminReadableText(
      context,
      Scaffold(
        backgroundColor: const Color(0xFFF4F8FC),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          toolbarHeight: 96,
          title: const Text(
            "Laporan Kendala Staf",
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
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
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
            ),
          ),
        ),
        body: Column(
          children: [
            const SizedBox(height: 16),

            // --- 1. SEARCH BAR & CHIP FILTER STATUS ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // Search Bar
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 45,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (value) {
                              setState(() {
                                _searchQuery = value;
                              });
                            },
                            decoration: const InputDecoration(
                              hintText: "Cari staf, NIP, atau kendala...",
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.only(top: 10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0066B3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            _searchQuery = _searchController.text;
                          });
                        },
                        child: const Text(
                          "Cari",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Filter Status Chips
                  SingleChildScrollView(
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
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // --- 2. LIST LAPORAN KENDALA DARI FIRESTORE ---
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _firestore
                    .collection('laporan_kendala')
                    .orderBy('created_at', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Gagal memuat kendala: ${snapshot.error}'),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data?.docs ?? [];

                  // Filtering data
                  final filteredDocs = docs.where((doc) {
                    final data = doc.data();
                    final nama = (data['nama_staf'] ?? '')
                        .toString()
                        .toLowerCase();
                    final nip = (data['nip_staf'] ?? '')
                        .toString()
                        .toLowerCase();
                    final deskripsi = (data['deskripsi_kendala'] ?? '')
                        .toString()
                        .toLowerCase();
                    final status = (data['status'] ?? 'Menunggu Respon')
                        .toString();

                    final query = _searchQuery.trim().toLowerCase();

                    bool matchesSearch =
                        query.isEmpty ||
                        nama.contains(query) ||
                        nip.contains(query) ||
                        deskripsi.contains(query);

                    bool matchesFilter = true;
                    if (_selectedFilter == 'Perlu Direspon') {
                      matchesFilter =
                          status == 'Menunggu Respon' ||
                          status == 'Sedang Diproses';
                    } else if (_selectedFilter == 'Selesai') {
                      matchesFilter = status == 'Selesai';
                    }

                    return matchesSearch && matchesFilter;
                  }).toList();

                  if (filteredDocs.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.assignment_turned_in_outlined,
                              size: 50,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'Belum ada laporan kendala dari staf.'
                                  : 'Laporan kendala tidak ditemukan.',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: filteredDocs.length,
                    itemBuilder: (context, index) {
                      final doc = filteredDocs[index];
                      final data = doc.data();
                      final docId = doc.id;

                      final String namaStaf = data['nama_staf'] ?? 'Staf';
                      final String nipStaf = data['nip_staf'] ?? '-';
                      final String judulTugas = data['judul_tugas'] ?? '';
                      final String deskripsi = data['deskripsi_kendala'] ?? '-';
                      final String status = data['status'] ?? 'Menunggu Respon';
                      final String tanggapan = data['tanggapan_admin'] ?? '';

                      Color statusBgColor = Colors.orange.shade50;
                      Color statusTextColor = Colors.orange.shade800;

                      if (status == 'Selesai') {
                        statusBgColor = Colors.green.shade50;
                        statusTextColor = Colors.green.shade800;
                      } else if (status == 'Sedang Diproses') {
                        statusBgColor = Colors.blue.shade50;
                        statusTextColor = Colors.blue.shade800;
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header Staf & Badge Status
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        namaStaf,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        'NIP: $nipStaf',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusBgColor,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    status,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: statusTextColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            if (judulTugas.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Tugas: $judulTugas',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.blue.shade900,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],

                            const SizedBox(height: 10),
                            Text(
                              deskripsi,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black87,
                              ),
                            ),

                            // Tanggapan Admin jika sudah direspon
                            if (tanggapan.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0F4FF),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFFC7D7FE),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(
                                          Icons.reply_rounded,
                                          size: 16,
                                          color: Color(0xFF0066B3),
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Tanggapan Admin:',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF0066B3),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      tanggapan,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 12),

                            // Tombol Berikan / Edit Respon
                            SizedBox(
                              width: double.infinity,
                              height: 36,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: Color(0xFF0066B3),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () =>
                                    _showTanggapanModal(context, docId, data),
                                icon: Icon(
                                  tanggapan.isEmpty
                                      ? Icons.reply_rounded
                                      : Icons.edit_note_rounded,
                                  size: 18,
                                  color: const Color(0xFF0066B3),
                                ),
                                label: Text(
                                  tanggapan.isEmpty
                                      ? 'Beri Tanggapan'
                                      : 'Ubah Tanggapan',
                                  style: const TextStyle(
                                    color: Color(0xFF0066B3),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
        bottomNavigationBar: const AdminBottomNavigationBar(currentIndex: 0),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final bool isSelected = _selectedFilter == label;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFF0066B3),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? const Color(0xFF0066B3) : Colors.grey.shade300,
        ),
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedFilter = label;
          });
        }
      },
    );
  }
}
