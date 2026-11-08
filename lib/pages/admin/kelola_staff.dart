import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../theme/app_theme.dart';
import '/widgets/admin_header.dart';
import 'admin_sidebar.dart';
import 'status_staff.dart';

class KelolaStaffPage extends StatefulWidget {
  const KelolaStaffPage({super.key});

  @override
  State<KelolaStaffPage> createState() => _KelolaStaffPageState();
}

class _KelolaStaffPageState extends State<KelolaStaffPage> {
  static const Color _biruTua = AppPalette.navy;
  static const Color _biru = AppPalette.blue;
  static const Color _biruMuda = AppPalette.sky;
  static const Color _bg = AppPalette.background;

  static const int _maksTugasAktif = 5;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _usersStream =
      _firestore.collection('users').snapshots();

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _assignmentsStream =
      _firestore.collection('penugasan').snapshots();

  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _str(dynamic value, [String fallback = '']) {
    if (value == null) return fallback;
    final result = value.toString().trim();
    return result.isEmpty ? fallback : result;
  }

  String _phoneOf(Map<String, dynamic>? data) {
    if (data == null) return '';

    for (final key in [
      'wa',
      'no_hp',
      'noHp',
      'nomor_hp',
      'no_telp',
      'telepon',
    ]) {
      final value = _str(data[key]);
      if (value.isNotEmpty) return value;
    }

    return '';
  }

  ImageProvider? _decodeFoto(dynamic value) {
    final foto = _str(value);
    if (foto.isEmpty) return null;

    try {
      return MemoryImage(base64Decode(foto));
    } catch (_) {
      return null;
    }
  }

  bool _isActiveStatus(dynamic value) {
    final status = _str(value, 'pending').toLowerCase();

    return !const [
      'disetujui',
      'selesai',
      'antrean',
      'menunggu giliran',
    ].contains(status);
  }

  int _countActive(
    String uid,
    Map<String, dynamic> staff,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> assignments,
  ) {
    final nama = _str(staff['nama']).toLowerCase();
    final nip = _str(staff['nip']);

    int total = 0;

    for (final doc in assignments) {
      final data = doc.data();

      final staffUid = _str(
        data['staff_uid'] ??
            data['staff_id'] ??
            data['uid_staff'] ??
            data['user_id'],
      );

      final staffNama = _str(
        data['staff_nama'] ?? data['nama_staff'],
      ).toLowerCase();

      final staffNip = _str(
        data['staff_nip'] ?? data['nip_staff'],
      );

      final cocok =
          (staffUid.isNotEmpty && staffUid == uid) ||
          (nama.isNotEmpty && staffNama == nama) ||
          (nip.isNotEmpty && staffNip == nip);

      if (cocok && _isActiveStatus(data['status'])) {
        total++;
      }
    }

    return total;
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

  // ============================================================
  // FIREBASE AUTHENTICATION
  // ============================================================

  Future<FirebaseAuth> _secondaryAuth() async {
    FirebaseApp app;

    try {
      app = Firebase.app('staffCreator');
    } catch (_) {
      app = await Firebase.initializeApp(
        name: 'staffCreator',
        options: Firebase.app().options,
      );
    }

    return FirebaseAuth.instanceFor(app: app);
  }

  Future<void> _setStaffPassword(
    String uid,
    String password,
  ) async {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'adminSetPassword',
    );

    await callable.call({
      'uid': uid,
      'password': password,
    });
  }

  Future<String> _setStaffNip(
    String uid,
    String nip,
  ) async {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'adminSetNip',
    );

    final result = await callable.call({
      'uid': uid,
      'nip': nip,
    });

    final data = result.data;

    if (data is Map && data['email'] != null) {
      return data['email'].toString();
    }

    return '$nip@simtas.internal';
  }

  String _errorMessage(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'email-already-in-use':
          return 'NIP sudah memiliki akun login.';
        case 'weak-password':
          return 'Password minimal 6 karakter.';
        default:
          return error.message ?? error.code;
      }
    }

    if (error is FirebaseFunctionsException) {
      if (error.code == 'not-found' ||
          error.code == 'unimplemented') {
        return 'Cloud Function adminSetPassword atau adminSetNip belum tersedia.';
      }

      return error.message ?? error.code;
    }

    if (error is FirebaseException) {
      if (error.code == 'permission-denied') {
        return 'Akses ditolak oleh aturan Firestore.';
      }

      return error.message ?? error.code;
    }

    return error.toString();
  }

  // ============================================================
  // FORM TAMBAH / EDIT STAFF
  // ============================================================

  void _showStaffModal({
    Map<String, dynamic>? staffDoc,
  }) {
    final bool isEdit = staffDoc != null;
    final String? docId = staffDoc?['id']?.toString();

    final oldNip = _str(staffDoc?['nip']);

    final namaC = TextEditingController(
      text: _str(staffDoc?['nama']),
    );

    final nipC = TextEditingController(
      text: oldNip,
    );

    final jabatanC = TextEditingController(
      text: _str(staffDoc?['jabatan']),
    );

    final emailC = TextEditingController(
      text: _str(staffDoc?['email_kontak']),
    );

    final waC = TextEditingController(
      text: _phoneOf(staffDoc),
    );

    final passC = TextEditingController();

    String? fotoBase64 = _str(staffDoc?['foto_base64']);
    bool saving = false;
    bool obscure = true;
    String? errorText;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            Future<void> pickImage(ImageSource source) async {
              try {
                final image = await ImagePicker().pickImage(
                  source: source,
                  imageQuality: 70,
                  maxWidth: 512,
                  maxHeight: 512,
                );

                if (image == null) return;

                final bytes = await image.readAsBytes();

                if (!modalContext.mounted) return;

                if (base64Encode(bytes).length > 700000) {
                  ScaffoldMessenger.of(modalContext).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Foto terlalu besar. Pilih foto yang lebih kecil.',
                      ),
                    ),
                  );
                  return;
                }

                setModalState(() {
                  fotoBase64 = base64Encode(bytes);
                });
              } catch (e) {
                if (modalContext.mounted) {
                  ScaffoldMessenger.of(modalContext).showSnackBar(
                    SnackBar(
                      content: Text('Gagal memilih foto: $e'),
                    ),
                  );
                }
              }
            }

            void showPhotoOptions() {
              showDialog(
                context: modalContext,
                builder: (photoContext) {
                  return SimpleDialog(
                    title: const Text('Foto Staf'),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    children: [
                      SimpleDialogOption(
                        onPressed: () {
                          Navigator.pop(photoContext);
                          pickImage(ImageSource.gallery);
                        },
                        child: const Row(
                          children: [
                            Icon(
                              Icons.photo_library_rounded,
                              color: _biru,
                            ),
                            SizedBox(width: 12),
                            Text('Pilih dari galeri'),
                          ],
                        ),
                      ),
                      SimpleDialogOption(
                        onPressed: () {
                          Navigator.pop(photoContext);
                          pickImage(ImageSource.camera);
                        },
                        child: const Row(
                          children: [
                            Icon(
                              Icons.camera_alt_rounded,
                              color: _biru,
                            ),
                            SizedBox(width: 12),
                            Text('Ambil foto'),
                          ],
                        ),
                      ),
                      if (fotoBase64 != null &&
                          fotoBase64!.isNotEmpty)
                        SimpleDialogOption(
                          onPressed: () {
                            Navigator.pop(photoContext);
                            setModalState(() {
                              fotoBase64 = null;
                            });
                          },
                          child: const Row(
                            children: [
                              Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.redAccent,
                              ),
                              SizedBox(width: 12),
                              Text('Hapus foto'),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              );
            }

            Future<void> save() async {
              final nama = namaC.text.trim();
              final nip = nipC.text.trim();
              final jabatan = jabatanC.text.trim();
              final wa = waC.text.trim();
              final emailKontak = emailC.text.trim();
              final password = passC.text;

              final nipBerubah = isEdit && nip != oldNip;

              if (nama.isEmpty ||
                  nip.isEmpty ||
                  jabatan.isEmpty) {
                setModalState(() {
                  errorText = 'Nama, NIP, dan jabatan wajib diisi.';
                });
                return;
              }

              if ((!isEdit || nipBerubah) &&
                  !RegExp(r'^[0-9]{6,30}$').hasMatch(nip)) {
                setModalState(() {
                  errorText = 'NIP harus berupa 6–30 digit angka.';
                });
                return;
              }

              if (wa.length > 30) {
                setModalState(() {
                  errorText = 'Nomor WhatsApp maksimal 30 karakter.';
                });
                return;
              }

              if (emailKontak.isNotEmpty &&
                  !RegExp(
                    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                  ).hasMatch(emailKontak)) {
                setModalState(() {
                  errorText = 'Format email tidak valid.';
                });
                return;
              }

              if (!isEdit && password.length < 6) {
                setModalState(() {
                  errorText = 'Password minimal 6 karakter.';
                });
                return;
              }

              if (isEdit &&
                  password.isNotEmpty &&
                  password.length < 6) {
                setModalState(() {
                  errorText = 'Password baru minimal 6 karakter.';
                });
                return;
              }

              setModalState(() {
                saving = true;
                errorText = null;
              });

              try {
                if (isEdit && docId != null) {
                  if (password.isNotEmpty) {
                    await _setStaffPassword(docId, password);
                  }

                  String? emailLoginBaru;

                  if (nipBerubah) {
                    emailLoginBaru = await _setStaffNip(
                      docId,
                      nip,
                    );
                  }

                  await _firestore
                      .collection('users')
                      .doc(docId)
                      .update({
                    'nama': nama,
                    'nip': nip,
                    if (emailLoginBaru != null)
                      'email': emailLoginBaru,
                    'email_kontak': emailKontak,
                    'jabatan': jabatan,
                    'no_hp': wa,
                    'foto_base64': fotoBase64 ?? '',
                    'updated_at': FieldValue.serverTimestamp(),
                  });
                } else {
                  final email = '$nip@simtas.internal';

                  final existing = await _firestore
                      .collection('users')
                      .where('nip', isEqualTo: nip)
                      .limit(1)
                      .get();

                  if (existing.docs.isNotEmpty) {
                    throw StateError(
                      'NIP sudah terdaftar.',
                    );
                  }

                  final auth = await _secondaryAuth();

                  UserCredential? credential;

                  try {
                    credential =
                        await auth.createUserWithEmailAndPassword(
                      email: email,
                      password: password,
                    );

                    final uid = credential.user!.uid;

                    await _firestore
                        .collection('users')
                        .doc(uid)
                        .set({
                      'uid': uid,
                      'email': email,
                      'nama': nama,
                      'nip': nip,
                      'email_kontak': emailKontak,
                      'jabatan': jabatan,
                      'no_hp': wa,
                      'role': 'staff',
                      'status_pekerjaan': 'tersedia',
                      'foto_base64': fotoBase64 ?? '',
                      'is_first_login': true,
                      'created_at': FieldValue.serverTimestamp(),
                      'updated_at': FieldValue.serverTimestamp(),
                    });
                  } catch (e) {
                    try {
                      await credential?.user?.delete();
                    } catch (_) {}

                    rethrow;
                  } finally {
                    await auth.signOut();
                  }
                }

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }

                _snack(
                  isEdit
                      ? 'Data staf berhasil diperbarui.'
                      : 'Staf baru berhasil ditambahkan.',
                );
              } catch (e) {
                if (modalContext.mounted) {
                  setModalState(() {
                    saving = false;
                    errorText = _errorMessage(e);
                  });
                }
              }
            }

            final foto = _decodeFoto(fotoBase64);

            return Dialog(
              backgroundColor: Colors.white,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 440,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    22,
                    18,
                    22,
                    22,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              isEdit
                                  ? 'Edit Data Staf'
                                  : 'Tambah Staf Baru',
                              style: const TextStyle(
                                fontSize: AppTypography.subtitle,
                                fontWeight: FontWeight.bold,
                                color: _biruTua,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: saving
                                ? null
                                : () => Navigator.pop(dialogContext),
                            icon: const Icon(
                              Icons.close_rounded,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      Center(
                        child: GestureDetector(
                          onTap: saving ? null : showPhotoOptions,
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 40,
                                backgroundColor:
                                    _biru.withOpacity(0.1),
                                backgroundImage: foto,
                                child: foto == null
                                    ? const Icon(
                                        Icons.person_rounded,
                                        size: 40,
                                        color: _biru,
                                      )
                                    : null,
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: _biru,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt_rounded,
                                    size: 15,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      _buildModalTextField(
                        'Nama Lengkap',
                        namaC,
                        Icons.person_outline_rounded,
                        hint: 'Masukkan nama lengkap',
                        textCapitalization:
                            TextCapitalization.words,
                      ),

                      _buildModalTextField(
                        'NIP',
                        nipC,
                        Icons.badge_outlined,
                        hint: 'Masukkan NIP',
                        keyboardType: TextInputType.number,
                        helperText:
                            'NIP digunakan sebagai identitas login.',
                      ),

                      _buildModalTextField(
                        'Jabatan',
                        jabatanC,
                        Icons.work_outline_rounded,
                        hint: 'Masukkan jabatan',
                        textCapitalization:
                            TextCapitalization.words,
                      ),

                      _buildModalTextField(
                        'Email (opsional)',
                        emailC,
                        Icons.email_outlined,
                        hint: 'Masukkan email staf',
                        keyboardType:
                            TextInputType.emailAddress,
                      ),

                      _buildModalTextField(
                        'No. WhatsApp (opsional)',
                        waC,
                        Icons.phone_outlined,
                        hint: 'Contoh: 08123456789',
                        keyboardType: TextInputType.phone,
                      ),

                      _buildModalTextField(
                        isEdit
                            ? 'Kata Sandi Baru (opsional)'
                            : 'Kata Sandi',
                        passC,
                        Icons.lock_outline_rounded,
                        hint: 'Masukkan kata sandi',
                        obscureText: obscure,
                        helperText: isEdit
                            ? 'Kosongkan jika tidak ingin mengubah password.'
                            : 'Minimal 6 karakter.',
                        suffixIcon: IconButton(
                          onPressed: () {
                            setModalState(() {
                              obscure = !obscure;
                            });
                          },
                          icon: Icon(
                            obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),

                      TextButton.icon(
                        onPressed: saving
                            ? null
                            : () {
                                final nip = nipC.text.trim();

                                if (nip.length < 6) {
                                  setModalState(() {
                                    errorText =
                                        'Isi NIP terlebih dahulu.';
                                  });
                                  return;
                                }

                                setModalState(() {
                                  passC.text = nip;
                                  obscure = false;
                                  errorText = null;
                                });
                              },
                        icon: const Icon(
                          Icons.restart_alt_rounded,
                        ),
                        label: Text(
                          isEdit
                              ? 'Reset password sama dengan NIP'
                              : 'Isi password sama dengan NIP',
                        ),
                      ),

                      if (errorText != null)
                        Padding(
                          padding: const EdgeInsets.only(
                            top: 10,
                            bottom: 10,
                          ),
                          child: Text(
                            errorText!,
                            style: const TextStyle(
                              color: Colors.redAccent,
                            ),
                          ),
                        ),

                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: saving
                                  ? null
                                  : () => Navigator.pop(
                                        dialogContext,
                                      ),
                              child: const Text('Batal'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: saving ? null : save,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _biru,
                              ),
                              child: saving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child:
                                          CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      isEdit
                                          ? 'Simpan Perubahan'
                                          : 'Simpan Data Staf',
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModalTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    String? hint,
    bool enabled = true,
    bool obscureText = false,
    Widget? suffixIcon,
    String? helperText,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization =
        TextCapitalization.none,
  }) {
    const borderColor = Color(0xFFE2E8F0);

    OutlineInputBorder border(
      Color color, [
      double width = 1,
    ]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: color,
          width: width,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: AppTypography.body,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            enabled: enabled,
            obscureText: obscureText,
            keyboardType: keyboardType,
            textCapitalization: textCapitalization,
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: Icon(
                icon,
                color: const Color(0xFF64748B),
              ),
              suffixIcon: suffixIcon,
              filled: true,
              fillColor: AppPalette.background,
              contentPadding:
                  const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 16,
              ),
              enabledBorder: border(borderColor),
              border: border(borderColor),
              focusedBorder: border(_biru, 1.5),
            ),
          ),
          if (helperText != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                helperText,
                style: const TextStyle(
                  fontSize: AppTypography.small,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // HAPUS STAF
  // ============================================================

  void _deleteStaff(
    String docId,
    String namaStaff,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Hapus Staf'),
          content: Text(
            'Yakin ingin menghapus $namaStaff dari daftar staf?',
          ),
          actions: [
            OutlinedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _firestore
                      .collection('users')
                      .doc(docId)
                      .delete();

                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }

                  _snack('$namaStaff berhasil dihapus');
                } catch (e) {
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }

                  _snack('Gagal menghapus staf: $e');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              child: const Text(
                'Hapus',
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // SEARCH
  // ============================================================

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
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        decoration: InputDecoration(
          hintText:
              'Cari nama, NIP, jabatan, atau email...',
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: _biru,
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
                  icon: const Icon(
                    Icons.close_rounded,
                  ),
                ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  // ============================================================
  // STATISTIK
  // ============================================================

  Widget _buildStat(
    String label,
    int value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '$value',
                  style: TextStyle(
                    fontSize: AppTypography.section,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 2,
              style: TextStyle(
                fontSize: AppTypography.caption,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage(
    IconData icon,
    String title,
    String subtitle,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 44,
              color: _biru,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: AppTypography.section,
                fontWeight: FontWeight.bold,
                color: _biruTua,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // KARTU STAF
  // ============================================================

  Widget _buildStaffCard(
    String docId,
    Map<String, dynamic> staff,
    String status,
  ) {
    final nama = _str(
      staff['nama'],
      _str(staff['email'], 'Staf'),
    );

    final nip = _str(staff['nip'], '-');
    final jabatan = _str(staff['jabatan'], '-');
    final email = _str(staff['email_kontak'], '-');
    final wa = _phoneOf(staff);

    final tersedia =
        status.toLowerCase() == 'tersedia';

    final statusColor = tersedia
        ? Colors.green.shade700
        : Colors.orange.shade800;

    final foto = _decodeFoto(staff['foto_base64']);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              12,
              14,
              12,
              12,
            ),
            child: Column(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: _biru,
                      backgroundImage: foto,
                      child: foto == null
                          ? const Icon(
                              Icons.person_rounded,
                              color: Colors.white,
                              size: 34,
                            )
                          : null,
                    ),
                    Positioned(
                      right: 2,
                      bottom: 2,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: tersedia
                              ? Colors.green
                              : Colors.orange,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                Text(
                  nama,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: AppTypography.body,
                    color: _biruTua,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  jabatan,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: AppTypography.small,
                    color: Colors.grey.shade600,
                  ),
                ),

                const SizedBox(height: 10),

                _buildInfoRow(
                  Icons.badge_outlined,
                  nip,
                ),

                _buildInfoRow(
                  Icons.email_outlined,
                  email,
                ),

                _buildInfoRow(
                  Icons.phone_outlined,
                  wa.isEmpty ? 'Belum diisi' : wa,
                ),

                const Spacer(),

                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const StatusStaffPage(),
                      ),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius:
                          BorderRadius.circular(20),
                    ),
                    child: Text(
                      status,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: AppTypography.small,
                        color: statusColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Positioned(
            top: 2,
            right: 2,
            child: PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_vert_rounded,
              ),
              onSelected: (value) {
                if (value == 'edit') {
                  _showStaffModal(
                    staffDoc: {
                      'id': docId,
                      ...staff,
                    },
                  );
                } else if (value == 'hapus') {
                  _deleteStaff(docId, nama);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(
                        Icons.edit_rounded,
                        color: Colors.amber,
                      ),
                      SizedBox(width: 10),
                      Text('Edit'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'hapus',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_rounded,
                        color: Colors.redAccent,
                      ),
                      SizedBox(width: 10),
                      Text('Hapus'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 14,
            color: Colors.grey.shade500,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: AppTypography.small,
                color: Colors.grey.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DAFTAR STAF
  // ============================================================

  Widget _buildContent() {
    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream: _usersStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildMessage(
            Icons.error_outline_rounded,
            'Gagal memuat staf',
            '${snapshot.error}',
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        return StreamBuilder<
            QuerySnapshot<Map<String, dynamic>>>(
          stream: _assignmentsStream,
          builder: (context, assignmentSnapshot) {
            final assignments =
                assignmentSnapshot.data?.docs ?? [];

            final allStaff = snapshot.data!.docs.where(
              (doc) {
                final role = _str(
                  doc.data()['role'],
                  'staff',
                ).toLowerCase();

                return role != 'admin';
              },
            ).toList();

            final Map<String, String> statusById = {
              for (final doc in allStaff)
                doc.id: _countActive(
                          doc.id,
                          doc.data(),
                          assignments,
                        ) >=
                        _maksTugasAktif
                    ? 'Sibuk'
                    : 'Tersedia',
            };

            final total = allStaff.length;

            final tersedia = statusById.values
                .where((status) => status == 'Tersedia')
                .length;

            final query =
                _searchQuery.trim().toLowerCase();

            final filtered = allStaff.where((doc) {
              final data = doc.data();

              final nama =
                  _str(data['nama']).toLowerCase();

              final nip =
                  _str(data['nip']).toLowerCase();

              final jabatan =
                  _str(data['jabatan']).toLowerCase();

              final email = _str(
                data['email_kontak'],
              ).toLowerCase();

              return query.isEmpty ||
                  nama.contains(query) ||
                  nip.contains(query) ||
                  jabatan.contains(query) ||
                  email.contains(query);
            }).toList();

            filtered.sort((a, b) {
              final namaA =
                  _str(a.data()['nama']).toLowerCase();

              final namaB =
                  _str(b.data()['nama']).toLowerCase();

              return namaA.compareTo(namaB);
            });

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      16,
                      16,
                      12,
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _buildStat(
                              'Total Staf',
                              total,
                              Icons.groups_rounded,
                              _biru,
                            ),
                            const SizedBox(width: 10),
                            _buildStat(
                              'Tersedia',
                              tersedia,
                              Icons.check_circle_rounded,
                              Colors.green.shade700,
                            ),
                            const SizedBox(width: 10),
                            _buildStat(
                              'Sibuk',
                              total - tersedia,
                              Icons.timelapse_rounded,
                              Colors.orange.shade800,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildSearchBar(),
                      ],
                    ),
                  ),
                ),

                if (filtered.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildMessage(
                      query.isEmpty
                          ? Icons.group_off_rounded
                          : Icons.search_off_rounded,
                      query.isEmpty
                          ? 'Belum ada staf'
                          : 'Staf tidak ditemukan',
                      query.isEmpty
                          ? 'Tekan tombol Tambah Staff untuk menambahkan.'
                          : 'Coba kata kunci lain.',
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      4,
                      16,
                      96,
                    ),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 240,
                        mainAxisExtent: 276,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final doc = filtered[index];

                          return _buildStaffCard(
                            doc.id,
                            doc.data(),
                            statusById[doc.id] ??
                                'Tersedia',
                          );
                        },
                        childCount: filtered.length,
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================
  // HALAMAN UTAMA
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;

        return Scaffold(
          backgroundColor: _bg,
          drawer: wide
              ? null
              : const AdminSidebar(
                  currentIndex: 1,
                  isDrawer: true,
                ),
          body: Row(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              if (wide)
                const AdminSidebar(
                  currentIndex: 1,
                ),
              Expanded(
                child: Column(
                  children: [
                    AdminHeader(
                      title: 'Kelola Staff',
                      showSidebar: wide,
                    ),
                    Expanded(
                      child: _buildContent(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton:
              FloatingActionButton.extended(
            onPressed: () => _showStaffModal(),
            backgroundColor: _biru,
            icon: const Icon(
              Icons.person_add_alt_1_rounded,
              color: Colors.white,
            ),
            label: const Text(
              'Tambah Staff',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.endFloat,
        );
      },
    );
  }
}