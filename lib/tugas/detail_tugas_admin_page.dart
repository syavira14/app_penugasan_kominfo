import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'location_picker_page.dart';
import 'tugas_model.dart';

/// ============================================================
/// DETAIL TUGAS ADMIN (Tambah / Edit Tugas)
/// Sistem Penjadwalan Penugasan Pegawai — Dinas Kominfo
/// ============================================================
/// Form berisi:
///   - Judul Tugas
///   - Deskripsi Tugas
///   - Tempat Tugas (+ ambil lokasi GPS otomatis)
///   - Tanggal & Jam Penugasan
///   - Staf yang Bertugas (multi-pilih)
///   - Prioritas Tugas
///
/// CATATAN DEPENDENCY (tambahkan di pubspec.yaml):
///   dependencies:
///     geolocator: ^13.0.1
///
///   Android (android/app/src/main/AndroidManifest.xml), di dalam <manifest>:
///     <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
///     <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
///
///   iOS (ios/Runner/Info.plist), tambahkan:
///     <key>NSLocationWhenInUseUsageDescription</key>
///     <string>Aplikasi memerlukan lokasi untuk menandai tempat tugas</string>
/// ============================================================

class AppColors {
  static const Color biruTua = Color(0xFF0011CC);
  static const Color biruSedang = Color(0xFF0066FF);
  static const Color cyan = Color(0xFF00CCFF);
  static const Color putih = Colors.white;
  static const Color abuTeks = Color(0xFF5A6472);
  static const Color latarAbu = Color(0xFFF4F6FB);
  static const Color abuBorder = Color(0xFFE1E5F0);
}

/// Daftar staf contoh — ganti dengan data dari backend/API
const List<String> _daftarStafTersedia = [
  'Ahmad Fauzi',
  'Siti Nurhaliza',
  'Budi Santoso',
  'Dewi Lestari',
  'Rizky Pratama',
];

class DetailTugasAdminPage extends StatefulWidget {
  final TugasModel? tugas; // null = mode tambah, terisi = mode edit

  const DetailTugasAdminPage({super.key, this.tugas});

  @override
  State<DetailTugasAdminPage> createState() => _DetailTugasAdminPageState();
}

class _DetailTugasAdminPageState extends State<DetailTugasAdminPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _judulController;
  late final TextEditingController _deskripsiController;
  late final TextEditingController _tempatController;
  late final TextEditingController _staffSearchController;

  DateTime? _tanggalDipilih;
  TimeOfDay? _jamDipilih;
  double? _latitude;
  double? _longitude;
  bool _sedangMengambilLokasi = false;
  String _prioritas = 'Sedang';
  String _staffSearchQuery = '';
  final Set<String> _stafDipilih = {};

  bool get _modeEdit => widget.tugas != null;

  List<String> get _saranStaf {
    final query = _staffSearchQuery.trim().toLowerCase();
    if (query.isEmpty) return [];

    return _daftarStafTersedia.where((nama) {
      return !_stafDipilih.contains(nama) && nama.toLowerCase().contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    final tugas = widget.tugas;
    _judulController = TextEditingController(text: tugas?.judul ?? '');
    _deskripsiController = TextEditingController(text: tugas?.deskripsi ?? '');
    _tempatController = TextEditingController(text: tugas?.tempat ?? '');
    _staffSearchController = TextEditingController();
    _tanggalDipilih = tugas?.tanggal;
    _jamDipilih = tugas?.jam;
    _latitude = tugas?.latitude;
    _longitude = tugas?.longitude;
    _prioritas = tugas?.prioritas ?? 'Sedang';
    if (tugas != null) _stafDipilih.addAll(tugas.staff);
  }

  @override
  void dispose() {
    _judulController.dispose();
    _deskripsiController.dispose();
    _tempatController.dispose();
    _staffSearchController.dispose();
    super.dispose();
  }

  void _pilihStaf(String nama) {
    setState(() {
      _stafDipilih.add(nama);
      _staffSearchController.clear();
      _staffSearchQuery = '';
    });
  }

  void _hapusStaf(String nama) {
    setState(() => _stafDipilih.remove(nama));
  }

  // ---------- AMBIL LOKASI GPS SAAT INI ----------
  Future<void> _ambilLokasiSaatIni() async {
    setState(() => _sedangMengambilLokasi = true);
    try {
      bool layananAktif = await Geolocator.isLocationServiceEnabled();
      if (!layananAktif) {
        _tampilkanPesan(
          'Layanan lokasi (GPS) sedang nonaktif. Aktifkan terlebih dahulu.',
        );
        return;
      }

      LocationPermission izin = await Geolocator.checkPermission();
      if (izin == LocationPermission.denied) {
        izin = await Geolocator.requestPermission();
        if (izin == LocationPermission.denied) {
          _tampilkanPesan('Izin lokasi ditolak.');
          return;
        }
      }
      if (izin == LocationPermission.deniedForever) {
        _tampilkanPesan(
          'Izin lokasi ditolak permanen. Aktifkan lewat pengaturan aplikasi.',
        );
        return;
      }

      final posisi = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      setState(() {
        _latitude = posisi.latitude;
        _longitude = posisi.longitude;
        if (_tempatController.text.trim().isEmpty) {
          _tempatController.text =
              'Lat: ${posisi.latitude.toStringAsFixed(6)}, Lng: ${posisi.longitude.toStringAsFixed(6)}';
        }
      });
      _tampilkanPesan('Lokasi berhasil diambil');
    } catch (e) {
      _tampilkanPesan('Gagal mengambil lokasi. Coba lagi.');
    } finally {
      if (mounted) setState(() => _sedangMengambilLokasi = false);
    }
  }

  Future<void> _pilihLokasiDariPeta() async {
    final hasil = await Navigator.push<LocationPickResult>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerPage(
          initialTempat: _tempatController.text.trim(),
          initialLatitude: _latitude,
          initialLongitude: _longitude,
        ),
      ),
    );

    if (hasil == null) return;
    setState(() {
      _tempatController.text = hasil.tempat;
      _latitude = hasil.latitude;
      _longitude = hasil.longitude;
    });
  }

  void _tampilkanPesan(String pesan) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(pesan),
        backgroundColor: AppColors.biruTua,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _pilihTanggal() async {
    final hasil = await showDatePicker(
      context: context,
      initialDate: _tanggalDipilih ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.biruTua),
        ),
        child: child!,
      ),
    );
    if (hasil != null) setState(() => _tanggalDipilih = hasil);
  }

  Future<void> _pilihJam() async {
    final hasil = await showTimePicker(
      context: context,
      initialTime: _jamDipilih ?? TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.biruTua),
        ),
        child: child!,
      ),
    );
    if (hasil != null) setState(() => _jamDipilih = hasil);
  }

  void _simpanTugas() {
    if (!_formKey.currentState!.validate()) return;

    if (_tanggalDipilih == null) {
      _tampilkanPesan('Tanggal penugasan wajib dipilih');
      return;
    }
    if (_jamDipilih == null) {
      _tampilkanPesan('Jam penugasan wajib dipilih');
      return;
    }
    if (_stafDipilih.isEmpty) {
      _tampilkanPesan('Pilih minimal 1 staf yang bertugas');
      return;
    }

    final tugasBaru = TugasModel(
      id: widget.tugas?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      judul: _judulController.text.trim(),
      deskripsi: _deskripsiController.text.trim(),
      tempat: _tempatController.text.trim(),
      latitude: _latitude,
      longitude: _longitude,
      tanggal: _tanggalDipilih!,
      jam: _jamDipilih!,
      staff: _stafDipilih.toList(),
      prioritas: _prioritas,
      selesai: widget.tugas?.selesai ?? false,
    );

    Navigator.pop(context, tugasBaru);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.latarAbu,
      appBar: AppBar(
        backgroundColor: AppColors.biruTua,
        elevation: 0,
        title: Text(
          _modeEdit ? 'Edit Tugas' : 'Tambah Tugas',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ---------- JUDUL TUGAS ----------
            _LabelForm(label: 'Judul Tugas'),
            TextFormField(
              controller: _judulController,
              decoration: _dekorasi(
                hint: 'Contoh: Pemeliharaan Server Data Center',
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Judul tugas wajib diisi'
                  : null,
            ),
            const SizedBox(height: 18),

            // ---------- DESKRIPSI TUGAS ----------
            _LabelForm(label: 'Deskripsi Tugas'),
            TextFormField(
              controller: _deskripsiController,
              maxLines: 4,
              decoration: _dekorasi(
                hint: 'Jelaskan rincian pekerjaan yang perlu dilakukan...',
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Deskripsi tugas wajib diisi'
                  : null,
            ),
            const SizedBox(height: 18),

            // ---------- TEMPAT TUGAS + GPS ----------
            _LabelForm(label: 'Tempat Tugas'),
            TextFormField(
              controller: _tempatController,
              decoration: _dekorasi(hint: 'Contoh: Kantor Dinas Kominfo Lt. 2')
                  .copyWith(
                    suffixIcon: _sedangMengambilLokasi
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.biruSedang,
                              ),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(
                              Icons.my_location_rounded,
                              color: AppColors.biruSedang,
                              size: 20,
                            ),
                            tooltip: 'Ambil lokasi saat ini',
                            onPressed: _ambilLokasiSaatIni,
                          ),
                  ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Tempat tugas wajib diisi'
                  : null,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pilihLokasiDariPeta,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.biruTua,
                      side: const BorderSide(color: AppColors.abuBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: const Text(
                      'Pilih dari Peta',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _sedangMengambilLokasi
                        ? null
                        : _ambilLokasiSaatIni,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.biruSedang,
                      side: const BorderSide(color: AppColors.abuBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.my_location_rounded, size: 18),
                    label: const Text(
                      'Lokasi Saat Ini',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_latitude != null && _longitude != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.place_rounded,
                    size: 14,
                    color: AppColors.biruSedang,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Koordinat: ${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}',
                    style: const TextStyle(
                      color: AppColors.abuTeks,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 18),

            // ---------- TANGGAL & JAM ----------
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LabelForm(label: 'Tanggal Penugasan'),
                      _PemilihWaktu(
                        icon: Icons.calendar_today_rounded,
                        teks: _tanggalDipilih == null
                            ? 'Pilih tanggal'
                            : formatTanggalIndo(_tanggalDipilih!),
                        onTap: _pilihTanggal,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LabelForm(label: 'Jam Penugasan'),
                      _PemilihWaktu(
                        icon: Icons.access_time_rounded,
                        teks: _jamDipilih == null
                            ? 'Pilih jam'
                            : formatJam(_jamDipilih!),
                        onTap: _pilihJam,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // ---------- STAF YANG BERTUGAS ----------
            _LabelForm(label: 'Staf yang Bertugas'),
            TextField(
              controller: _staffSearchController,
              onChanged: (value) => setState(() => _staffSearchQuery = value),
              decoration: _dekorasi(hint: 'Ketik nama staf, contoh: Ahmad')
                  .copyWith(
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.biruSedang,
                      size: 20,
                    ),
                    suffixIcon: _staffSearchQuery.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              color: AppColors.abuTeks,
                              size: 18,
                            ),
                            onPressed: () {
                              _staffSearchController.clear();
                              setState(() => _staffSearchQuery = '');
                            },
                          ),
                  ),
            ),
            if (_saranStaf.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.putih,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.abuBorder),
                ),
                child: Column(
                  children: _saranStaf.map((nama) {
                    final isLast = nama == _saranStaf.last;
                    return Column(
                      children: [
                        ListTile(
                          dense: true,
                          leading: const CircleAvatar(
                            radius: 16,
                            backgroundColor: Color(0x1A0066FF),
                            child: Icon(
                              Icons.person_outline_rounded,
                              color: AppColors.biruSedang,
                              size: 17,
                            ),
                          ),
                          title: Text(
                            nama,
                            style: const TextStyle(
                              color: AppColors.biruTua,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.add_circle_outline_rounded,
                            color: AppColors.biruSedang,
                            size: 20,
                          ),
                          onTap: () => _pilihStaf(nama),
                        ),
                        if (!isLast)
                          const Divider(
                            height: 1,
                            indent: 56,
                            color: AppColors.abuBorder,
                          ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ] else if (_staffSearchQuery.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.putih,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.abuBorder),
                ),
                child: const Text(
                  'Nama staf tidak ditemukan',
                  style: TextStyle(color: AppColors.abuTeks, fontSize: 12.5),
                ),
              ),
            ],
            if (_stafDipilih.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _stafDipilih.map((nama) {
                  return Chip(
                    label: Text(
                      nama,
                      style: const TextStyle(
                        color: AppColors.biruTua,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    avatar: const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.biruSedang,
                      size: 17,
                    ),
                    deleteIcon: const Icon(Icons.close_rounded, size: 16),
                    onDeleted: () => _hapusStaf(nama),
                    backgroundColor: AppColors.cyan.withOpacity(0.12),
                    side: BorderSide(color: AppColors.cyan.withOpacity(0.35)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  );
                }).toList(),
              ),
            ],
            if (_stafDipilih.isEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Pilih minimal 1 staf yang bertugas.',
                style: TextStyle(color: AppColors.abuTeks, fontSize: 11.5),
              ),
            ],
            const SizedBox(height: 18),

            // ---------- PRIORITAS ----------
            _LabelForm(label: 'Prioritas Tugas'),
            Row(
              children: ['Rendah', 'Sedang', 'Tinggi'].map((p) {
                final dipilih = _prioritas == p;
                final Color warna = switch (p) {
                  'Tinggi' => const Color(0xFFFF9800),
                  'Rendah' => AppColors.cyan,
                  _ => AppColors.biruSedang,
                };
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => setState(() => _prioritas = p),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: dipilih
                            ? warna.withOpacity(0.15)
                            : AppColors.putih,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: dipilih ? warna : AppColors.abuBorder,
                        ),
                      ),
                      child: Text(
                        p,
                        style: TextStyle(
                          color: dipilih ? warna : AppColors.abuTeks,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),

            // ---------- TOMBOL SIMPAN & BATAL ----------
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _simpanTugas,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.biruTua,
                  foregroundColor: AppColors.putih,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  _modeEdit ? 'Simpan Perubahan' : 'Simpan Tugas',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.abuTeks,
                  side: const BorderSide(color: AppColors.abuBorder),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Batal',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _dekorasi({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.abuTeks, fontSize: 13),
      filled: true,
      fillColor: AppColors.putih,
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.abuBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.abuBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.biruSedang, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }
}

class _LabelForm extends StatelessWidget {
  final String label;
  const _LabelForm({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.biruTua,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PemilihWaktu extends StatelessWidget {
  final IconData icon;
  final String teks;
  final VoidCallback onTap;

  const _PemilihWaktu({
    required this.icon,
    required this.teks,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.putih,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.abuBorder),
        ),
        child: Row(
          children: [
            Icon(icon, size: 17, color: AppColors.biruSedang),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                teks,
                style: const TextStyle(
                  color: AppColors.abuTeks,
                  fontSize: 12.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
