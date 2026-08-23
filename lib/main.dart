import 'package:flutter/material.dart';
import 'pages/auth/welcome_page.dart';

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