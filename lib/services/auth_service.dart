import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Domain email "bayangan" untuk akun yang dibuat atasan.
  // Harus sama dengan yang dipakai di Kelola Staff: "$nip@simtas.internal".
  static const String _nipDomain = '@simtas.internal';

  /// Mengubah isi kolom login menjadi email untuk Firebase Auth.
  String _toAuthEmail(String identifier) {
    final value = identifier.trim();

    // ===== [HAPUS NANTI] mulai: login pakai email asli =====
    // Jika diisi email (ada tanda @), pakai apa adanya.
    // Hapus blok ini kalau login sudah murni memakai NIP.
    if (value.contains('@')) {
      return value;
    }
    // ===== [HAPUS NANTI] selesai =====

    // Login dengan NIP -> NIP@simtas.internal
    return '$value$_nipDomain';
  }

  /// Memproses login via Firebase Auth dan mengambil role dari Firestore.
  /// Parameter [email] berisi NIP (atau email, selama masa transisi).
  Future<Map<String, dynamic>?> loginWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      // 1. Authenticate akun ke Firebase Auth
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _toAuthEmail(email),
        password: password,
      );

      String uid = userCredential.user!.uid;

      // 2. Ambil dokumen detail pengguna & role dari Cloud Firestore
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(uid)
          .get();

      if (userDoc.exists) {
        return userDoc.data() as Map<String, dynamic>;
      } else {
        await _auth.signOut();
        throw Exception('Data profil pengguna tidak ditemukan di Firestore.');
      }
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleAuthError(e.code));
    } catch (e) {
      rethrow;
    }
  }

  /// Keluar dari sesi Firebase Auth
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Pemetaan pesan kesalahan Firebase Auth
  String _handleAuthError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'NIP tidak terdaftar.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'NIP atau kata sandi salah.';
      case 'invalid-email':
        return 'Format NIP tidak valid.';
      case 'user-disabled':
        return 'Akun telah dinonaktifkan oleh Administrator.';
      case 'too-many-requests':
        return 'Terlalu banyak percobaan. Coba lagi beberapa saat lagi.';
      case 'network-request-failed':
        return 'Tidak ada koneksi internet.';
      default:
        return 'Terjadi kesalahan otentikasi. Silakan coba lagi.';
    }
  }
}
