import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'admin_navbar.dart';
import 'status_staff.dart';

class KelolaStaffPage extends StatefulWidget {
  const KelolaStaffPage({super.key});

  @override
  State<KelolaStaffPage> createState() => _KelolaStaffPageState();
}

class _KelolaStaffPageState extends State<KelolaStaffPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedStaffImageBase64;
  bool _isSaving = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ==== DIALOG / BOTTOM SHEET TAMBAH & EDIT STAF FIRESTORE ====
  void _showStaffModal({Map<String, dynamic>? staffDoc}) {
    final isEdit = staffDoc != null;
    final String? docId = staffDoc?['id'];

    final namaController = TextEditingController(text: staffDoc?['nama'] ?? '');
    final nipController = TextEditingController(text: staffDoc?['nip'] ?? '');
    final jabatanController = TextEditingController(
      text: staffDoc?['jabatan'] ?? '',
    );
    final waController = TextEditingController(text: staffDoc?['wa'] ?? '');
    _selectedStaffImageBase64 = staffDoc?['foto_base64'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            Future<void> pickImage({bool fromCamera = false}) async {
              final picker = ImagePicker();
              final XFile? image = await (fromCamera
                  ? picker.pickImage(
                      source: ImageSource.camera,
                      imageQuality: 80,
                    )
                  : picker.pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 80,
                    ));

              if (image == null) return;

              final bytes = await image.readAsBytes();
              setModalState(() {
                _selectedStaffImageBase64 = base64Encode(bytes);
              });
            }

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
                        Text(
                          isEdit ? 'Edit Data Staf' : 'Tambah Staf Baru',
                          style: const TextStyle(
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
                    const SizedBox(height: 15),

                    // Avatar Foto Profil
                    Center(
                      child: InkWell(
                        onTap: () => showModalBottomSheet(
                          context: modalContext,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(20),
                            ),
                          ),
                          builder: (_) => SafeArea(
                            child: Wrap(
                              children: [
                                ListTile(
                                  leading: const Icon(
                                    Icons.photo_library_rounded,
                                  ),
                                  title: const Text('Pilih dari galeri'),
                                  onTap: () {
                                    Navigator.pop(modalContext);
                                    pickImage();
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.camera_alt_rounded),
                                  title: const Text('Ambil foto'),
                                  onTap: () {
                                    Navigator.pop(modalContext);
                                    pickImage(fromCamera: true);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 35,
                          backgroundColor: const Color(
                            0xFF0066B3,
                          ).withOpacity(0.1),
                          backgroundImage:
                              _selectedStaffImageBase64 != null &&
                                  _selectedStaffImageBase64!.isNotEmpty
                              ? MemoryImage(
                                  base64Decode(_selectedStaffImageBase64!),
                                )
                              : null,
                          child:
                              _selectedStaffImageBase64 == null ||
                                  _selectedStaffImageBase64!.isEmpty
                              ? const Icon(
                                  Icons.add_a_photo,
                                  color: Color(0xFF0066B3),
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),

                    _buildModalTextField('Nama Lengkap', namaController),
                    _buildModalTextField(
                      'NIP',
                      nipController,
                      enabled: !isEdit,
                    ),
                    _buildModalTextField('Jabatan', jabatanController),
                    _buildModalTextField(
                      'No. WhatsApp',
                      waController,
                      keyboardType: TextInputType.phone,
                    ),

                    const SizedBox(height: 15),

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
                        onPressed: _isSaving
                            ? null
                            : () async {
                                final nama = namaController.text.trim();
                                final nip = nipController.text.trim();
                                final jabatan = jabatanController.text.trim();
                                final wa = waController.text.trim();

                                if (nama.isEmpty ||
                                    nip.isEmpty ||
                                    jabatan.isEmpty ||
                                    wa.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Semua data staf harus diisi.',
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                setModalState(() {
                                  _isSaving = true;
                                });

                                try {
                                  if (isEdit && docId != null) {
                                    // UPDATE DATA STAF DI FIRESTORE
                                    await _firestore
                                        .collection('users')
                                        .doc(docId)
                                        .update({
                                          'nama': nama,
                                          'jabatan': jabatan,
                                          'wa': wa,
                                          'foto_base64':
                                              _selectedStaffImageBase64 ?? '',
                                          'updated_at':
                                              FieldValue.serverTimestamp(),
                                        });
                                  } else {
                                    // TAMBAH STAF BARU KE FIRESTORE & AUTH
                                    final String virtualEmail =
                                        "$nip@simtas.internal";
                                    final String defaultPassword = nip;

                                    UserCredential credential =
                                        await FirebaseAuth.instance
                                            .createUserWithEmailAndPassword(
                                              email: virtualEmail,
                                              password: defaultPassword,
                                            );

                                    final String newUid = credential.user!.uid;

                                    await _firestore
                                        .collection('users')
                                        .doc(newUid)
                                        .set({
                                          'uid': newUid,
                                          'nama': nama,
                                          'nip': nip,
                                          'jabatan': jabatan,
                                          'wa': wa,
                                          'role': 'staff',
                                          'status': 'Tersedia',
                                          'foto_base64':
                                              _selectedStaffImageBase64 ?? '',
                                          'is_first_login': true,
                                          'created_at':
                                              FieldValue.serverTimestamp(),
                                          'updated_at':
                                              FieldValue.serverTimestamp(),
                                        });
                                  }

                                  if (!mounted) return;
                                  _selectedStaffImageBase64 = null;
                                  Navigator.pop(modalContext);

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        isEdit
                                            ? 'Data staf berhasil diperbarui'
                                            : 'Staf baru berhasil ditambahkan! Password awal adalah NIP.',
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(
                                    modalContext,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text('Gagal menyimpan data: $e'),
                                    ),
                                  );
                                } finally {
                                  setModalState(() {
                                    _isSaving = false;
                                  });
                                }
                              },
                        child: _isSaving
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : Text(
                                isEdit
                                    ? 'Simpan Perubahan'
                                    : 'Simpan Data Staf',
                                style: const TextStyle(
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

  // ==== HAPUS STAF DARI FIRESTORE ====
  void _deleteStaff(String docId, String namaStaff) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Staf'),
        content: Text('Yakin ingin menghapus $namaStaff dari daftar staf?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await _firestore.collection('users').doc(docId).delete();
                if (!mounted) return;
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$namaStaff berhasil dihapus')),
                );
              } catch (e) {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Gagal menghapus staf: $e')),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  Widget _buildModalTextField(
    String label,
    TextEditingController controller, {
    bool enabled = true,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
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
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
          ),
          title: const Text(
            "Kelola Staff",
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
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // --- 1. SEARCH BAR & TOMBOL CARI ---
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
                          hintText: "Pencarian...",
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

              const SizedBox(height: 16),

              // --- 2. GRID CARD STAF DARI FIRESTORE (REAL-TIME STREAM) ---
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _firestore.collection('users').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Gagal memuat staf: ${snapshot.error}'),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data?.docs ?? [];

                  // Filter agar hanya akun Staf yang tampil dan sesuai query pencarian
                  final filteredDocs = docs.where((doc) {
                    final data = doc.data();
                    final role = (data['role'] ?? 'staff')
                        .toString()
                        .toLowerCase();

                    if (role == 'admin') return false;

                    final nama = (data['nama'] ?? '').toString().toLowerCase();
                    final nip = (data['nip'] ?? '').toString().toLowerCase();
                    final jabatan = (data['jabatan'] ?? '')
                        .toString()
                        .toLowerCase();
                    final query = _searchQuery.trim().toLowerCase();

                    return query.isEmpty ||
                        nama.contains(query) ||
                        nip.contains(query) ||
                        jabatan.contains(query);
                  }).toList();

                  if (filteredDocs.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          _searchQuery.isEmpty
                              ? 'Belum ada data staf terdaftar.'
                              : 'Staf tidak ditemukan.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                    );
                  }

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.76,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                    itemCount: filteredDocs.length,
                    itemBuilder: (context, index) {
                      final doc = filteredDocs[index];
                      final staff = doc.data();
                      final docId = doc.id;

                      final String nama =
                          staff['nama'] ?? staff['email'] ?? 'Staf';
                      final String nip = staff['nip'] ?? '-';
                      final String jabatan = staff['jabatan'] ?? '-';
                      final String wa = staff['wa'] ?? '-';
                      final String status = staff['status'] ?? 'Tersedia';
                      final String? fotoBase64 = staff['foto_base64'];

                      final bool isTersedia = status == "Tersedia";

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Foto Profil Lingkaran
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: const Color(0xFF0066B3),
                              backgroundImage:
                                  fotoBase64 != null && fotoBase64.isNotEmpty
                                  ? MemoryImage(base64Decode(fotoBase64))
                                  : null,
                              child: fotoBase64 == null || fotoBase64.isEmpty
                                  ? const Icon(
                                      Icons.person,
                                      color: Colors.white,
                                      size: 32,
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 10),

                            // Detail Staf
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Nama : $nama",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  "NIP : $nip",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  "Jabatan : $jabatan",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  "WA : $wa",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),

                            const Divider(height: 12, thickness: 1),

                            // Status Aktif
                            GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const StatusStaffPage(),
                                ),
                              ),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: isTersedia
                                      ? Colors.green.shade50
                                      : Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  "Status : $status",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isTersedia
                                        ? Colors.green.shade800
                                        : Colors.orange.shade800,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 8),

                            // Tombol Edit dan Hapus
                            Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 30,
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        side: const BorderSide(
                                          color: Colors.amber,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      onPressed: () => _showStaffModal(
                                        staffDoc: {'id': docId, ...staff},
                                      ),
                                      child: const Text(
                                        "Edit",
                                        style: TextStyle(
                                          color: Colors.amber,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: SizedBox(
                                    height: 30,
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        side: const BorderSide(
                                          color: Colors.redAccent,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      onPressed: () =>
                                          _deleteStaff(docId, nama),
                                      child: const Text(
                                        "Hapus",
                                        style: TextStyle(
                                          color: Colors.redAccent,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showStaffModal(),
          backgroundColor: const Color(0xFF0011CC),
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text(
            'Tambah Staff',
            style: TextStyle(color: Colors.white),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        bottomNavigationBar: const AdminBottomNavigationBar(currentIndex: 3),
      ),
    );
  }
}
