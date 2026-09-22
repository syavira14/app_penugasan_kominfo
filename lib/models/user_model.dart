import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String nip;
  final String nama;
  final String email;
  final String noHp;
  final String jabatan;
  final String role;
  final String statusPekerjaan;

  // Foto disimpan langsung di Firestore dalam bentuk Base64
  final String fotoBase64;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserModel({
    required this.uid,
    required this.nip,
    required this.nama,
    required this.email,
    required this.noHp,
    required this.jabatan,
    required this.role,
    required this.statusPekerjaan,
    required this.fotoBase64,
    this.createdAt,
    this.updatedAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, {String uid = ''}) {
    return UserModel(
      uid: map['uid'] ?? uid,
      nip: map['nip'] ?? '',
      nama: map['nama'] ?? map['nama_lengkap'] ?? '',
      email: map['email'] ?? map['email_user'] ?? '',
      noHp: map['no_hp'] ?? map['no_hp'] ?? '',
      jabatan: map['jabatan'] ?? '',
      role: map['role'] ?? 'Staff',
      statusPekerjaan: map['status_pekerjaan'] ?? 'tersedia',

      // Foto baru
      fotoBase64: map['foto_base64'] ?? '',

      createdAt: map['created_at'] != null && map['created_at'] is Timestamp
          ? (map['created_at'] as Timestamp).toDate()
          : null,

      updatedAt: map['updated_at'] != null && map['updated_at'] is Timestamp
          ? (map['updated_at'] as Timestamp).toDate()
          : null,
    );
  }

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>? ?? {};

    return UserModel.fromMap(map, uid: doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'nip': nip,
      'nama': nama,
      'email': email,
      'no_hp': noHp,
      'jabatan': jabatan,
      'role': role,
      'status_pekerjaan': statusPekerjaan,

      // Simpan foto sebagai Base64
      'foto_base64': fotoBase64,

      'updated_at': FieldValue.serverTimestamp(),
    };
  }
}
