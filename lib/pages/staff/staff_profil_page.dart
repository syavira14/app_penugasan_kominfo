import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class AppColors {
  static const Color biruTua = Color(0xFF0011CC);
  static const Color biruSedang = Color(0xFF0066FF);
  static const Color cyan = Color(0xFF00CCFF);
  static const Color putih = Colors.white;
  static const Color abuTeks = Color(0xFF5A6472);
  static const Color latarAbu = Color(0xFFF4F6FB);
  static const Color abuBorder = Color(0xFFE1E5F0);
}

class StaffProfilPage extends StatefulWidget {
  const StaffProfilPage({super.key});

  @override
  State<StaffProfilPage> createState() => _StaffProfilPageState();
}

class _StaffProfilPageState extends State<StaffProfilPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _namaController;
  late final TextEditingController _jabatanController;
  late final TextEditingController _emailController;
  late final TextEditingController _noHpController;

  final ImagePicker _imagePicker = ImagePicker();
  Uint8List? _fotoProfilBytes;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _namaController = TextEditingController(text: 'Ahmad Fauzi');
    _jabatanController = TextEditingController(text: 'Staf Infrastruktur TIK');
    _emailController = TextEditingController(text: 'ahmad.fauzi@kominfo.go.id');
    _noHpController = TextEditingController(text: '0812-3456-7890');
  }

  @override
  void dispose() {
    _namaController.dispose();
    _jabatanController.dispose();
    _emailController.dispose();
    _noHpController.dispose();
    super.dispose();
  }

  void _simpanProfil() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isEditing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Profil staff berhasil diperbarui'),
        backgroundColor: AppColors.biruTua,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _pilihFoto(ImageSource source) async {
    try {
      final XFile? pickedImage = await _imagePicker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 800,
      );
      if (pickedImage == null) return;

      final bytes = await pickedImage.readAsBytes();
      if (!mounted) return;
      setState(() => _fotoProfilBytes = bytes);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Gagal memilih foto. Periksa izin akses perangkat.',
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

  void _tampilkanPilihanFoto() {
    if (!_isEditing) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.putih,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.abuBorder,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(
                    Icons.photo_library_outlined,
                    color: AppColors.biruSedang,
                  ),
                  title: const Text('Pilih dari Galeri'),
                  onTap: () {
                    Navigator.pop(context);
                    _pilihFoto(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.camera_alt_outlined,
                    color: AppColors.biruSedang,
                  ),
                  title: const Text('Ambil Foto Kamera'),
                  onTap: () {
                    Navigator.pop(context);
                    _pilihFoto(ImageSource.camera);
                  },
                ),
                if (_fotoProfilBytes != null)
                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.redAccent,
                    ),
                    title: const Text('Hapus Foto'),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _fotoProfilBytes = null);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.latarAbu,
      appBar: AppBar(
        backgroundColor: AppColors.biruTua,
        foregroundColor: AppColors.putih,
        title: const Text(
          'Profil Staff',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: _isEditing ? 'Batal edit' : 'Edit profil',
            icon: Icon(_isEditing ? Icons.close_rounded : Icons.edit_outlined),
            onPressed: () => setState(() => _isEditing = !_isEditing),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.putih,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.biruTua.withOpacity(0.06),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      GestureDetector(
                        onTap: _tampilkanPilihanFoto,
                        child: CircleAvatar(
                          radius: 52,
                          backgroundColor: AppColors.biruSedang.withOpacity(
                            0.12,
                          ),
                          backgroundImage: _fotoProfilBytes == null
                              ? null
                              : MemoryImage(_fotoProfilBytes!),
                          child: _fotoProfilBytes == null
                              ? const Icon(
                                  Icons.person_rounded,
                                  color: AppColors.biruSedang,
                                  size: 56,
                                )
                              : null,
                        ),
                      ),
                      if (_isEditing)
                        Container(
                          width: 34,
                          height: 34,
                          decoration: const BoxDecoration(
                            color: AppColors.biruTua,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(
                              Icons.camera_alt_outlined,
                              color: AppColors.putih,
                              size: 17,
                            ),
                            onPressed: _tampilkanPilihanFoto,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _namaController.text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.biruTua,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _jabatanController.text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.abuTeks,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _ProfileField(
              label: 'Nama Lengkap',
              icon: Icons.badge_outlined,
              controller: _namaController,
              enabled: _isEditing,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Nama lengkap wajib diisi'
                  : null,
              onChanged: (_) => setState(() {}),
            ),
            _ProfileField(
              label: 'Jabatan',
              icon: Icons.work_outline_rounded,
              controller: _jabatanController,
              enabled: _isEditing,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Jabatan wajib diisi'
                  : null,
              onChanged: (_) => setState(() {}),
            ),
            _ProfileField(
              label: 'Email',
              icon: Icons.email_outlined,
              controller: _emailController,
              enabled: _isEditing,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return 'Email wajib diisi';
                if (!text.contains('@')) return 'Format email belum valid';
                return null;
              },
            ),
            _ProfileField(
              label: 'No HP',
              icon: Icons.phone_outlined,
              controller: _noHpController,
              enabled: _isEditing,
              keyboardType: TextInputType.phone,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'No HP wajib diisi'
                  : null,
            ),
            const SizedBox(height: 16),
            if (_isEditing)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _simpanProfil,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.biruTua,
                    foregroundColor: AppColors.putih,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: const Text(
                    'Simpan Profil',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  final String label;
  final IconData icon;
  final TextEditingController controller;
  final bool enabled;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;

  const _ProfileField({
    required this.label,
    required this.icon,
    required this.controller,
    required this.enabled,
    this.keyboardType,
    this.validator,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.biruTua,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            enabled: enabled,
            keyboardType: keyboardType,
            validator: validator,
            onChanged: onChanged,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: AppColors.biruSedang, size: 20),
              filled: true,
              fillColor: enabled ? AppColors.putih : const Color(0xFFF8FAFE),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 14,
                horizontal: 14,
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.abuBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.abuBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.biruSedang,
                  width: 1.6,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.redAccent),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
