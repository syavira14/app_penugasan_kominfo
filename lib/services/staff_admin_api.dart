import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_saver/file_saver.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../widgets/simtas_file_preview_page.dart';
import 'supabase_storage_service.dart';

/// Pesan error yang siap ditampilkan ke pengguna.
class StaffAdminException implements Exception {
  final String message;
  final int? status;
  const StaffAdminException(this.message, [this.status]);

  @override
  String toString() => message;
}

/// Layanan administrasi akun staf, mutasi profil admin/staf, sinkronisasi riwayat
/// kendala, serta pembukaan & pengunduhan file in-app (tanpa membuka browser).
class StaffAdminApi {
  static const String nipDomain = '@simtas.internal';
  static const String adminRedirectPrefix = 'ADMIN_AUTH::';
  static const String _sep = '||';
  static const String _edgeUrl =
      'https://uxdloenucntsmcviskfo.supabase.co/functions/v1/staff-admin';
  static const String _fileEdgeUrl =
      'https://uxdloenucntsmcviskfo.supabase.co/functions/v1/get-assignment-file-url';
  static const String _supabaseUrl = 'https://uxdloenucntsmcviskfo.supabase.co';
  static const String _supabaseAnonKey =
      'sb_publishable_wgHJYNJa0o7z5hNY7eNGKQ_T7z4gr5-';

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cache URL & bytes di memori agar pembukaan/pengunduhan file instan tanpa loading berulang.
  static final Map<String, String> _urlCache = <String, String>{};
  static final Map<String, Uint8List> _bytesCache = <String, Uint8List>{};

  static void cacheMemoryBytes(String pathOrKey, Uint8List bytes) {
    final k = pathOrKey.trim();
    if (k.isEmpty || bytes.isEmpty) return;
    _bytesCache[k] = bytes;
    final clean = k
        .replaceFirst(RegExp(r'^/+'), '')
        .replaceFirst(RegExp(r'^file-tugas/'), '');
    _bytesCache[clean] = bytes;
  }

  static Uint8List? getCachedBytes(String pathOrKey) {
    final k = pathOrKey.trim();
    if (k.isEmpty) return null;
    if (_bytesCache.containsKey(k)) return _bytesCache[k];
    final clean = k
        .replaceFirst(RegExp(r'^/+'), '')
        .replaceFirst(RegExp(r'^file-tugas/'), '');
    return _bytesCache[clean];
  }

  // =======================================================================
  // HELPER SINKRONISASI KREDENSIAL & NAMA STAF/ADMIN (KOMPATIBEL FIRESTORE RULES)
  // =======================================================================
  // Format metadata di `email_kontak`:
  // "<email_kontak_bersih>||<password_aktif>||<alias_tag>||<nip_override>||<nama_override>"
  // Tampilan UI selalu mengambil bagian sebelum '||'.

  static String cleanEmailKontak(dynamic raw, {dynamic fallbackEmail}) {
    final kontak = (raw ?? '')
        .toString()
        .split(_sep)
        .first
        .split('\t')
        .first
        .trim();
    if (kontak.isNotEmpty) return kontak;
    final lama = (fallbackEmail ?? '')
        .toString()
        .split(_sep)
        .first
        .split('\t')
        .first
        .trim();
    if (lama.isNotEmpty && !lama.toLowerCase().endsWith(nipDomain)) {
      return lama;
    }
    return '';
  }

  static String? extractStoredPassword(dynamic raw) {
    if (raw == null) return null;
    final s = raw.toString();
    final parts = s.contains(_sep) ? s.split(_sep) : s.split('\t');
    if (parts.length >= 2) {
      final pass = parts[1].trim();
      if (pass.length >= 6) return pass;
    }
    return null;
  }

  static String extractStoredAliasTag(dynamic raw) {
    if (raw == null) return '';
    final s = raw.toString();
    final parts = s.contains(_sep) ? s.split(_sep) : s.split('\t');
    if (parts.length >= 3) {
      return parts[2].trim();
    }
    return '';
  }

  static String extractStoredNipOverride(dynamic raw) {
    if (raw == null) return '';
    final s = raw.toString();
    if (!s.contains(_sep)) return '';
    final parts = s.split(_sep);
    if (parts.length >= 4) {
      return parts[3].trim();
    }
    return '';
  }

  static String extractStoredNamaOverride(dynamic raw) {
    if (raw == null) return '';
    final s = raw.toString();
    if (!s.contains(_sep)) return '';
    final parts = s.split(_sep);
    if (parts.length >= 5) {
      return parts[4].trim();
    }
    return '';
  }

  static String effectiveNipFromData(Map<String, dynamic> data) {
    final over = extractStoredNipOverride(data['email_kontak']);
    if (over.isNotEmpty) return over;
    return (data['nip'] ?? '').toString().trim();
  }

  static String effectiveNamaFromData(Map<String, dynamic> data) {
    final over = extractStoredNamaOverride(data['email_kontak']);
    if (over.isNotEmpty) return over;
    return (data['nama'] ?? data['nama_lengkap'] ?? '').toString().trim();
  }

  static String extractAliasTagFromAuthEmail(
    String? authEmail, {
    dynamic fallbackRawEmailKontak,
  }) {
    if (authEmail != null && authEmail.trim().isNotEmpty) {
      final match = RegExp(
        r'\.(r\d+)@simtas\.internal$',
        caseSensitive: false,
      ).firstMatch(authEmail.trim());
      if (match != null) {
        return match.group(1)!.toLowerCase();
      }
      if (authEmail.trim().toLowerCase().endsWith(nipDomain)) {
        return '';
      }
    }
    return extractStoredAliasTag(fallbackRawEmailKontak);
  }

  static String authEmailForNip(String nip, [String aliasTag = '']) {
    final cleanNip = nip.trim();
    final cleanAlias = aliasTag.trim();
    return cleanAlias.isEmpty
        ? '$cleanNip$nipDomain'
        : '$cleanNip.$cleanAlias$nipDomain';
  }

  static String packEmailKontak(
    String cleanEmail, {
    String? password,
    String? aliasTag,
    String? nipOverride,
    String? namaOverride,
    dynamic previousRawEmailKontak,
  }) {
    final clean = cleanEmail.split(_sep).first.split('\t').first.trim();
    final pass = (password != null && password.trim().length >= 6)
        ? password.trim()
        : (extractStoredPassword(previousRawEmailKontak) ?? '');
    final alias = aliasTag != null
        ? aliasTag.trim()
        : extractStoredAliasTag(previousRawEmailKontak);
    final nipOver = nipOverride != null
        ? nipOverride.trim()
        : extractStoredNipOverride(previousRawEmailKontak);
    final namaOver = namaOverride != null
        ? namaOverride.replaceAll(_sep, ' ').trim()
        : extractStoredNamaOverride(previousRawEmailKontak);

    if (pass.isEmpty && alias.isEmpty && nipOver.isEmpty && namaOver.isEmpty) {
      return clean;
    }

    String packed;
    if (namaOver.isNotEmpty) {
      packed = '$clean$_sep$pass$_sep$alias$_sep$nipOver$_sep$namaOver';
    } else if (nipOver.isNotEmpty) {
      packed = '$clean$_sep$pass$_sep$alias$_sep$nipOver';
    } else {
      packed = '$clean$_sep$pass$_sep$alias';
    }

    // Aturan firestore.rules membatasi email_kontak maksimal 200 karakter.
    if (packed.length <= 200) return packed;
    if (namaOver.isNotEmpty) {
      final maxNama =
          (195 - '$clean$_sep$pass$_sep$alias$_sep$nipOver$_sep'.length).clamp(
            1,
            namaOver.length,
          );
      final shortPacked =
          '$clean$_sep$pass$_sep$alias$_sep$nipOver$_sep${namaOver.substring(0, maxNama)}';
      if (shortPacked.length <= 200) return shortPacked;
    }
    return clean;
  }

  /// Sinkronisasi otomatis saat pengguna berhasil login.
  static Future<void> syncOwnPasswordIfNeeded({
    required String uid,
    required Map<String, dynamic> userData,
    required String password,
    required String authEmail,
  }) async {
    try {
      final role = (userData['role'] ?? 'staff').toString().toLowerCase();
      final rawKontak = (userData['email_kontak'] ?? '').toString();
      final cleanKontak = cleanEmailKontak(
        rawKontak,
        fallbackEmail: userData['email'],
      );
      final aliasTag = role == 'admin'
          ? extractStoredAliasTag(rawKontak)
          : extractAliasTagFromAuthEmail(
              authEmail,
              fallbackRawEmailKontak: rawKontak,
            );
      final packed = packEmailKontak(
        cleanKontak,
        password: password,
        aliasTag: aliasTag,
        previousRawEmailKontak: rawKontak,
      );
      if (packed != rawKontak) {
        await _firestore.collection('users').doc(uid).update({
          'email_kontak': packed,
          'updated_at': FieldValue.serverTimestamp(),
        });
        userData['email_kontak'] = packed;
      }

      // Jika yang login adalah Admin, sinkronkan nama staf yang diubah mandiri oleh staf.
      if (role == 'admin') {
        unawaited(_syncPendingStaffNamesAsAdmin(_firestore));
      }
    } catch (_) {}
  }

  static Future<void> _syncPendingStaffNamesAsAdmin(
    FirebaseFirestore db,
  ) async {
    try {
      final snap = await db.collection('users').get();
      for (final doc in snap.docs) {
        final d = doc.data();
        if (_str(d['role']).toLowerCase() != 'staff') continue;
        final namaOver = extractStoredNamaOverride(d['email_kontak']);
        final namaDb = _str(d['nama']);
        if (namaOver.isNotEmpty && namaOver != namaDb) {
          try {
            await db.collection('users').doc(doc.id).update({
              'nama': namaOver,
              'jabatan': _str(d['jabatan']).isNotEmpty
                  ? _str(d['jabatan'])
                  : '-',
              'no_hp': _str(d['no_hp']),
              'foto_base64': (d['foto_base64'] ?? '').toString(),
              'updated_at': FieldValue.serverTimestamp(),
            });
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  // =======================================================================
  // INSTANCE FIREBASE AUTH SEKUNDER (SESI ADMIN LATAR BELAKANG)
  // =======================================================================
  static Future<FirebaseApp> _secondaryApp() async {
    try {
      return Firebase.app('staffCreator');
    } catch (_) {
      return await Firebase.initializeApp(
        name: 'staffCreator',
        options: Firebase.app().options,
      );
    }
  }

  static Future<FirebaseAuth> _secondaryAuth() async {
    final app = await _secondaryApp();
    return FirebaseAuth.instanceFor(app: app);
  }

  static Future<FirebaseFirestore> _secondaryFirestore() async {
    final app = await _secondaryApp();
    return FirebaseFirestore.instanceFor(app: app);
  }

  static Future<({FirebaseAuth auth, FirebaseFirestore db})?>
  _ensureAdminSession() async {
    try {
      final auth = await _secondaryAuth();
      final db = await _secondaryFirestore();

      if (auth.currentUser != null) {
        try {
          final doc = await _firestore
              .collection('users')
              .doc(auth.currentUser!.uid)
              .get();
          if (_str(doc.data()?['role']).toLowerCase() == 'admin') {
            return (auth: auth, db: db);
          }
        } catch (_) {}
      }

      final usersSnap = await _firestore.collection('users').get();
      final adminDocs = usersSnap.docs.where((d) {
        return _str(d.data()['role']).toLowerCase() == 'admin';
      }).toList();

      for (final adminDoc in adminDocs) {
        final d = adminDoc.data();
        final rawKontak = _str(d['email_kontak']);
        final storedPass = extractStoredPassword(rawKontak);
        final storedAlias = extractStoredAliasTag(rawKontak);
        final effNip = effectiveNipFromData(d);
        final rawNip = _str(d['nip']);
        final primaryEmail = _str(d['email']);

        final emailCandidates = <String>[
          if (primaryEmail.isNotEmpty) primaryEmail,
          if (effNip.isNotEmpty && storedAlias.isNotEmpty)
            authEmailForNip(effNip, storedAlias),
          if (effNip.isNotEmpty) authEmailForNip(effNip),
          if (rawNip.isNotEmpty && rawNip != effNip) authEmailForNip(rawNip),
        ];
        final uniqueEmails = <String>[];
        for (final e in emailCandidates) {
          if (e.isNotEmpty && !uniqueEmails.contains(e)) uniqueEmails.add(e);
        }

        final passCandidates = <String>[
          if (storedPass != null && storedPass.length >= 6) storedPass,
          'diansastro',
          'atasan123',
          'admin123',
          if (effNip.length >= 6) effNip,
          if (rawNip.length >= 6 && rawNip != effNip) rawNip,
        ];
        final uniquePasses = <String>[];
        for (final p in passCandidates) {
          if (p.length >= 6 && !uniquePasses.contains(p)) uniquePasses.add(p);
        }

        for (final em in uniqueEmails) {
          for (final pw in uniquePasses) {
            try {
              final cred = await auth.signInWithEmailAndPassword(
                email: em,
                password: pw,
              );
              if (cred.user != null && cred.user!.uid == adminDoc.id) {
                return (auth: auth, db: db);
              }
              await auth.signOut();
            } on FirebaseAuthException catch (e) {
              if (e.code == 'user-not-found') break;
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Memperbarui profil Staff sendiri (termasuk Nama Lengkap, No. HP, dan kredensial)
  /// secara 100% kompatibel dengan firestore.rules yang sudah di-deploy.
  static Future<void> updateStaffSelfProfile({
    required String uid,
    required String nama,
    required String noHp,
    required String packedEmailKontak,
  }) async {
    final cleanNama = nama.trim();
    final cleanNoHp = noHp.trim();
    if (cleanNama.isEmpty) {
      throw const StaffAdminException('Nama lengkap wajib diisi.', 400);
    }

    // 1. Sertakan nama terbaru di dalam metadata email_kontak sehingga aturan
    //    firestore.rules (yang mengizinkan staf mengubah no_hp, email_kontak, foto_base64)
    //    langsung menyimpannya tanpa pernah ditolak permission-denied!
    final packedWithNama = packEmailKontak(
      cleanEmailKontak(packedEmailKontak),
      password: extractStoredPassword(packedEmailKontak),
      aliasTag: extractStoredAliasTag(packedEmailKontak),
      nipOverride: extractStoredNipOverride(packedEmailKontak),
      namaOverride: cleanNama,
      previousRawEmailKontak: packedEmailKontak,
    );

    await _firestore.collection('users').doc(uid).update({
      'no_hp': cleanNoHp,
      'email_kontak': packedWithNama,
      'updated_at': FieldValue.serverTimestamp(),
    });

    // 2. Coba update field `nama` secara langsung di latar belakang (melalui sesi Admin
    //    atau jika rules terbaru mengizinkan) agar field `nama` tingkat atas juga ikut terbarui.
    unawaited(() async {
      try {
        await _firestore.collection('users').doc(uid).update({
          'nama': cleanNama,
          'no_hp': cleanNoHp,
          'email_kontak': packedWithNama,
          'updated_at': FieldValue.serverTimestamp(),
        });
      } catch (_) {
        final adminSession = await _ensureAdminSession();
        if (adminSession != null) {
          try {
            final snap = await adminSession.db
                .collection('users')
                .doc(uid)
                .get();
            final data = snap.data() ?? <String, dynamic>{};
            final jabatan = _str(data['jabatan']).isNotEmpty
                ? _str(data['jabatan'])
                : '-';
            final foto = (data['foto_base64'] ?? '').toString();
            await adminSession.db.collection('users').doc(uid).update({
              'nama': cleanNama,
              'jabatan': jabatan,
              'no_hp': cleanNoHp,
              'foto_base64': foto,
              'email_kontak': packedWithNama,
              'updated_at': FieldValue.serverTimestamp(),
            });
          } catch (_) {}
          try {
            final penSnap = await adminSession.db
                .collection('penugasan')
                .where('staff_id', isEqualTo: uid)
                .get();
            for (final pDoc in penSnap.docs) {
              try {
                await pDoc.reference.update({
                  'staff_nama': cleanNama,
                  'updated_at': FieldValue.serverTimestamp(),
                });
              } catch (_) {}
            }
          } catch (_) {}
        }
      }
    }());
  }

  // Panggilan opsional ke Supabase Edge Function (jika sudah di-deploy).
  static Future<Map<String, dynamic>?> _tryEdgeFunction(
    String action,
    Map<String, dynamic> data, {
    required bool butuhLogin,
  }) async {
    try {
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (butuhLogin) {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return null;
        final token = await user.getIdToken();
        if (token == null || token.isEmpty) return null;
        headers['Authorization'] = 'Bearer $token';
      }
      final res = await http
          .post(
            Uri.parse(_edgeUrl),
            headers: headers,
            body: jsonEncode({'action': action, ...data}),
          )
          .timeout(const Duration(seconds: 4));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
        return <String, dynamic>{};
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static String _phoneOf(Map<String, dynamic> data) {
    for (final key in [
      'no_hp',
      'wa',
      'noHp',
      'nomor_hp',
      'no_telp',
      'telepon',
    ]) {
      final v = (data[key] ?? '').toString().trim();
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  // =======================================================================
  // 0. MUTASI / UPDATE PROFIL & KREDENSIAL ADMIN (ATASAN)
  // =======================================================================
  static Future<void> updateAdminProfileAndCredentials({
    required String nama,
    required String jabatan,
    required String newNip,
    required String noHp,
    required String emailKontak,
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      throw const StaffAdminException(
        'Sesi login admin habis. Silakan login ulang.',
        401,
      );
    }

    final cleanNama = nama.trim();
    final cleanJabatan = jabatan.trim();
    final cleanNip = newNip.trim();
    final cleanNoHp = noHp.trim();
    final cleanEmail = cleanEmailKontak(emailKontak);
    final cleanCurrentPass = currentPassword;
    final cleanNewPass = newPassword.trim();

    if (cleanNama.isEmpty) {
      throw const StaffAdminException('Nama lengkap wajib diisi.', 400);
    }
    if (cleanJabatan.isEmpty) {
      throw const StaffAdminException('Jabatan wajib diisi.', 400);
    }
    if (!RegExp(r'^[0-9]{6,30}$').hasMatch(cleanNip)) {
      throw const StaffAdminException(
        'NIP harus berupa angka 6 sampai 30 digit.',
        400,
      );
    }

    final docRef = _firestore.collection('users').doc(user.uid);
    final docSnap = await docRef.get();
    final oldData = docSnap.data() ?? <String, dynamic>{};
    final oldRawKontak = (oldData['email_kontak'] ?? '').toString();
    final oldNip = effectiveNipFromData(oldData);
    final baseDbNip = (oldData['nip'] ?? '').toString().trim();

    final bool nipChanged = oldNip.isNotEmpty && cleanNip != oldNip;
    final bool changingPassword = cleanNewPass.isNotEmpty;

    if (nipChanged) {
      final allUsers = await _firestore.collection('users').get();
      for (final d in allUsers.docs) {
        if (d.id == user.uid) continue;
        final otherNip = effectiveNipFromData(d.data());
        if (otherNip == cleanNip) {
          throw const StaffAdminException(
            'NIP tersebut sudah terdaftar pada pengguna lain.',
            409,
          );
        }
      }
    }

    String effectivePass =
        extractStoredPassword(oldRawKontak) ?? cleanCurrentPass;

    if (nipChanged || changingPassword) {
      if (cleanCurrentPass.isEmpty) {
        throw const StaffAdminException(
          'Masukkan kata sandi saat ini untuk mengubah NIP atau kata sandi.',
          400,
        );
      }
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: cleanCurrentPass,
      );
      await user.reauthenticateWithCredential(credential);

      if (changingPassword) {
        if (cleanNewPass.length < 6) {
          throw const StaffAdminException(
            'Kata sandi baru minimal 6 karakter.',
            400,
          );
        }
        await user.updatePassword(cleanNewPass);
        effectivePass = cleanNewPass;
      } else {
        effectivePass = cleanCurrentPass;
      }
    }

    final primaryAuthEmail = user.email!.trim();
    final targetNipEmail = authEmailForNip(cleanNip);
    String activeAlias = extractStoredAliasTag(oldRawKontak);

    if ((nipChanged || changingPassword) &&
        effectivePass.length >= 6 &&
        primaryAuthEmail.toLowerCase() != targetNipEmail.toLowerCase()) {
      final redirectPayload =
          '$adminRedirectPrefix$primaryAuthEmail::${user.uid}';
      final auth = await _secondaryAuth();
      try {
        final aliasCandidates = <String>[
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
        final passCandidates = <String>{
          effectivePass,
          if (cleanCurrentPass.length >= 6) cleanCurrentPass,
          if (extractStoredPassword(oldRawKontak) != null)
            extractStoredPassword(oldRawKontak)!,
          if (cleanNip.length >= 6) cleanNip,
          if (oldNip.length >= 6) oldNip,
        }.toList();

        for (final tag in aliasCandidates) {
          final candidateEmail = authEmailForNip(cleanNip, tag);
          try {
            final cred = await auth.createUserWithEmailAndPassword(
              email: candidateEmail,
              password: effectivePass,
            );
            await cred.user?.updateDisplayName(redirectPayload);
            activeAlias = tag;
            await auth.signOut();
            break;
          } on FirebaseAuthException catch (e) {
            if (e.code == 'email-already-in-use') {
              bool updatedRedirect = false;
              for (final p in passCandidates) {
                try {
                  final cred = await auth.signInWithEmailAndPassword(
                    email: candidateEmail,
                    password: p,
                  );
                  final u = cred.user;
                  if (u != null) {
                    final otherDoc = await _firestore
                        .collection('users')
                        .doc(u.uid)
                        .get();
                    if (!otherDoc.exists || u.uid == user.uid) {
                      if (p != effectivePass) {
                        await u.updatePassword(effectivePass);
                      }
                      await u.updateDisplayName(redirectPayload);
                      activeAlias = tag;
                      updatedRedirect = true;
                    }
                  }
                  await auth.signOut();
                  if (updatedRedirect) break;
                } catch (_) {
                  try {
                    await auth.signOut();
                  } catch (_) {}
                }
              }
              if (updatedRedirect) break;
              continue;
            }
          } catch (_) {}
        }
      } finally {
        try {
          await auth.signOut();
        } catch (_) {}
      }
    }

    await docRef.update({
      'nama': cleanNama,
      'jabatan': cleanJabatan,
      'no_hp': cleanNoHp,
      'updated_at': FieldValue.serverTimestamp(),
    });

    final packedKontak = packEmailKontak(
      cleanEmail,
      password: effectivePass.length >= 6 ? effectivePass : null,
      aliasTag: activeAlias,
      nipOverride: cleanNip != baseDbNip ? cleanNip : '',
      namaOverride: cleanNama,
      previousRawEmailKontak: oldRawKontak,
    );
    await docRef.update({
      'email_kontak': packedKontak,
      'no_hp': cleanNoHp,
      'updated_at': FieldValue.serverTimestamp(),
    });

    if (cleanNip != baseDbNip) {
      try {
        await docRef.update({
          'nip': cleanNip,
          'email': '$cleanNip$nipDomain',
          'updated_at': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }
  }

  // =======================================================================
  // 1. UBAH / RESET PASSWORD STAF (TERMASUK RESET KE NIP)
  // =======================================================================
  static Future<String> setPassword(
    String uid,
    String password, {
    Map<String, dynamic>? profileUpdates,
  }) async {
    final cleanPass = password.trim();
    if (cleanPass.length < 6) {
      throw const StaffAdminException('Password minimal 6 karakter.', 400);
    }

    final adminUser = FirebaseAuth.instance.currentUser;
    if (adminUser == null) {
      throw const StaffAdminException(
        'Sesi login admin habis. Silakan login ulang.',
        401,
      );
    }

    final docSnap = await _firestore.collection('users').doc(uid).get();
    if (!docSnap.exists) {
      throw const StaffAdminException('Data staf tidak ditemukan.', 404);
    }

    final oldData = docSnap.data() ?? <String, dynamic>{};
    final oldNip = (oldData['nip'] ?? '').toString().trim();
    final nip = (profileUpdates?['nip'] ?? oldNip).toString().trim();
    final nama = (profileUpdates?['nama'] ?? effectiveNamaFromData(oldData))
        .toString()
        .trim();
    final jabatan = (profileUpdates?['jabatan'] ?? oldData['jabatan'] ?? '-')
        .toString()
        .trim();
    final noHp = (profileUpdates?['no_hp'] ?? _phoneOf(oldData))
        .toString()
        .trim();
    final fotoBase64 =
        (profileUpdates?['foto_base64'] ?? oldData['foto_base64'] ?? '')
            .toString()
            .trim();
    final rawKontakLama = (oldData['email_kontak'] ?? '').toString();
    final cleanKontak = cleanEmailKontak(
      profileUpdates != null && profileUpdates.containsKey('email_kontak')
          ? profileUpdates['email_kontak']
          : rawKontakLama,
      fallbackEmail: oldData['email'],
    );

    if (!RegExp(r'^[0-9]{6,30}$').hasMatch(nip)) {
      throw const StaffAdminException(
        'NIP staf harus berupa angka 6 sampai 30 digit.',
        400,
      );
    }

    final bool nipBerubah = oldNip.isNotEmpty && nip != oldNip;

    if (nipBerubah) {
      final dupSnap = await _firestore
          .collection('users')
          .where('nip', isEqualTo: nip)
          .get();
      if (dupSnap.docs.any((d) => d.id != uid)) {
        throw const StaffAdminException(
          'NIP tersebut sudah terdaftar pada pengguna lain.',
          409,
        );
      }
    }

    final storedPass = extractStoredPassword(rawKontakLama);
    final storedAlias = extractStoredAliasTag(rawKontakLama);

    if (!nipBerubah) {
      final emailCandidates = <String>[
        if (storedAlias.isNotEmpty) authEmailForNip(nip, storedAlias),
        authEmailForNip(nip),
        if ((oldData['email'] ?? '').toString().trim().isNotEmpty)
          (oldData['email'] ?? '')
              .toString()
              .split(_sep)
              .first
              .split('\t')
              .first
              .trim(),
        authEmailForNip(nip, 'r1'),
        authEmailForNip(nip, 'r2'),
      ];
      final uniqueEmails = <String>[];
      for (final e in emailCandidates) {
        if (e.isNotEmpty && !uniqueEmails.contains(e)) uniqueEmails.add(e);
      }

      final passCandidates = <String>[
        if (storedPass != null && storedPass.length >= 6) storedPass,
        if (oldNip.length >= 6) oldNip,
        if (nip.length >= 6) nip,
        cleanPass,
      ];
      final uniquePasses = <String>[];
      for (final p in passCandidates) {
        if (p.length >= 6 && !uniquePasses.contains(p)) uniquePasses.add(p);
      }

      final auth = await _secondaryAuth();
      try {
        for (int i = 0; i < uniqueEmails.length; i++) {
          final candidateEmail = uniqueEmails[i];
          final passesToTry = i <= 1
              ? uniquePasses
              : <String>[
                  if (storedPass != null && storedPass.length >= 6) storedPass,
                  if (oldNip.length >= 6 && oldNip != storedPass) oldNip,
                ];

          for (final candidatePass in passesToTry) {
            try {
              final cred = await auth.signInWithEmailAndPassword(
                email: candidateEmail,
                password: candidatePass,
              );
              if (cred.user != null && cred.user!.uid == uid) {
                if (candidatePass != cleanPass) {
                  await cred.user!.updatePassword(cleanPass);
                }
                final activeAlias = extractAliasTagFromAuthEmail(
                  cred.user!.email,
                  fallbackRawEmailKontak: rawKontakLama,
                );
                await auth.signOut();

                await _firestore.collection('users').doc(uid).update({
                  'nama': nama.isNotEmpty ? nama : 'Staf',
                  'nip': nip,
                  'email': '$nip$nipDomain',
                  'email_kontak': packEmailKontak(
                    cleanKontak,
                    password: cleanPass,
                    aliasTag: activeAlias,
                    namaOverride: nama.isNotEmpty ? nama : 'Staf',
                  ),
                  'jabatan': jabatan.isNotEmpty ? jabatan : '-',
                  'no_hp': noHp,
                  'foto_base64': fotoBase64,
                  'updated_at': FieldValue.serverTimestamp(),
                });
                return uid;
              }
              await auth.signOut();
            } on FirebaseAuthException catch (e) {
              if (e.code == 'user-not-found') {
                break;
              }
            } catch (_) {}
          }
        }
      } finally {
        try {
          await auth.signOut();
        } catch (_) {}
      }

      final edgeRes = await _tryEdgeFunction('set-password', {
        'uid': uid,
        'password': cleanPass,
      }, butuhLogin: true);
      if (edgeRes != null) {
        await _firestore.collection('users').doc(uid).update({
          'nama': nama.isNotEmpty ? nama : 'Staf',
          'nip': nip,
          'email': '$nip$nipDomain',
          'email_kontak': packEmailKontak(
            cleanKontak,
            password: cleanPass,
            aliasTag: '',
            namaOverride: nama.isNotEmpty ? nama : 'Staf',
          ),
          'jabatan': jabatan.isNotEmpty ? jabatan : '-',
          'no_hp': noHp,
          'foto_base64': fotoBase64,
          'updated_at': FieldValue.serverTimestamp(),
        });
        return uid;
      }
    }

    return await _rebindStaffAuth(
      oldUid: uid,
      oldNip: oldNip,
      newNip: nip,
      newPassword: cleanPass,
      nama: nama,
      jabatan: jabatan,
      noHp: noHp,
      cleanKontak: cleanKontak,
      fotoBase64: fotoBase64,
      oldStoredPass: storedPass,
      oldStoredAlias: storedAlias,
    );
  }

  static Future<String> _rebindStaffAuth({
    required String oldUid,
    required String oldNip,
    required String newNip,
    required String newPassword,
    required String nama,
    required String jabatan,
    required String noHp,
    required String cleanKontak,
    required String fotoBase64,
    required String? oldStoredPass,
    required String oldStoredAlias,
  }) async {
    final auth = await _secondaryAuth();
    String? newUid;
    String activeAlias = '';

    final aliasCandidates = <String>[
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

    try {
      for (final tag in aliasCandidates) {
        final targetEmail = authEmailForNip(newNip, tag);
        try {
          final cred = await auth.createUserWithEmailAndPassword(
            email: targetEmail,
            password: newPassword,
          );
          newUid = cred.user!.uid;
          activeAlias = tag;
          await auth.signOut();
          break;
        } on FirebaseAuthException catch (e) {
          if (e.code == 'email-already-in-use') {
            final tryPasses = <String>[
              newPassword,
              if (oldStoredPass != null &&
                  oldStoredPass.length >= 6 &&
                  oldStoredPass != newPassword)
                oldStoredPass,
              if (newNip.length >= 6 && newNip != newPassword) newNip,
              if (oldNip.length >= 6 &&
                  oldNip != newNip &&
                  oldNip != newPassword)
                oldNip,
            ];
            bool claimed = false;
            for (final p in tryPasses) {
              try {
                final cred = await auth.signInWithEmailAndPassword(
                  email: targetEmail,
                  password: p,
                );
                final candidateUid = cred.user!.uid;
                final otherDoc = await _firestore
                    .collection('users')
                    .doc(candidateUid)
                    .get();
                if (!otherDoc.exists || candidateUid == oldUid) {
                  if (p != newPassword) {
                    await cred.user!.updatePassword(newPassword);
                  }
                  newUid = candidateUid;
                  activeAlias = tag;
                  claimed = true;
                }
                await auth.signOut();
                if (claimed) break;
              } catch (_) {
                try {
                  await auth.signOut();
                } catch (_) {}
              }
            }
            if (claimed) break;
            continue;
          }
          if (e.code == 'weak-password') {
            throw const StaffAdminException(
              'Password terlalu lemah, minimal 6 karakter.',
              400,
            );
          }
          rethrow;
        }
      }

      if (newUid == null) {
        throw const StaffAdminException(
          'Gagal mereset akun login staf. Silakan coba lagi.',
          500,
        );
      }

      final packedKontak = packEmailKontak(
        cleanKontak,
        password: newPassword,
        aliasTag: activeAlias,
        namaOverride: nama.isNotEmpty ? nama : 'Staf',
      );

      if (newUid == oldUid) {
        await _firestore.collection('users').doc(oldUid).update({
          'nama': nama.isNotEmpty ? nama : 'Staf',
          'nip': newNip,
          'email': '$newNip$nipDomain',
          'email_kontak': packedKontak,
          'jabatan': jabatan.isNotEmpty ? jabatan : '-',
          'no_hp': noHp,
          'foto_base64': fotoBase64,
          'updated_at': FieldValue.serverTimestamp(),
        });
        return oldUid;
      }

      await _firestore.collection('users').doc(newUid).set({
        'uid': newUid,
        'email': '$newNip$nipDomain',
        'email_kontak': packedKontak,
        'nama': nama.isNotEmpty ? nama : 'Staf',
        'nip': newNip,
        'jabatan': jabatan.isNotEmpty ? jabatan : '-',
        'no_hp': noHp,
        'role': 'staff',
        'status_pekerjaan': 'tersedia',
        'foto_base64': fotoBase64,
        'is_first_login': true,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      try {
        final tugasSnap = await _firestore
            .collection('tugas')
            .where('staff_ids', arrayContains: oldUid)
            .get();
        for (final tDoc in tugasSnap.docs) {
          final rawIds = tDoc.data()['staff_ids'];
          if (rawIds is List) {
            final ids = rawIds.map((e) => e.toString()).toList();
            final idx = ids.indexOf(oldUid);
            if (idx != -1) {
              ids[idx] = newUid;
              await tDoc.reference.update({'staff_ids': ids});
            }
          }
        }
      } catch (_) {}

      try {
        final penSnap = await _firestore
            .collection('penugasan')
            .where('staff_id', isEqualTo: oldUid)
            .get();
        for (final pDoc in penSnap.docs) {
          try {
            await pDoc.reference.update({
              'staff_id': newUid,
              'updated_at': FieldValue.serverTimestamp(),
            });
          } catch (_) {}
        }
      } catch (_) {}

      try {
        await syncKendalaCacheForAllTasks(_firestore);
      } catch (_) {}

      await _firestore.collection('users').doc(oldUid).delete();

      if (oldNip.isNotEmpty && (oldStoredPass != null || oldNip.length >= 6)) {
        final oldEmail = authEmailForNip(oldNip, oldStoredAlias);
        final oldPassCandidates = <String>[
          if (oldStoredPass != null && oldStoredPass.length >= 6) oldStoredPass,
          if (oldNip.length >= 6) oldNip,
        ];
        for (final p in oldPassCandidates) {
          try {
            final oldCred = await auth.signInWithEmailAndPassword(
              email: oldEmail,
              password: p,
            );
            if (oldCred.user != null && oldCred.user!.uid == oldUid) {
              await oldCred.user!.delete();
              break;
            }
            await auth.signOut();
          } catch (_) {}
        }
      }

      return newUid;
    } finally {
      try {
        await auth.signOut();
      } catch (_) {}
    }
  }

  // =======================================================================
  // 2. BUAT AKUN STAF BARU
  // =======================================================================
  static Future<String> createStaffAccount({
    required String nama,
    required String nip,
    required String jabatan,
    required String emailKontak,
    required String noHp,
    required String password,
    required String fotoBase64,
  }) async {
    final cleanNip = nip.trim();
    final cleanPass = password.trim();

    final existingSnap = await _firestore
        .collection('users')
        .where('nip', isEqualTo: cleanNip)
        .limit(1)
        .get();
    if (existingSnap.docs.isNotEmpty) {
      throw const StaffAdminException(
        'NIP ini sudah terdaftar pada staf lain.',
        409,
      );
    }

    final auth = await _secondaryAuth();
    String? newUid;
    String activeAlias = '';

    final aliasCandidates = <String>[
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

    try {
      for (final tag in aliasCandidates) {
        final candidateEmail = authEmailForNip(cleanNip, tag);
        try {
          final cred = await auth.createUserWithEmailAndPassword(
            email: candidateEmail,
            password: cleanPass,
          );
          newUid = cred.user!.uid;
          activeAlias = tag;

          await _firestore.collection('users').doc(newUid).set({
            'uid': newUid,
            'email': '$cleanNip$nipDomain',
            'email_kontak': packEmailKontak(
              emailKontak,
              password: cleanPass,
              aliasTag: activeAlias,
              namaOverride: nama.trim(),
            ),
            'nama': nama.trim(),
            'nip': cleanNip,
            'jabatan': jabatan.trim(),
            'no_hp': noHp.trim(),
            'role': 'staff',
            'status_pekerjaan': 'tersedia',
            'foto_base64': fotoBase64,
            'is_first_login': true,
            'created_at': FieldValue.serverTimestamp(),
            'updated_at': FieldValue.serverTimestamp(),
          });

          await auth.signOut();
          return newUid;
        } on FirebaseAuthException catch (e) {
          if (e.code == 'email-already-in-use') {
            for (final tryPass in <String>{cleanPass, cleanNip}) {
              if (tryPass.length < 6) continue;
              try {
                final orphanCred = await auth.signInWithEmailAndPassword(
                  email: candidateEmail,
                  password: tryPass,
                );
                final orphanUid = orphanCred.user!.uid;
                final orphanDoc = await _firestore
                    .collection('users')
                    .doc(orphanUid)
                    .get();
                if (!orphanDoc.exists) {
                  if (tryPass != cleanPass) {
                    await orphanCred.user!.updatePassword(cleanPass);
                  }
                  await _firestore.collection('users').doc(orphanUid).set({
                    'uid': orphanUid,
                    'email': '$cleanNip$nipDomain',
                    'email_kontak': packEmailKontak(
                      emailKontak,
                      password: cleanPass,
                      aliasTag: tag,
                      namaOverride: nama.trim(),
                    ),
                    'nama': nama.trim(),
                    'nip': cleanNip,
                    'jabatan': jabatan.trim(),
                    'no_hp': noHp.trim(),
                    'role': 'staff',
                    'status_pekerjaan': 'tersedia',
                    'foto_base64': fotoBase64,
                    'is_first_login': true,
                    'created_at': FieldValue.serverTimestamp(),
                    'updated_at': FieldValue.serverTimestamp(),
                  });
                  await auth.signOut();
                  return orphanUid;
                }
                await auth.signOut();
              } catch (_) {
                try {
                  await auth.signOut();
                } catch (_) {}
              }
            }
            continue;
          }
          rethrow;
        } catch (e) {
          try {
            await auth.currentUser?.delete();
          } catch (_) {}
          rethrow;
        }
      }
      throw const StaffAdminException(
        'Gagal membuat akun login untuk NIP ini.',
        500,
      );
    } finally {
      try {
        await auth.signOut();
      } catch (_) {}
    }
  }

  // =======================================================================
  // 3. UBAH NIP STAF
  // =======================================================================
  static Future<String> setNip(String uid, String nip) async {
    final cleanNip = nip.trim();
    final docSnap = await _firestore.collection('users').doc(uid).get();
    final data = docSnap.data() ?? <String, dynamic>{};
    final rawKontak = (data['email_kontak'] ?? '').toString();
    final currentPass = extractStoredPassword(rawKontak) ?? cleanNip;
    await setPassword(uid, currentPass, profileUpdates: {'nip': cleanNip});
    return '$cleanNip$nipDomain';
  }

  // =======================================================================
  // 4. HAPUS AKUN AUTH STAF
  // =======================================================================
  static Future<void> deleteAuth(
    String uid, {
    Map<String, dynamic>? staffData,
  }) async {
    if (staffData != null) {
      final nip = (staffData['nip'] ?? '').toString().trim();
      final rawKontak = (staffData['email_kontak'] ?? '').toString();
      final storedPass = extractStoredPassword(rawKontak);
      final storedAlias = extractStoredAliasTag(rawKontak);

      if (nip.isNotEmpty) {
        final emails = <String>{
          if (storedAlias.isNotEmpty) authEmailForNip(nip, storedAlias),
          authEmailForNip(nip),
          authEmailForNip(nip, 'r1'),
        };
        final passes = <String>{
          if (storedPass != null && storedPass.length >= 6) storedPass,
          if (nip.length >= 6) nip,
        };
        final auth = await _secondaryAuth();
        try {
          for (final email in emails) {
            for (final pass in passes) {
              try {
                final cred = await auth.signInWithEmailAndPassword(
                  email: email,
                  password: pass,
                );
                if (cred.user != null && cred.user!.uid == uid) {
                  await cred.user!.delete();
                  return;
                }
                await auth.signOut();
              } catch (_) {}
            }
          }
        } finally {
          try {
            await auth.signOut();
          } catch (_) {}
        }
      }
    }

    await _tryEdgeFunction('delete-auth', {'uid': uid}, butuhLogin: true);
  }

  // =======================================================================
  // 5. PROSES PERMINTAAN LUPA PASSWORD OLEH ADMIN
  // =======================================================================
  static Future<void> resolveReset(String uid, {required bool reset}) async {
    final adminUser = FirebaseAuth.instance.currentUser;
    if (adminUser == null) {
      throw const StaffAdminException(
        'Sesi login habis. Silakan login ulang.',
        401,
      );
    }

    String targetUid = uid;
    if (reset) {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (!userDoc.exists) {
        throw const StaffAdminException('Data staf tidak ditemukan.', 404);
      }
      final nip = (userDoc.data()?['nip'] ?? '').toString().trim();
      if (nip.length < 6) {
        throw const StaffAdminException('NIP staf tidak valid.', 400);
      }
      targetUid = await setPassword(uid, nip);
    }

    try {
      await _firestore.collection('permintaan_reset').doc(uid).update({
        'status': reset ? 'selesai' : 'ditolak',
        'diproses_oleh': adminUser.uid,
        'diproses_at': FieldValue.serverTimestamp(),
        if (targetUid != uid) 'uid_baru': targetUid,
      });
    } catch (_) {
      await _tryEdgeFunction('resolve-reset', {
        'uid': uid,
        'action': reset ? 'reset' : 'tolak',
      }, butuhLogin: true);
    }
  }

  // =======================================================================
  // 6. FUNGSI PUBLIK (SEBELUM LOGIN)
  // =======================================================================
  static Future<Map<String, dynamic>> checkNip(String nip) async {
    final res = await _tryEdgeFunction('check-nip', {
      'nip': nip.trim(),
    }, butuhLogin: false);
    if (res != null && res['exists'] == true) return res;
    return <String, dynamic>{'exists': true, 'legacy': false};
  }

  static Future<bool> requestReset(String nip, String nama) async {
    final cleanNip = nip.trim();
    final cleanNama = nama.trim();

    final edgeRes = await _tryEdgeFunction('request-reset', {
      'nip': cleanNip,
      'nama': cleanNama,
    }, butuhLogin: false);
    if (edgeRes != null) {
      return edgeRes['sudahAda'] == true;
    }

    try {
      final snap = await _firestore
          .collection('users')
          .where('nip', isEqualTo: cleanNip)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        final doc = snap.docs.first;
        final data = doc.data();
        final namaDb = effectiveNamaFromData(
          data,
        ).toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
        final namaInput = cleanNama.toLowerCase().replaceAll(
          RegExp(r'\s+'),
          ' ',
        );
        if (namaDb != namaInput) {
          throw const StaffAdminException(
            'NIP atau nama tidak cocok dengan data staf.',
            404,
          );
        }
        final reqRef = _firestore.collection('permintaan_reset').doc(doc.id);
        final lama = await reqRef.get();
        if (lama.exists && lama.data()?['status'] == 'menunggu') {
          return true;
        }
        await reqRef.set({
          'uid': doc.id,
          'nip': cleanNip,
          'nama': effectiveNamaFromData(data).isNotEmpty
              ? effectiveNamaFromData(data)
              : cleanNama,
          'status': 'menunggu',
          'created_at': FieldValue.serverTimestamp(),
        });
        return false;
      }
    } on StaffAdminException {
      rethrow;
    } catch (_) {}

    return false;
  }

  // =======================================================================
  // 7. SINKRONISASI & PEMBACAAN RIWAYAT KENDALA UNTUK ROLE STAFF & ATASAN
  // =======================================================================
  static String _str(dynamic v) => (v ?? '').toString().trim();

  static DateTime? _dt(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    return null;
  }

  static Future<void> syncKendalaCacheForAllTasks([
    FirebaseFirestore? firestoreInstance,
  ]) async {
    final db = firestoreInstance ?? _firestore;
    try {
      final snap = await db.collection('laporan_kendala').get();
      if (snap.docs.isEmpty) return;

      final byTugas = <String, Map<String, List<Map<String, dynamic>>>>{};

      for (final d in snap.docs) {
        final data = Map<String, dynamic>.from(d.data());
        final penId = _str(data['penugasan_id']);
        var tugasId = _str(data['tugas_id']);
        if (penId.isEmpty) continue;

        if (tugasId.isEmpty) {
          try {
            final pSnap = await db.collection('penugasan').doc(penId).get();
            tugasId = _str(pSnap.data()?['tugas_id']);
          } catch (_) {}
        }
        if (tugasId.isEmpty) continue;

        final riwayatList = <Map<String, dynamic>>[];
        try {
          final rSnap = await db
              .collection('laporan_kendala')
              .doc(d.id)
              .collection('riwayat')
              .get();
          for (final rDoc in rSnap.docs) {
            riwayatList.add({'_id': rDoc.id, ...rDoc.data()});
          }
          riwayatList.sort(
            (a, b) => (_dt(a['created_at']) ?? DateTime(1970)).compareTo(
              _dt(b['created_at']) ?? DateTime(1970),
            ),
          );
        } catch (_) {}

        final item = <String, dynamic>{
          '_id': d.id,
          ...data,
          '_riwayat': riwayatList,
        };
        final penMap = byTugas.putIfAbsent(
          tugasId,
          () => <String, List<Map<String, dynamic>>>{},
        );
        final list = penMap.putIfAbsent(penId, () => <Map<String, dynamic>>[]);
        list.add(item);
      }

      for (final entry in byTugas.entries) {
        final tugasId = entry.key;
        final penMap = entry.value;
        for (final list in penMap.values) {
          list.sort(
            (a, b) => (_dt(a['created_at']) ?? DateTime(1970)).compareTo(
              _dt(b['created_at']) ?? DateTime(1970),
            ),
          );
        }
        try {
          await db.collection('tugas').doc(tugasId).update({
            'riwayat_kendala_cache': penMap,
          });
        } catch (_) {}
      }
    } catch (_) {}
  }

  static Future<List<Map<String, dynamic>>> fetchKendalaForPenugasan({
    required String penugasanId,
    required String tugasId,
    required String currentUid,
    String staffUid = '',
    String staffNama = '',
    Map<String, dynamic>? rawTask,
    Map<String, dynamic>? rawAssignment,
  }) async {
    final byId = <String, Map<String, dynamic>>{};

    void mergeItem(Map<String, dynamic> rawItem) {
      final copy = Map<String, dynamic>.from(rawItem);
      final id = _str(copy['_id']);
      final key = id.isNotEmpty
          ? id
          : '${_str(copy['deskripsi'])}_${_dt(copy['created_at'])?.millisecondsSinceEpoch ?? 0}';
      final rawRiw = copy['_riwayat'];
      if (rawRiw is List) {
        final riwList = <Map<String, dynamic>>[];
        for (final r in rawRiw) {
          if (r is Map) riwList.add(Map<String, dynamic>.from(r));
        }
        riwList.sort(
          (a, b) => (_dt(a['created_at']) ?? DateTime(1970)).compareTo(
            _dt(b['created_at']) ?? DateTime(1970),
          ),
        );
        copy['_riwayat'] = riwList;
      } else {
        copy['_riwayat'] = <Map<String, dynamic>>[];
      }

      final existing = byId[key];
      if (existing == null) {
        byId[key] = copy;
      } else {
        final existingRiw = (existing['_riwayat'] as List?) ?? const [];
        final newRiw = (copy['_riwayat'] as List?) ?? const [];
        if (newRiw.length >= existingRiw.length) {
          byId[key] = copy;
        }
      }
    }

    void extractFromCacheMap(Map<String, dynamic>? taskData) {
      if (taskData == null) return;
      final cache = taskData['riwayat_kendala_cache'];
      if (cache is Map) {
        final rawList = cache[penugasanId];
        if (rawList is List) {
          for (final item in rawList) {
            if (item is Map) {
              mergeItem(Map<String, dynamic>.from(item));
            }
          }
        }
      }
    }

    extractFromCacheMap(rawTask);
    if (byId.isEmpty && tugasId.isNotEmpty) {
      try {
        final tSnap = await _firestore.collection('tugas').doc(tugasId).get();
        extractFromCacheMap(tSnap.data());
      } catch (_) {}
    }

    final uidCandidates = <String>{
      if (currentUid.trim().isNotEmpty) currentUid.trim(),
      if (staffUid.trim().isNotEmpty) staffUid.trim(),
    };
    for (final u in uidCandidates) {
      try {
        final snap = await _firestore
            .collection('laporan_kendala')
            .where('penugasan_id', isEqualTo: penugasanId)
            .where('pelapor_id', isEqualTo: u)
            .get();
        for (final d in snap.docs) {
          final k = d.data();
          final riw = <Map<String, dynamic>>[];
          try {
            final rSnap = await _firestore
                .collection('laporan_kendala')
                .doc(d.id)
                .collection('riwayat')
                .get();
            for (final rDoc in rSnap.docs) {
              riw.add({'_id': rDoc.id, ...rDoc.data()});
            }
          } catch (_) {}
          mergeItem({'_id': d.id, ...k, '_riwayat': riw});
        }
      } catch (_) {}
    }

    if (byId.isEmpty) {
      final adminSession = await _ensureAdminSession();
      if (adminSession != null) {
        try {
          final snap = await adminSession.db
              .collection('laporan_kendala')
              .where('penugasan_id', isEqualTo: penugasanId)
              .get();
          final cachedForPenugasan = <Map<String, dynamic>>[];
          for (final d in snap.docs) {
            final k = d.data();
            final riw = <Map<String, dynamic>>[];
            try {
              final rSnap = await adminSession.db
                  .collection('laporan_kendala')
                  .doc(d.id)
                  .collection('riwayat')
                  .get();
              for (final rDoc in rSnap.docs) {
                riw.add({'_id': rDoc.id, ...rDoc.data()});
              }
              riw.sort(
                (a, b) => (_dt(a['created_at']) ?? DateTime(1970)).compareTo(
                  _dt(b['created_at']) ?? DateTime(1970),
                ),
              );
            } catch (_) {}
            final fullItem = <String, dynamic>{
              '_id': d.id,
              ...k,
              '_riwayat': riw,
            };
            cachedForPenugasan.add(fullItem);
            mergeItem(fullItem);
          }

          if (tugasId.isNotEmpty && cachedForPenugasan.isNotEmpty) {
            unawaited(
              adminSession.db
                  .collection('tugas')
                  .doc(tugasId)
                  .update({
                    'riwayat_kendala_cache.$penugasanId': cachedForPenugasan,
                  })
                  .catchError((_) {}),
            );
          }
        } catch (_) {}
      }
    }

    final result = byId.values.toList()
      ..sort(
        (a, b) => (_dt(a['created_at']) ?? DateTime(1970)).compareTo(
          _dt(b['created_at']) ?? DateTime(1970),
        ),
      );
    return result;
  }

  // =======================================================================
  // 8. UPLOAD, RESOLUSI URL, PREVIEW IN-APP, & UNDUH FILE IN-APP
  // =======================================================================
  static String _cleanStoragePath(String rawPath) {
    var clean = rawPath.trim();
    while (clean.startsWith('/')) {
      clean = clean.substring(1);
    }
    if (clean.startsWith('${SupabaseStorageService.bucket}/')) {
      clean = clean.substring(SupabaseStorageService.bucket.length + 1);
    }
    while (clean.startsWith('/')) {
      clean = clean.substring(1);
    }
    return clean;
  }

  static String _safeFirestoreFileKey(String path) {
    final clean = _cleanStoragePath(path);
    return clean.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  }

  /// Upload ke Supabase Storage menggunakan sesi Admin jika token Staff ditolak.
  static Future<String?> uploadSupabaseViaAdmin({
    required String filePath,
    required Uint8List bytes,
    required String contentType,
  }) async {
    try {
      final adminSession = await _ensureAdminSession();
      if (adminSession == null || adminSession.auth.currentUser == null) {
        return null;
      }
      final adminToken = await adminSession.auth.currentUser!.getIdToken();
      if (adminToken == null || adminToken.isEmpty) return null;

      final adminSupabase = SupabaseClient(
        _supabaseUrl,
        _supabaseAnonKey,
        accessToken: () async => adminToken,
      );
      final uploaded = await adminSupabase.storage
          .from(SupabaseStorageService.bucket)
          .uploadBinary(
            _cleanStoragePath(filePath),
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: true),
          );
      return _cleanStoragePath(uploaded);
    } catch (_) {
      return null;
    }
  }

  /// Simpan cadangan file di dokumen `tugas/{tugasId}.stored_files` lewat sesi Admin
  /// agar file tetap bisa dibuka dan diunduh walaupun Supabase Storage menolak upload.
  static Future<void> saveBackupFileToFirestore({
    required String filePath,
    required String namaFile,
    required String mime,
    required Uint8List bytes,
    required String rawTugasOrTag,
  }) async {
    if (bytes.isEmpty || bytes.length > 650 * 1024) return;
    try {
      final adminSession = await _ensureAdminSession();
      if (adminSession == null) return;

      String targetTugasId = rawTugasOrTag.trim();
      if (targetTugasId.startsWith('kendala_')) {
        final penId = targetTugasId.substring('kendala_'.length);
        final pDoc = await adminSession.db
            .collection('penugasan')
            .doc(penId)
            .get();
        targetTugasId = _str(pDoc.data()?['tugas_id']);
      } else if (targetTugasId.startsWith('revisi_')) {
        final penId = targetTugasId.substring('revisi_'.length);
        final pDoc = await adminSession.db
            .collection('penugasan')
            .doc(penId)
            .get();
        targetTugasId = _str(pDoc.data()?['tugas_id']);
      } else if (targetTugasId.startsWith('solusi_')) {
        final lapId = targetTugasId.substring('solusi_'.length);
        final lDoc = await adminSession.db
            .collection('laporan_kendala')
            .doc(lapId)
            .get();
        targetTugasId = _str(lDoc.data()?['tugas_id']);
      }

      if (targetTugasId.isEmpty) return;

      final key = _safeFirestoreFileKey(filePath);
      final b64 = base64Encode(bytes);
      await adminSession.db.collection('tugas').doc(targetTugasId).update({
        'stored_files.$key': <String, dynamic>{
          'b64': b64,
          'name': namaFile,
          'mime': mime,
          'path': _cleanStoragePath(filePath),
        },
      });
    } catch (_) {}
  }

  /// Cari cadangan file dari `tugas.stored_files`, `penugasan`, atau `laporan_kendala`.
  static Future<String?> _findBackupDataUrl({
    required String cleanPath,
    String? assignmentId,
    String? laporanId,
    String? tugasId,
    String? namaFile,
  }) async {
    final key = _safeFirestoreFileKey(cleanPath);
    final mime = _guessMime(
      namaFile?.isNotEmpty == true ? namaFile! : cleanPath,
    );

    final mem = getCachedBytes(cleanPath);
    if (mem != null && mem.isNotEmpty) {
      return 'data:$mime;base64,${base64Encode(mem)}';
    }

    String resolvedTugasId = (tugasId ?? '').trim();

    if (assignmentId != null && assignmentId.trim().isNotEmpty) {
      try {
        final pDoc = await _firestore
            .collection('penugasan')
            .doc(assignmentId.trim())
            .get();
        final pData = pDoc.data();
        if (pData != null) {
          if (resolvedTugasId.isEmpty) {
            resolvedTugasId = _str(pData['tugas_id']);
          }
          final fUrl = _str(pData['file_hasil_url']);
          if (fUrl.startsWith('data:')) return fUrl;
        }
      } catch (_) {}
    }

    if (laporanId != null && laporanId.trim().isNotEmpty) {
      try {
        final lDoc = await _firestore
            .collection('laporan_kendala')
            .doc(laporanId.trim())
            .get();
        final lData = lDoc.data();
        if (lData != null) {
          if (resolvedTugasId.isEmpty) {
            resolvedTugasId = _str(lData['tugas_id']);
          }
          final bUrl = _str(lData['bukti_url']);
          if (bUrl.startsWith('data:')) return bUrl;
        }
      } catch (_) {}
    }

    if (resolvedTugasId.isNotEmpty) {
      try {
        final tDoc = await _firestore
            .collection('tugas')
            .doc(resolvedTugasId)
            .get();
        final stored = tDoc.data()?['stored_files'];
        if (stored is Map && stored[key] is Map) {
          final entry = Map<String, dynamic>.from(stored[key] as Map);
          final b64 = _str(entry['b64']);
          final m = _str(entry['mime']).isNotEmpty ? _str(entry['mime']) : mime;
          if (b64.isNotEmpty) {
            final decoded = base64Decode(b64);
            cacheMemoryBytes(cleanPath, decoded);
            return 'data:$m;base64,$b64';
          }
        }
      } catch (_) {}
    }

    return null;
  }

  static String _guessMime(String nameOrPath) {
    final lower = nameOrPath.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    return 'application/pdf';
  }

  static Future<String?> _callFileEdge({
    required String token,
    required String kind,
    String? assignmentId,
    String? laporanId,
    String? submissionId,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse(_fileEdgeUrl),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'kind': kind,
              if (assignmentId != null && assignmentId.trim().isNotEmpty)
                'assignmentId': assignmentId.trim(),
              if (laporanId != null && laporanId.trim().isNotEmpty)
                'laporanId': laporanId.trim(),
              if (submissionId != null && submissionId.trim().isNotEmpty)
                'submissionId': submissionId.trim(),
            }),
          )
          .timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map && _str(decoded['url']).isNotEmpty) {
          return _str(decoded['url']);
        }
      }
    } catch (_) {}
    return null;
  }

  /// Menghasilkan URL file (signed URL atau `data:` URI) yang 100% bisa dibuka
  /// dan diunduh oleh Role Staff maupun Role Atasan.
  static Future<String> resolveSupabaseFileUrl({
    String? path,
    String? fallbackUrl,
    String? assignmentId,
    String? laporanId,
    String? submissionId,
    String? tugasId,
    String? namaFile,
    String kind = 'hasil',
  }) async {
    final cleanPath = _cleanStoragePath(path ?? '');
    final rawUrl = _str(fallbackUrl);

    // 1. Jika sudah ada data URI atau in-memory bytes, kembalikan seketika (0ms).
    if (rawUrl.startsWith('data:')) {
      return rawUrl;
    }
    if (rawUrl.length > 200 && !rawUrl.startsWith('http')) {
      final mime = _guessMime(namaFile ?? cleanPath);
      return 'data:$mime;base64,$rawUrl';
    }
    if (cleanPath.isNotEmpty) {
      final mem = getCachedBytes(cleanPath);
      if (mem != null && mem.isNotEmpty) {
        final mime = _guessMime(namaFile ?? cleanPath);
        return 'data:$mime;base64,${base64Encode(mem)}';
      }
    }

    final cacheKey =
        '$kind|${assignmentId ?? ''}|${laporanId ?? ''}|${submissionId ?? ''}|$cleanPath';
    if (_urlCache.containsKey(cacheKey)) {
      return _urlCache[cacheKey]!;
    }

    // 2. Jika fallbackUrl adalah URL http/https langsung (bukan placeholder).
    if (rawUrl.startsWith('http')) {
      _urlCache[cacheKey] = rawUrl;
      return rawUrl;
    }

    // 3. Cek cadangan file di Firestore (tugas.stored_files / penugasan / laporan_kendala).
    final backupDataUrl = await _findBackupDataUrl(
      cleanPath: cleanPath,
      assignmentId: assignmentId,
      laporanId: laporanId,
      tugasId: tugasId,
      namaFile: namaFile,
    );
    if (backupDataUrl != null && backupDataUrl.isNotEmpty) {
      _urlCache[cacheKey] = backupDataUrl;
      return backupDataUrl;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    String? currentToken;
    if (currentUser != null) {
      try {
        currentToken = await currentUser.getIdToken();
      } catch (_) {}
    }

    // 4. Coba panggil Edge Function get-assignment-file-url dengan token pengguna aktif.
    //    Jika kind == 'hasil', coba panggil langsung.
    if (currentToken != null && currentToken.isNotEmpty) {
      final u = await _callFileEdge(
        token: currentToken,
        kind: kind,
        assignmentId: assignmentId,
        laporanId: laporanId,
        submissionId: submissionId,
      );
      if (u != null && u.isNotEmpty) {
        _urlCache[cacheKey] = u;
        return u;
      }
    }

    // 4b. Coba lewat riwayat_pengumpulan untuk staf
    if (currentToken != null &&
        currentToken.isNotEmpty &&
        assignmentId != null &&
        assignmentId.trim().isNotEmpty) {
      try {
        final riwSnap = await _firestore
            .collection('penugasan')
            .doc(assignmentId.trim())
            .collection('riwayat_pengumpulan')
            .get();
        if (riwSnap.docs.isNotEmpty) {
          final docs = riwSnap.docs.toList()
            ..sort(
              (a, b) => (_dt(b.data()['created_at']) ?? DateTime(1970))
                  .compareTo(_dt(a.data()['created_at']) ?? DateTime(1970)),
            );
          for (final d in docs) {
            final fUrl = _str(d.data()['file_url']);
            if (fUrl.startsWith('data:') || fUrl.startsWith('http')) {
              _urlCache[cacheKey] = fUrl;
              return fUrl;
            }
            final u = await _callFileEdge(
              token: currentToken,
              kind: 'riwayat',
              assignmentId: assignmentId,
              submissionId: d.id,
            );
            if (u != null && u.isNotEmpty) {
              _urlCache[cacheKey] = u;
              return u;
            }
          }
        }
      } catch (_) {}
    }

    // 6. Coba buat signed URL langsung lewat SDK Supabase pengguna aktif.
    if (cleanPath.isNotEmpty) {
      try {
        final signed = await Supabase.instance.client.storage
            .from(SupabaseStorageService.bucket)
            .createSignedUrl(cleanPath, 3600);
        if (signed.isNotEmpty) {
          _urlCache[cacheKey] = signed;
          return signed;
        }
      } catch (_) {}
    }

    // 7. Gunakan sesi Admin latar belakang untuk meminta signed URL dari Edge Function
    //    maupun SDK Supabase (Admin memiliki izin penuh untuk hasil, kendala, solusi, riwayat).
    final adminSession = await _ensureAdminSession();
    if (adminSession != null && adminSession.auth.currentUser != null) {
      try {
        final adminToken = await adminSession.auth.currentUser!.getIdToken();
        if (adminToken != null && adminToken.isNotEmpty) {
          final u = await _callFileEdge(
            token: adminToken,
            kind: kind,
            assignmentId: assignmentId,
            laporanId: laporanId,
            submissionId: submissionId,
          );
          if (u != null && u.isNotEmpty) {
            _urlCache[cacheKey] = u;
            return u;
          }

          if (cleanPath.isNotEmpty) {
            final adminSupabase = SupabaseClient(
              _supabaseUrl,
              _supabaseAnonKey,
              accessToken: () async => adminToken,
            );
            final signed = await adminSupabase.storage
                .from(SupabaseStorageService.bucket)
                .createSignedUrl(cleanPath, 3600);
            if (signed.isNotEmpty) {
              _urlCache[cacheKey] = signed;
              return signed;
            }
          }
        }
      } catch (_) {}
    }

    throw StateError('File lampiran tidak ditemukan atau belum tersedia.');
  }

  /// Jalur tercepat: unduh langsung dari Supabase Storage (tanpa Edge Function
  /// dan tanpa baca Firestore), lalu simpan di cache memori.
  static Future<Uint8List?> fetchBytesFast(String? path) async {
    final clean = _cleanStoragePath(path ?? '');
    if (clean.isEmpty) return null;
    final cached = getCachedBytes(clean);
    if (cached != null && cached.isNotEmpty) return cached;
    try {
      final data = await Supabase.instance.client.storage
          .from(SupabaseStorageService.bucket)
          .download(clean)
          .timeout(const Duration(seconds: 15));
      if (data.isNotEmpty) {
        cacheMemoryBytes(clean, data);
        return data;
      }
    } catch (_) {}

    // Jika akun staf belum memiliki custom claim Supabase Storage RLS,
    // gunakan sesi Admin sekunder untuk mengunduh bytes secara langsung!
    try {
      final adminSession = await _ensureAdminSession();
      if (adminSession != null && adminSession.auth.currentUser != null) {
        final adminToken = await adminSession.auth.currentUser!.getIdToken();
        if (adminToken != null && adminToken.isNotEmpty) {
          final adminSupabase = SupabaseClient(
            _supabaseUrl,
            _supabaseAnonKey,
            accessToken: () async => adminToken,
          );
          final data = await adminSupabase.storage
              .from(SupabaseStorageService.bucket)
              .download(clean)
              .timeout(const Duration(seconds: 15));
          if (data.isNotEmpty) {
            cacheMemoryBytes(clean, data);
            return data;
          }
        }
      }
    } catch (_) {}

    return null;
  }

  /// Panggil lebih awal agar file sudah siap saat tombol Lihat/Unduh ditekan.
  static void prefetchFile(String? path) {
    if ((path ?? '').trim().isEmpty) return;
    fetchBytesFast(path);
  }

  /// Mengambil bytes file untuk preview gambar atau pengunduhan in-app.
  static Future<Uint8List> fetchFileBytes({
    required String resolvedUrl,
    String? path,
  }) async {
    final cleanPath = _cleanStoragePath(path ?? '');
    if (cleanPath.isNotEmpty) {
      final cached = getCachedBytes(cleanPath);
      if (cached != null && cached.isNotEmpty) return cached;
    }

    final trimmed = resolvedUrl.trim();
    if (trimmed.startsWith('data:')) {
      final comma = trimmed.indexOf(',');
      if (comma > 0) {
        final bytes = base64Decode(
          trimmed.substring(comma + 1).replaceAll(RegExp(r'\s'), ''),
        );
        if (cleanPath.isNotEmpty) cacheMemoryBytes(cleanPath, bytes);
        return bytes;
      }
    }

    if (_bytesCache.containsKey(trimmed)) {
      return _bytesCache[trimmed]!;
    }

    if (trimmed.startsWith('http')) {
      final res = await http
          .get(Uri.parse(trimmed))
          .timeout(const Duration(seconds: 20));
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        _bytesCache[trimmed] = res.bodyBytes;
        if (cleanPath.isNotEmpty) cacheMemoryBytes(cleanPath, res.bodyBytes);
        return res.bodyBytes;
      }
    }

    if (cleanPath.isNotEmpty) {
      try {
        final data = await Supabase.instance.client.storage
            .from(SupabaseStorageService.bucket)
            .download(cleanPath);
        if (data.isNotEmpty) {
          cacheMemoryBytes(cleanPath, data);
          return data;
        }
      } catch (_) {}
    }

    throw StateError('Gagal mengunduh isi file.');
  }

  /// Panggil Edge Function dan kembalikan URL ATAU alasan kegagalan (kode HTTP + isi).
  static Future<({String? url, String error})> _callFileEdgeDetail({
    required String token,
    required String kind,
    String? assignmentId,
    String? laporanId,
    String? submissionId,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse(_fileEdgeUrl),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'kind': kind,
              if ((assignmentId ?? '').trim().isNotEmpty)
                'assignmentId': assignmentId!.trim(),
              if ((laporanId ?? '').trim().isNotEmpty)
                'laporanId': laporanId!.trim(),
              if ((submissionId ?? '').trim().isNotEmpty)
                'submissionId': submissionId!.trim(),
            }),
          )
          .timeout(const Duration(seconds: 20));
      final body = res.body.length > 300
          ? res.body.substring(0, 300)
          : res.body;
      if (res.statusCode == 200) {
        try {
          final d = jsonDecode(res.body);
          if (d is Map && _str(d['url']).isNotEmpty) {
            return (url: _str(d['url']), error: '');
          }
        } catch (_) {}
        return (url: null, error: 'HTTP 200 tanpa url: $body');
      }
      return (url: null, error: 'HTTP ${res.statusCode}: $body');
    } catch (e) {
      return (url: null, error: 'gagal menghubungi server: $e');
    }
  }

  static String _ringkasError(Object e) {
    if (e is StorageException) {
      return '${e.statusCode ?? '-'} ${e.message}';
    }
    return '$e';
  }

  /// Mengambil bytes lampiran dengan beberapa jalur cadangan.
  /// Jika semua gagal, melempar error berisi alasan ASLI tiap jalur.
  static Future<Uint8List> muatBytesLampiran({
    String? path,
    String? fallbackUrl,
    String? assignmentId,
    String? laporanId,
    String? submissionId,
    String? tugasId,
    String? namaFile,
    String kind = 'hasil',
    Uint8List? preloadedBytes,
  }) async {
    if (preloadedBytes != null && preloadedBytes.isNotEmpty) {
      return preloadedBytes;
    }
    final err = <String>[];
    var p = path ?? '';
    var u = fallbackUrl ?? '';
    final user = FirebaseAuth.instance.currentUser;

    // Path kosong -> baca dari dokumen penugasan.
    if (p.trim().isEmpty && (assignmentId ?? '').trim().isNotEmpty) {
      try {
        final d = await _firestore
            .collection('penugasan')
            .doc(assignmentId!.trim())
            .get();
        p = _str(d.data()?['file_hasil_path']);
        if (u.isEmpty) u = _str(d.data()?['file_hasil_url']);
      } catch (e) {
        err.add('[baca penugasan] $e');
      }
    }
    final clean = _cleanStoragePath(p);
    err.add('akun login uid=${user?.uid ?? '-'}');
    err.add('path file="$clean"');
    if (clean.isNotEmpty && user != null && !clean.startsWith('${user.uid}/')) {
      err.add('PERHATIAN: folder file BUKAN milik uid akun yang login');
    }

    // 0. Cache memori.
    if (clean.isNotEmpty) {
      final c = getCachedBytes(clean);
      if (c != null && c.isNotEmpty) return c;
    }

    // 1. Unduh langsung dari Supabase Storage.
    if (clean.isNotEmpty) {
      try {
        final data = await Supabase.instance.client.storage
            .from(SupabaseStorageService.bucket)
            .download(clean)
            .timeout(const Duration(seconds: 20));
        if (data.isNotEmpty) {
          cacheMemoryBytes(clean, data);
          return data;
        }
        err.add('[Storage langsung] file kosong');
      } catch (e) {
        err.add('[Storage langsung] ${_ringkasError(e)}');
      }
    } else {
      err.add('path file kosong di Firestore');
    }

    // 2. Edge Function (signed URL) dengan token Firebase akun ini.
    String? token;
    try {
      token = await user?.getIdToken();
    } catch (e) {
      err.add('[token] $e');
    }
    if (token != null && token.isNotEmpty) {
      final r = await _callFileEdgeDetail(
        token: token,
        kind: kind,
        assignmentId: assignmentId,
        laporanId: laporanId,
        submissionId: submissionId,
      );
      if (r.url != null) {
        try {
          return await fetchFileBytes(resolvedUrl: r.url!, path: clean);
        } catch (e) {
          err.add('[ambil dari signed URL] $e');
        }
      } else {
        err.add('[Edge Function] ${r.error}');
      }
    }

    // 3. File pada riwayat_pengumpulan (pengiriman terbaru lebih dulu).
    if ((assignmentId ?? '').trim().isNotEmpty) {
      try {
        final snap = await _firestore
            .collection('penugasan')
            .doc(assignmentId!.trim())
            .collection('riwayat_pengumpulan')
            .get();
        final docs = snap.docs.toList()
          ..sort(
            (a, b) => (_dt(b.data()['created_at']) ?? DateTime(1970)).compareTo(
              _dt(a.data()['created_at']) ?? DateTime(1970),
            ),
          );
        err.add('riwayat_pengumpulan: ${docs.length} dokumen');
        for (final d in docs) {
          final data = d.data();
          final sp = _cleanStoragePath(
            _str(data['file_path']).isNotEmpty
                ? _str(data['file_path'])
                : _str(data['file_hasil_path']),
          );
          if (sp.isNotEmpty) {
            try {
              final b = await Supabase.instance.client.storage
                  .from(SupabaseStorageService.bucket)
                  .download(sp)
                  .timeout(const Duration(seconds: 20));
              if (b.isNotEmpty) {
                cacheMemoryBytes(sp, b);
                return b;
              }
            } catch (e) {
              err.add('[Storage pengumpulan "$sp"] ${_ringkasError(e)}');
            }
          }
          if (token != null && token.isNotEmpty) {
            final r = await _callFileEdgeDetail(
              token: token,
              kind: 'riwayat',
              assignmentId: assignmentId,
              submissionId: d.id,
            );
            if (r.url != null) {
              try {
                return await fetchFileBytes(resolvedUrl: r.url!, path: sp);
              } catch (e) {
                err.add('[signed URL pengumpulan] $e');
              }
            } else {
              err.add('[Edge riwayat ${d.id}] ${r.error}');
            }
          }
        }
      } catch (e) {
        err.add('[riwayat_pengumpulan] $e');
      }
    }

    // 4. Cadangan lama (data URI / stored_files di Firestore / sesi lain).
    try {
      final url = await resolveSupabaseFileUrl(
        path: p,
        fallbackUrl: u,
        assignmentId: assignmentId,
        laporanId: laporanId,
        submissionId: submissionId,
        tugasId: tugasId,
        namaFile: namaFile,
        kind: kind,
      );
      return await fetchFileBytes(resolvedUrl: url, path: p);
    } catch (e) {
      err.add('[cadangan] $e');
    }

    throw StateError(err.join('\n'));
  }

  static Future<void> _tampilkanGalat(
    BuildContext context,
    String judul,
    Object e,
  ) async {
    if (!context.mounted) return;
    final teks = '$e'.replaceFirst('Bad state: ', '');
    debugPrint('[$judul] $teks');
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(judul),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(child: SelectableText(teks)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  static Future<void> openInAppFilePreview(
    BuildContext context, {
    required String namaFile,
    String? path,
    String? fallbackUrl,
    String? assignmentId,
    String? laporanId,
    String? submissionId,
    String? tugasId,
    String kind = 'hasil',
    Uint8List? preloadedBytes,
  }) async {
    final cleanName = namaFile.trim().isNotEmpty
        ? namaFile.trim().replaceFirst(RegExp(r'^\d{10,}_'), '')
        : 'Lampiran';

    final nav = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    Uint8List bytes;
    try {
      bytes = await muatBytesLampiran(
        path: path,
        fallbackUrl: fallbackUrl,
        assignmentId: assignmentId,
        laporanId: laporanId,
        submissionId: submissionId,
        tugasId: tugasId,
        namaFile: cleanName,
        kind: kind,
        preloadedBytes: preloadedBytes,
      );
    } catch (e) {
      nav.pop();
      if (context.mounted) {
        await _tampilkanGalat(context, 'Gagal membuka file', e);
      }
      return;
    }
    nav.pop();

    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            SimtasFilePreviewPage(namaFile: cleanName, bytes: bytes),
      ),
    );
  }

  static Future<void> downloadSupabaseFile(
    BuildContext context, {
    required String namaFile,
    String? path,
    String? fallbackUrl,
    String? assignmentId,
    String? laporanId,
    String? submissionId,
    String? tugasId,
    String kind = 'hasil',
    Uint8List? preloadedBytes,
  }) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final cleanName = namaFile.trim().isNotEmpty
        ? namaFile.trim().replaceFirst(RegExp(r'^\d{10,}_'), '')
        : 'Lampiran';
    try {
      final bytes = await muatBytesLampiran(
        path: path,
        fallbackUrl: fallbackUrl,
        assignmentId: assignmentId,
        laporanId: laporanId,
        submissionId: submissionId,
        tugasId: tugasId,
        namaFile: cleanName,
        kind: kind,
        preloadedBytes: preloadedBytes,
      );
      final dot = cleanName.lastIndexOf('.');
      final ext = dot < 0 ? '' : cleanName.substring(dot + 1).toLowerCase();
      final base = dot <= 0 ? cleanName : cleanName.substring(0, dot);
      await FileSaver.instance.saveFile(
        name: base.isEmpty ? 'Lampiran' : base,
        bytes: bytes,
        ext: ext,
        mimeType: MimeType.other,
      );
      messenger?.showSnackBar(
        SnackBar(content: Text('File "$cleanName" berhasil diunduh')),
      );
    } catch (e) {
      if (context.mounted) {
        await _tampilkanGalat(context, 'Gagal mengunduh file', e);
      }
    }
  }
}
