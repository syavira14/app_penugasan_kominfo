
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'firebase_options.dart';
import 'pages/auth/welcome_page.dart';

// Mode emulator diaktifkan melalui --dart-define.
const bool useFirebaseEmulator = bool.fromEnvironment(
  'USE_FIREBASE_EMULATOR',
  defaultValue: false,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Inisialisasi Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 2. Konfigurasi Firebase Emulator
  if (useFirebaseEmulator) {
    // Untuk Android Emulator gunakan 10.0.2.2.
    // Untuk Chrome/Windows gunakan localhost.
    final String emulatorHost =
        defaultTargetPlatform == TargetPlatform.android && !kIsWeb
            ? '10.0.2.2'
            : 'localhost';

    await FirebaseAuth.instance.useAuthEmulator(
      emulatorHost,
      9099,
    );

    FirebaseFirestore.instance.useFirestoreEmulator(
      emulatorHost,
      8080,
    );

    debugPrint('====================================');
    debugPrint('FIREBASE EMULATOR AKTIF');
    debugPrint('Authentication: $emulatorHost:9099');
    debugPrint('Firestore: $emulatorHost:8080');
    debugPrint('====================================');
  } else {
    debugPrint('Firebase menggunakan server asli.');
  }

  // 3. Inisialisasi Supabase
  await Supabase.initialize(
    url: 'https://uxdloenucntsmcviskfo.supabase.co',
    anonKey: 'sb_publishable_wgHJYNJa0o7z5hNY7eNGKQ_T7z4gr5-',
    accessToken: () async {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        return null;
      }

      return await user.getIdToken();
    },
  );

  // 4. Jalankan aplikasi
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sistem Penjadwalan Penugasan Pegawai',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF0011CC),
        fontFamily: 'Roboto',
      ),
      home: const WelcomePage(),
    );
  }
}
