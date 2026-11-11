import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'staff_admin_api.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Memproses login via Firebase Auth menggunakan NIP dan mengambil role dari Firestore.
  /// Input berupa alamat email (seperti @gmail.com) ditolak secara tegas.
  Future<Map<String, dynamic>?> loginWithEmail({
    required String email,
    required String password,
  }) async {
    final input = email.trim();

    // Tolak login menggunakan email (@gmail.com, dll.) — wajib menggunakan NIP (angka).
    if (input.contains('@') || !RegExp(r'^[0-9]+$').hasMatch(input)) {
      throw Exception(
        'Masuk hanya dapat menggunakan NIP (angka), bukan alamat email.',
      );
    }

    // Coba password apa adanya terlebih dahulu, lalu versi trim() jika ada spasi tak sengaja.
    final passwordCandidates = <String>[
      password,
      if (password.trim() != password && password.trim().isNotEmpty)
        password.trim(),
    ];

    // Login menggunakan NIP:
    // Coba email utama (NIP@simtas.internal), lalu alias hasil reset/mutasi (NIP.r1@simtas.internal, dst.)
    final aliasList = <String>[
      '',
      'r1',
      'r2',
      'r3',
      'r4',
      'r5',
      'r6',
      'r7',
      'r8',
      'r9',
    ];
    FirebaseAuthException? firstAuthError;
    bool foundReplacedAuth = false;

    for (int i = 0; i < aliasList.length; i++) {
      final tag = aliasList[i];
      final authEmail = StaffAdminApi.authEmailForNip(input, tag);

      for (final pass in passwordCandidates) {
        try {
          final userCredential = await _auth.signInWithEmailAndPassword(
            email: authEmail,
            password: pass,
          );
          final loggedInUser = userCredential.user!;
          final uid = loggedInUser.uid;
          final userDoc = await _firestore.collection('users').doc(uid).get();

          if (userDoc.exists) {
            final data = Map<String, dynamic>.from(
              userDoc.data() as Map<String, dynamic>,
            );
            // Sinkron di latar belakang agar login tidak menunggu tulis Firestore.
            unawaited(
              StaffAdminApi.syncOwnPasswordIfNeeded(
                uid: uid,
                userData: data,
                password: pass,
                authEmail: authEmail,
              ),
            );
            if ((data['role'] ?? '').toString().toLowerCase() == 'admin') {
              // Ditunda supaya tidak berebut jaringan dengan dashboard.
              unawaited(
                Future<void>.delayed(
                  const Duration(seconds: 15),
                  () => StaffAdminApi.syncKendalaCacheForAllTasks(),
                ),
              );
            }
            return data;
          }

          // Cek apakah akun Auth ini adalah jembatan redirect mutasi NIP Admin:
          final displayName = (loggedInUser.displayName ?? '').trim();
          if (displayName.startsWith(StaffAdminApi.adminRedirectPrefix)) {
            final rest = displayName.substring(
              StaffAdminApi.adminRedirectPrefix.length,
            );
            final parts = rest.split('::');
            final primaryAdminEmail = parts.first.trim();
            await _auth.signOut();
            if (primaryAdminEmail.isNotEmpty) {
              final adminCred = await _auth.signInWithEmailAndPassword(
                email: primaryAdminEmail,
                password: pass,
              );
              final adminUid = adminCred.user!.uid;
              final adminDoc = await _firestore
                  .collection('users')
                  .doc(adminUid)
                  .get();
              if (adminDoc.exists) {
                final adminData = Map<String, dynamic>.from(
                  adminDoc.data() as Map<String, dynamic>,
                );
                await StaffAdminApi.syncOwnPasswordIfNeeded(
                  uid: adminUid,
                  userData: adminData,
                  password: pass,
                  authEmail: primaryAdminEmail,
                );
                unawaited(StaffAdminApi.syncKendalaCacheForAllTasks());
                return adminData;
              }
            }
          }

          // Jika bukan redirect langsung di displayName, cek di koleksi users
          // selagi sesi autentikasi masih terbuka (apakah NIP ini milik Admin
          // yang dimutasi atau Staf yang direset ke alias baru).
          foundReplacedAuth = true;
          try {
            final allUsers = await _firestore.collection('users').get();
            for (final doc in allUsers.docs) {
              final d = doc.data();
              final effNip = StaffAdminApi.effectiveNipFromData(d);
              if (effNip == input) {
                final role = (d['role'] ?? '').toString().toLowerCase();
                final primaryEmail = (d['email'] ?? '').toString().trim();
                final activeAlias = StaffAdminApi.extractStoredAliasTag(
                  d['email_kontak'],
                );
                if (role == 'admin' &&
                    primaryEmail.isNotEmpty &&
                    primaryEmail.toLowerCase() != authEmail.toLowerCase()) {
                  await _auth.signOut();
                  final adminCred = await _auth.signInWithEmailAndPassword(
                    email: primaryEmail,
                    password: pass,
                  );
                  final adminUid = adminCred.user!.uid;
                  final adminDoc = await _firestore
                      .collection('users')
                      .doc(adminUid)
                      .get();
                  if (adminDoc.exists) {
                    final adminData = Map<String, dynamic>.from(
                      adminDoc.data() as Map<String, dynamic>,
                    );
                    await StaffAdminApi.syncOwnPasswordIfNeeded(
                      uid: adminUid,
                      userData: adminData,
                      password: pass,
                      authEmail: primaryEmail,
                    );
                    unawaited(StaffAdminApi.syncKendalaCacheForAllTasks());
                    return adminData;
                  }
                }
                if (activeAlias.isNotEmpty &&
                    !aliasList.contains(activeAlias)) {
                  aliasList.add(activeAlias);
                }
                break;
              }
            }
          } catch (_) {}
          await _auth.signOut();
        } on FirebaseAuthException catch (e) {
          firstAuthError ??= e;
          if (e.code == 'user-disabled' ||
              e.code == 'too-many-requests' ||
              e.code == 'network-request-failed') {
            throw Exception(_handleAuthError(e.code));
          }
          if (e.code == 'user-not-found') {
            break;
          }
        }
      }
    }

    if (foundReplacedAuth) {
      throw Exception(
        'Password akun ini telah direset oleh Atasan/Admin. Silakan login menggunakan NIP sebagai kata sandi.',
      );
    }

    if (firstAuthError != null) {
      if (firstAuthError.code == 'invalid-credential' ||
          firstAuthError.code == 'user-not-found' ||
          firstAuthError.code == 'wrong-password') {
        throw Exception(await _pesanLoginNip(input));
      }
      throw Exception(_handleAuthError(firstAuthError.code));
    }

    throw Exception('NIP atau kata sandi salah.');
  }

  /// Menentukan pesan yang tepat setelah login NIP gagal.
  Future<String> _pesanLoginNip(String nip) async {
    try {
      final r = await StaffAdminApi.checkNip(nip);
      if (r['exists'] == false) return 'NIP tidak terdaftar.';
      if (r['legacy'] == true) {
        return 'Akun ini belum diaktifkan untuk masuk dengan NIP. '
            'Minta admin menekan "Reset password" di Kelola Staff.';
      }
      return 'Kata sandi salah.';
    } catch (_) {
      return 'NIP atau kata sandi salah.';
    }
  }

  /// Keluar dari sesi Firebase Auth
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Pemetaan pesan kesalahan Firebase Auth.
  String _handleAuthError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'NIP tidak terdaftar.';
      case 'wrong-password':
        return 'Kata sandi salah.';
      case 'invalid-credential':
        return 'Kata sandi salah.';
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
