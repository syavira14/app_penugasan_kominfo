import 'package:flutter/material.dart';

class SimtasPdfWebView extends StatelessWidget {
  final String url;
  const SimtasPdfWebView({super.key, required this.url});

  @override
  Widget build(BuildContext context) => const Center(
    child: Text('Preview PDF browser hanya tersedia di Flutter Web.'),
  );
}
