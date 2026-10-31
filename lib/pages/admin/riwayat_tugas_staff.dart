import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/riwayat_penugasan_service.dart';
import '../../tugas/tugas_model.dart' show formatTanggalIndo;

import 'package:flutter/material.dart';

class RiwayatTugasStaffPage extends StatefulWidget {
  const RiwayatTugasStaffPage({super.key});

  @override
  State<RiwayatTugasStaffPage> createState() => _RiwayatTugasStaffPageState();
}

class _RiwayatTugasStaffPageState extends State<RiwayatTugasStaffPage> {
  static const Color biruTua = Color(0xFF0011CC);
  static const Color biru = Color(0xFF0066FF);
  static const Color cyan = Color(0xFF00CCFF);
  static const Color background = Color(0xFFF5F7FC);

  String pencarian = '';
  String filterStatus = 'Semua';

  List<Map<String, String>> riwayatTugas = [];
  StreamSubscription<List<Map<String, dynamic>>>? _subscription;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _subscription = streamRiwayatPenugasan().listen(
      (rows) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = null;
          riwayatTugas = rows.map((row) {
            final timestamp = row['tanggal_disetujui'] ?? row['updated_at'];
            final date = timestamp is Timestamp ? timestamp.toDate() : null;
            return <String, String>{
              'judul': (row['judul'] ?? '-').toString(),
              'staff': row['nama_staff'].toString(),
              'tanggal': date == null ? '-' : formatTanggalIndo(date),
              'status': 'Selesai',
              'deskripsi': (row['deskripsi'] ?? '-').toString(),
              'catatan_staff': (row['catatan_staff'] ?? '').toString(),
              'file_hasil_nama': (row['file_hasil_nama'] ?? '').toString(),
              'file_hasil_url': (row['file_hasil_url'] ?? '').toString(),
            };
          }).toList();
        });
      },
      onError: (Object error) {
        if (mounted)
          setState(() {
            _loading = false;
            _error = 'Gagal memuat riwayat: $error';
          });
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Color warnaStatus(String status) {
    switch (status) {
      case 'Selesai':
        return Colors.green;
      case 'Dikerjakan':
        return Colors.orange;
      default:
        return Colors.red;
    }
  }

  void tampilkanDetail(Map<String, String> tugas) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Detail Riwayat Tugas',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                      color: biruTua,
                    ),
                  ),
                  const SizedBox(height: 20),

                  detailItem('Nama Tugas', tugas['judul']!),
                  detailItem('Nama Staff', tugas['staff']!),
                  detailItem('Tanggal', tugas['tanggal']!),
                  detailItem('Status', tugas['status']!),
                  detailItem(
                    'Keterangan Hasil Pekerjaan',
                    tugas['catatan_staff'] ?? '-',
                  ),
                  if ((tugas['file_hasil_url'] ?? '').isNotEmpty)
                    TextButton.icon(
                      onPressed: () => launchUrl(
                        Uri.parse(tugas['file_hasil_url']!),
                        mode: LaunchMode.externalApplication,
                      ),
                      icon: const Icon(Icons.attach_file),
                      label: Text(
                        tugas['file_hasil_nama'] ?? 'File hasil pekerjaan',
                      ),
                    ),
                  detailItem('Deskripsi', tugas['deskripsi']!),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: biru,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(14),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Tutup'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget detailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 15)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasilFilter = riwayatTugas.where((tugas) {
      final cocokCari =
          tugas['judul']!.toLowerCase().contains(pencarian.toLowerCase()) ||
          tugas['staff']!.toLowerCase().contains(pencarian.toLowerCase());

      final cocokStatus =
          filterStatus == 'Semua' || tugas['status'] == filterStatus;

      return cocokCari && cocokStatus;
    }).toList();

    return Scaffold(
      backgroundColor: background,

      appBar: AppBar(
        title: const Text(
          'Riwayat Tugas Staff',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: biruTua,
      ),

      body: Column(
        children: [
          // =================================
          // HEADER PENCARIAN DAN FILTER
          // =================================
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [biruTua, biru]),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
            ),
            child: Column(
              children: [
                // Pencarian
                TextField(
                  onChanged: (value) {
                    setState(() {
                      pencarian = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Cari tugas atau nama staff...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Filter status
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: filterStatus,
                      isExpanded: true,
                      items: ['Semua', 'Selesai', 'Dikerjakan', 'Belum Selesai']
                          .map((status) {
                            return DropdownMenuItem(
                              value: status,
                              child: Text(status),
                            );
                          })
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            filterStatus = value;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // =================================
          // JUMLAH RIWAYAT
          // =================================
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
            child: Row(
              children: [
                const Icon(Icons.history, color: biru),
                const SizedBox(width: 8),
                Text(
                  'Daftar Riwayat (${hasilFilter.length})',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // =================================
          // LIST RIWAYAT TUGAS
          // =================================
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(child: Text(_error!))
                : hasilFilter.isEmpty
                ? const Center(
                    child: Text(
                      'Tidak ada riwayat tugas',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: hasilFilter.length,
                    itemBuilder: (context, index) {
                      final tugas = hasilFilter[index];
                      final status = tugas['status']!;

                      return Card(
                        color: Colors.white,
                        elevation: 3,
                        margin: const EdgeInsets.only(bottom: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => tampilkanDetail(tugas),

                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                // Ikon tugas
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: cyan.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.assignment_rounded,
                                    color: biru,
                                    size: 28,
                                  ),
                                ),

                                const SizedBox(width: 12),

                                // Informasi tugas
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tugas['judul']!,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        tugas['staff']!,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        tugas['tanggal']!,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(height: 8),

                                      // Badge status
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: warnaStatus(
                                            status,
                                          ).withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          status,
                                          style: TextStyle(
                                            color: warnaStatus(status),
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const Icon(
                                  Icons.chevron_right,
                                  color: Colors.grey,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
