import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'admin_navbar.dart';
import 'status_staff.dart';

class KelolaStaffPage extends StatefulWidget {
  const KelolaStaffPage({super.key});

  @override
  State<KelolaStaffPage> createState() => _KelolaStaffPageState();
}

class _KelolaStaffPageState extends State<KelolaStaffPage> {
  static const _staffStorageKey = 'kelola_staff_list';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedStaffImageBase64;
  bool _isLoadingStaff = true;

  // Data dummy staf
  final List<Map<String, String>> staffList = [
    {
      'nama': 'Syavira Fitri',
      'nip': '199508122026',
      'jabatan': 'Pranata Humas',
      'wa': '081234567890',
      'status': 'Tersedia',
    },
    {
      'nama': 'Ahmad Dahlan',
      'nip': '199203152026',
      'jabatan': 'Staf IT',
      'wa': '081398765432',
      'status': 'Sibuk',
    },
    {
      'nama': 'Budi Prayitno',
      'nip': '199001012026',
      'jabatan': 'Desainer Grafis',
      'wa': '081122334455',
      'status': 'Tersedia',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadStaffList();
  }

  Future<void> _loadStaffList() async {
    final preferences = await SharedPreferences.getInstance();
    final storedStaff = preferences.getString(_staffStorageKey);

    if (!mounted) return;

    if (storedStaff != null && storedStaff.isNotEmpty) {
      final decoded = jsonDecode(storedStaff);
      if (decoded is List) {
        staffList
          ..clear()
          ..addAll(
            decoded.whereType<Map>().map(
              (staff) => staff.map(
                (key, value) => MapEntry(key.toString(), value.toString()),
              ),
            ),
          );
      }
    }

    setState(() {
      _isLoadingStaff = false;
    });
  }

  Future<void> _saveStaffList() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_staffStorageKey, jsonEncode(staffList));
  }

  List<Map<String, String>> get _filteredStaffList {
    if (_searchQuery.trim().isEmpty) return staffList;

    final query = _searchQuery.trim().toLowerCase();
    return staffList.where((staff) {
      final nama = (staff['nama'] ?? '').toLowerCase();
      final nip = (staff['nip'] ?? '').toLowerCase();
      final jabatan = (staff['jabatan'] ?? '').toLowerCase();
      return nama.contains(query) ||
          nip.contains(query) ||
          jabatan.contains(query);
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showStaffModal({Map<String, String>? staff, int? index}) {
    final isEdit = staff != null && index != null;
    final namaController = TextEditingController(text: staff?['nama'] ?? '');
    final nipController = TextEditingController(text: staff?['nip'] ?? '');
    final jabatanController = TextEditingController(
      text: staff?['jabatan'] ?? '',
    );
    final waController = TextEditingController(text: staff?['wa'] ?? '');
    _selectedStaffImageBase64 = staff?['imageBase64'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        Future<void> pickImage({bool fromCamera = false}) async {
          final picker = ImagePicker();
          final XFile? image = await (fromCamera
              ? picker.pickImage(source: ImageSource.camera, imageQuality: 85)
              : picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 85,
                ));

          if (image == null) return;

          final bytes = await image.readAsBytes();
          if (!mounted) return;

          setState(() {
            _selectedStaffImageBase64 = base64Encode(bytes);
          });
        }

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEdit ? 'Edit Staff' : 'Tambah Staff Baru',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B267B),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Center(
                child: InkWell(
                  onTap: () => showModalBottomSheet(
                    context: context,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    builder: (_) => SafeArea(
                      child: Wrap(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.photo_library_rounded),
                            title: const Text('Pilih dari galeri'),
                            onTap: () {
                              Navigator.pop(context);
                              pickImage();
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.camera_alt_rounded),
                            title: const Text('Ambil foto'),
                            onTap: () {
                              Navigator.pop(context);
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
                    ).withValues(alpha: 0.1),
                    backgroundImage:
                        _selectedStaffImageBase64 != null &&
                            _selectedStaffImageBase64!.isNotEmpty
                        ? MemoryImage(base64Decode(_selectedStaffImageBase64!))
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
              _buildModalTextField('NIP', nipController),
              _buildModalTextField('Jabatan', jabatanController),
              _buildModalTextField('No. WhatsApp', waController),
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
                  onPressed: () async {
                    final newData = {
                      'nama': namaController.text.trim(),
                      'nip': nipController.text.trim(),
                      'jabatan': jabatanController.text.trim(),
                      'wa': waController.text.trim(),
                      'status': staff?['status'] ?? 'Tersedia',
                      'imageBase64':
                          _selectedStaffImageBase64 ??
                          staff?['imageBase64'] ??
                          '',
                    };

                    final nama = newData['nama'] ?? '';
                    final nip = newData['nip'] ?? '';
                    final jabatan = newData['jabatan'] ?? '';
                    final wa = newData['wa'] ?? '';

                    if (nama.isEmpty ||
                        nip.isEmpty ||
                        jabatan.isEmpty ||
                        wa.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Semua data staff harus diisi.'),
                        ),
                      );
                      return;
                    }

                    setState(() {
                      if (index != null) {
                        staffList[index] = newData;
                      } else {
                        staffList.add(newData);
                      }
                    });
                    await _saveStaffList();

                    _selectedStaffImageBase64 = null;
                    Navigator.pop(context);
                  },
                  child: Text(
                    isEdit ? 'Simpan Perubahan' : 'Simpan Data Staff',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _deleteStaff(int index) {
    final staff = staffList[index];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Staff'),
        content: Text(
          'Yakin ingin menghapus ${staff['nama']} dari daftar staff?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              setState(() => staffList.removeAt(index));
              await _saveStaffList();
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  Widget _buildModalTextField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
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
              // --- 1. SEARCH BAR & TOMBOL CARI (SESUAI SKETSA) ---
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

              const SizedBox(height: 12),

              const SizedBox(height: 16),

              // --- 3. GRID CARD STAF (2 KOLOM BERSAMPINGAN) ---
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, // 2 Card Bersampingan
                  childAspectRatio:
                      0.76, // Cukup tinggi agar tombol tidak overflow
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: _filteredStaffList.length,
                itemBuilder: (context, index) {
                  final actualIndex = staffList.indexOf(
                    _filteredStaffList[index],
                  );
                  final staff = _filteredStaffList[index];
                  bool isTersedia = staff['status'] == "Tersedia";

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
                        // Foto Profil Lingkaran Atas
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: const Color(0xFF0066B3),
                          backgroundImage:
                              (staff['imageBase64'] != null &&
                                  staff['imageBase64']!.isNotEmpty)
                              ? MemoryImage(base64Decode(staff['imageBase64']!))
                              : null,
                          child:
                              (staff['imageBase64'] == null ||
                                  staff['imageBase64']!.isEmpty)
                              ? const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 32,
                                )
                              : null,
                        ),
                        const SizedBox(height: 10),

                        // Detail Data Staf
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Nama : ${staff['nama']}",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              "NIP : ${staff['nip']}",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              "Jabatan : ${staff['jabatan']}",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              "WA : ${staff['wa']}",
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
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            decoration: BoxDecoration(
                              color: isTersedia
                                  ? Colors.green.shade50
                                  : Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              "Status : ${staff['status']}",
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

                        // Tombol Edit dan Hapus Bersampingan
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 30,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    side: const BorderSide(color: Colors.amber),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: () => _showStaffModal(
                                    staff: staff,
                                    index: actualIndex,
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
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: () => _deleteStaff(actualIndex),
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
