/// UID tetap menjadi relasi penugasan; nama digunakan untuk tampilan.
Map<String, dynamic> staffFromDocument(
  String documentId,
  Map<String, dynamic> data,
) {
  final uid = (data['uid'] ?? '').toString().trim();
  return {...data, 'id': uid.isEmpty ? documentId : uid};
}

bool isSelectableStaff(Map<String, dynamic> staff) {
  final role = (staff['role'] ?? '').toString().trim().toLowerCase();
  final status = (staff['status_akun'] ?? '').toString().trim().toLowerCase();
  return role == 'staff' && (status.isEmpty || status == 'aktif');
}

String staffDisplayName(Map<String, dynamic> staff) {
  final nama = (staff['nama'] ?? '').toString().trim();
  return nama.isEmpty ? 'Nama staf belum diisi' : nama;
}

bool matchesStaffSearch(Map<String, dynamic> staff, String query) {
  final normalized = query.trim().toLowerCase();
  return normalized.isEmpty ||
      ['nama', 'nip', 'email', 'jabatan'].any(
        (field) =>
            (staff[field] ?? '').toString().toLowerCase().contains(normalized),
      );
}
