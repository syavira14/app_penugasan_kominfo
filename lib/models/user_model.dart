class UserModel {
  final String uid;
  final String email;
  final String nama;
  final String role; // 'admin' atau 'staff'

  UserModel({
    required this.uid,
    required this.email,
    required this.nama,
    required this.role,
  });

  // Mengubah data Map Firestore ke Object UserModel
  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      email: map['email'] ?? '',
      nama: map['nama'] ?? '',
      role: map['role'] ?? 'staff',
    );
  }

  // Mengubah Object UserModel ke Map untuk disimpan ke Firestore
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'nama': nama,
      'role': role,
      'createdAt': DateTime.now(),
    };
  }
}
