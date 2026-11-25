import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'staff_admin_api.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _edgeUrl =
      'https://uxdloenucntsmcviskfo.supabase.co/functions/v1/staff-admin';
  static const String _supabaseAnonKey =
      'sb_publishable_wgHJYNJa0o7z5hNY7eNGKQ_T7z4gr5-';

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

    final passwordCandidates = <String>[password];

    // Gunakan email utama (NIP@simtas.internal) terlebih dahulu, lalu alias r1 bila ada.
    final aliasList = <String>['', 'r1'];
    FirebaseAuthException? firstAuthError;
    bool foundReplacedAuth = false;
    bool hitRateLimit = false;

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
            await StaffAdminApi.syncOwnPasswordIfNeeded(
              uid: uid,
              userData: data,
              password: pass,
              authEmail: authEmail,
            );
            final roleStr = (data['role'] ?? '').toString().toLowerCase();
            if (roleStr == 'admin' || roleStr == 'atasan') {
              unawaited(StaffAdminApi.syncKendalaCacheForAllTasks());
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
            final targetAdminUid = parts.length > 1 ? parts[1].trim() : '';

            // Baca data profil Admin selagi masih dalam sesi terautentikasi (`logged() == true`)
            Map<String, dynamic>? fallbackAdminData;
            if (targetAdminUid.isNotEmpty) {
              try {
                final tDoc = await _firestore
                    .collection('users')
                    .doc(targetAdminUid)
                    .get();
                if (tDoc.exists && tDoc.data() != null) {
                  fallbackAdminData = Map<String, dynamic>.from(tDoc.data()!);
                }
              } catch (_) {}
            }

            if (primaryAdminEmail.isNotEmpty) {
              try {
                await _auth.signOut();
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
              } on FirebaseAuthException catch (re) {
                // Jika email utama Admin terkena too-many-requests, masuk kembali lewat
                // akun jembatan ini dan gunakan profil Admin yang sudah dibaca!
                if (re.code == 'too-many-requests' &&
                    fallbackAdminData != null) {
                  await _auth.signInWithEmailAndPassword(
                    email: authEmail,
                    password: pass,
                  );
                  fallbackAdminData['role'] = 'admin';
                  return fallbackAdminData;
                }
              }
            } else if (fallbackAdminData != null) {
              fallbackAdminData['role'] = 'admin';
              return fallbackAdminData;
            }
          }

          // Jika bukan redirect langsung di displayName, cek di koleksi users
          // selagi sesi autentikasi masih terbuka.
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
                if ((role == 'admin' || role == 'atasan') &&
                    primaryEmail.isNotEmpty &&
                    primaryEmail.toLowerCase() != authEmail.toLowerCase()) {
                  final fallbackAdminData = Map<String, dynamic>.from(d);
                  try {
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
                  } on FirebaseAuthException catch (re) {
                    if (re.code == 'too-many-requests') {
                      await _auth.signInWithEmailAndPassword(
                        email: authEmail,
                        password: pass,
                      );
                      fallbackAdminData['role'] = 'admin';
                      return fallbackAdminData;
                    }
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
          if (e.code == 'user-disabled' || e.code == 'network-request-failed') {
            throw Exception(_handleAuthError(e.code));
          }
          if (e.code == 'too-many-requests') {
            hitRateLimit = true;
            // Jangan langsung melempar error di percobaan pertama!
            // Lanjutkan ke jalur pemulihan otomatis (recoverAndLoginLockedAdmin) di bawah.
            continue;
          }
          if (e.code == 'user-not-found') {
            break;
          }
        }
      }
    }

    // =========================================================================
    // JALUR PEMULIHAN OTOMATIS SAAT AKUN UTAMA TERKENA `too-many-requests`
    // =========================================================================
    if (hitRateLimit) {
      final recovered = await StaffAdminApi.recoverAndLoginLockedAdmin(
        nip: input,
        password: password,
      );
      if (recovered != null) {
        return recovered;
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

  /// Lupa password: kirim email terdaftar ke Edge Function untuk
  /// mengirimkan link reset password Firebase Authentication ke email tersebut.
  Future<String> forgotPassword({required String email}) async {
    try {
      final response = await http
          .post(
            Uri.parse(_edgeUrl),
            headers: {
              'Content-Type': 'application/json',
              'apikey': _supabaseAnonKey,
            },
            body: jsonEncode({
              'action': 'forgot-password',
              'email': email.trim(),
            }),
          )
          .timeout(const Duration(seconds: 30));

      Map<String, dynamic> data = {};
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) data = Map<String, dynamic>.from(decoded);
      } catch (_) {}

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StaffAdminException(
          (data['error'] ?? 'Gagal memproses permintaan lupa password.')
              .toString(),
          response.statusCode,
        );
      }

      final masked = (data['email_masked'] ?? '').toString();
      if (masked.isNotEmpty) {
        return 'Link reset password telah dikirimkan ke $masked. Silakan periksa kotak masuk (inbox) atau folder spam.';
      }
      return 'Link reset password telah dikirimkan ke email Anda. Silakan periksa kotak masuk (inbox) atau folder spam.';
    } on StaffAdminException catch (e) {
      throw Exception(e.message);
    } catch (_) {
      throw Exception(
        'Tidak dapat menghubungi layanan lupa password. Periksa koneksi internet.',
      );
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
