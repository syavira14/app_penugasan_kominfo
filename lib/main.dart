import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // Tambahkan ini
import 'firebase_options.dart'; // Tambahkan ini
import 'pages/auth/welcome_page.dart';

void main() async {
  // Wajib ditambahkan agar binding Flutter siap sebelum memanggil Firebase
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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
