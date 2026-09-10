import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class LocationPickResult {
  final String tempat;
  final double latitude;
  final double longitude;

  const LocationPickResult({
    required this.tempat,
    required this.latitude,
    required this.longitude,
  });
}

class _PlaceSearchResult {
  final String label;
  final double latitude;
  final double longitude;

  const _PlaceSearchResult({
    required this.label,
    required this.latitude,
    required this.longitude,
  });
}

class LocationPickerPage extends StatefulWidget {
  final String initialTempat;
  final double? initialLatitude;
  final double? initialLongitude;

  const LocationPickerPage({
    super.key,
    this.initialTempat = '',
    this.initialLatitude,
    this.initialLongitude,
  });

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  static const Color biruTua = Color(0xFF0011CC);
  static const Color biruSedang = Color(0xFF0066FF);
  static const Color putih = Colors.white;
  static const Color abuTeks = Color(0xFF5A6472);
  static const Color abuBorder = Color(0xFFE1E5F0);

  late final TextEditingController _tempatController;
  late final TextEditingController _searchController;
  late final MapController _mapController;
  late LatLng _selectedPoint;
  bool _sedangMencariTempat = false;
  List<_PlaceSearchResult> _hasilPencarian = [];

  @override
  void initState() {
    super.initState();
    _tempatController = TextEditingController(text: widget.initialTempat);
    _searchController = TextEditingController(text: widget.initialTempat);
    _mapController = MapController();

    final validLat = widget.initialLatitude != null && widget.initialLatitude!.isFinite
        ? widget.initialLatitude!
        : -0.494823;
    final validLng = widget.initialLongitude != null && widget.initialLongitude!.isFinite
        ? widget.initialLongitude!
        : 117.143615;

    _selectedPoint = LatLng(validLat, validLng);
  }

  @override
  void dispose() {
    _tempatController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cariTempat() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() => _hasilPencarian = []);
      return;
    }

    setState(() => _sedangMencariTempat = true);

    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?'
        'format=jsonv2&limit=5&q=${Uri.encodeQueryComponent(query)}',
      );

      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'app_penugasan_kominfo/1.0',
          'Accept-Language': 'id',
        },
      );

      if (!mounted) return;

      if (response.statusCode != 200) {
        setState(() => _hasilPencarian = []);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal mencari lokasi. Coba kata kunci lain.'),
            backgroundColor: biruTua,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List) {
        setState(() => _hasilPencarian = []);
        return;
      }

      final results = decoded;
      setState(() {
        _hasilPencarian = results
            .whereType<Map<String, dynamic>>()
            .map((item) {
              final rawLatitude = item['lat'];
              final rawLongitude = item['lon'];
              final latitude = double.tryParse(rawLatitude?.toString() ?? '') ?? 0.0;
              final longitude = double.tryParse(rawLongitude?.toString() ?? '') ?? 0.0;

              return _PlaceSearchResult(
                label: (item['display_name'] ?? 'Lokasi').toString(),
                latitude: latitude,
                longitude: longitude,
              );
            })
            .where((item) => item.latitude != 0.0 || item.longitude != 0.0)
            .toList();
      });

      if (_hasilPencarian.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lokasi tidak ditemukan. Coba kata kunci lain.'),
            backgroundColor: biruTua,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _hasilPencarian = []);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Koneksi gagal saat mencari lokasi.'),
          backgroundColor: biruTua,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _sedangMencariTempat = false);
      }
    }
  }

  void _pilihHasilPencarian(_PlaceSearchResult result) {
    final point = LatLng(result.latitude, result.longitude);
    setState(() {
      _selectedPoint = point;
      _tempatController.text = result.label;
      _searchController.text = result.label;
      _hasilPencarian = [];
    });
    _mapController.move(point, 15);
  }

  void _simpanLokasi() {
    final tempat = _tempatController.text.trim();
    if (tempat.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Nama tempat wajib diisi'),
          backgroundColor: biruTua,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    Navigator.pop(
      context,
      LocationPickResult(
        tempat: tempat,
        latitude: _selectedPoint.latitude,
        longitude: _selectedPoint.longitude,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        backgroundColor: biruTua,
        foregroundColor: putih,
        title: const Text(
          'Pilih Lokasi Tugas',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            color: putih,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Cari lokasi...',
                          hintStyle: const TextStyle(color: abuTeks, fontSize: 13),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: biruSedang,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFE),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: abuBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: abuBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: biruSedang,
                              width: 1.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        ),
                        onSubmitted: (_) => _cariTempat(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _sedangMencariTempat ? null : _cariTempat,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: biruTua,
                          foregroundColor: putih,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _sedangMencariTempat
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: putih,
                                ),
                              )
                            : const Text('Cari'),
                      ),
                    ),
                  ],
                ),
                if (_hasilPencarian.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFE),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: abuBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _hasilPencarian.map((item) {
                        return ListTile(
                          dense: true,
                          leading: const Icon(
                            Icons.location_on_outlined,
                            color: biruSedang,
                            size: 18,
                          ),
                          title: Text(
                            item.label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: biruTua,
                            ),
                          ),
                          onTap: () => _pilihHasilPencarian(item),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _selectedPoint,
                initialZoom: 15,
                onTap: (_, point) => setState(() => _selectedPoint = point),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.app_penugasan_kominfo',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedPoint,
                      width: 54,
                      height: 54,
                      child: const Icon(
                        Icons.location_pin,
                        color: Colors.redAccent,
                        size: 46,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            decoration: BoxDecoration(
              color: putih,
              boxShadow: [
                BoxShadow(
                  color: biruTua.withOpacity(0.08),
                  blurRadius: 14,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Nama Tempat',
                    style: TextStyle(
                      color: biruTua,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _tempatController,
                    decoration: InputDecoration(
                      hintText: 'Contoh: Kantor Kecamatan Samarinda Ulu',
                      prefixIcon: const Icon(
                        Icons.place_outlined,
                        color: biruSedang,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFE),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: abuBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: abuBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: biruSedang,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Koordinat: ${_selectedPoint.latitude.toStringAsFixed(6)}, ${_selectedPoint.longitude.toStringAsFixed(6)}',
                    style: const TextStyle(color: abuTeks, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _simpanLokasi,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: biruTua,
                        foregroundColor: putih,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text(
                        'Gunakan Lokasi Ini',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
