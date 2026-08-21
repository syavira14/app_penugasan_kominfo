import 'package:flutter/material.dart';
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
