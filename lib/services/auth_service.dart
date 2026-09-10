import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Memproses login via Firebase Auth dan mengambil role dari Firestore
  Future<Map<String, dynamic>?> loginWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      // 1. Authenticate akun ke Firebase Auth
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
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
        return 'Email tidak terdaftar.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Kata sandi yang Anda masukkan salah.';
      case 'invalid-email':
        return 'Format email tidak valid.';
      case 'user-disabled':
        return 'Akun telah dinonaktifkan oleh Administrator.';
      default:
        return 'Terjadi kesalahan otentikasi. Silakan coba lagi.';
    }
  }
}
