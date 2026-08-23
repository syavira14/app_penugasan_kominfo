import 'package:flutter/material.dart';
import 'pages/auth/welcome_page.dart';
// Import file StaffMainPage yang ada di folder staff
import 'pages/staff/staff_main_page.dart';

void main() {
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
      debugShowCheckedModeBanner: false,
      title: 'Aplikasi Kominfo Staff',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Poppins', // Sesuaikan jika kamu pakai font kustom
      ),
      // Set Halaman Utama/Awal langsung ke Navbar Staff
      home: const StaffMainPage(),
    );
  }
}
