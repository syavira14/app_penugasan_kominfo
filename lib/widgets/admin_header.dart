import 'package:flutter/material.dart';

class AdminHeader extends StatelessWidget {
  final String title;
  final bool showSidebar;

  const AdminHeader({
    super.key,
    required this.title,
    required this.showSidebar,
  });

  // Palet warna konsisten
  static const Color navy = Color(0xFF1A1464);
  static const Color blue = Color(0xFF1D5FA0);
  static const Color sky = Color(0xFF4FA6DE);

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double scale = (screenWidth / 375).clamp(0.85, 1.25);

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [navy, blue, sky],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: showSidebar ? 28 * scale : 16 * scale,
            vertical: 18 * scale,
          ),
          child: Row(
            children: [
              // Di HP (Drawer Mobile): Tampilkan tombol Hamburger Menu
              if (!showSidebar) ...[
                Builder(
                  builder: (ctx) => IconButton(
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      Icons.menu_rounded,
                      color: Colors.white,
                      size: 26 * scale,
                    ),
                  ),
                ),
                SizedBox(width: 12 * scale),
              ],

              // Judul & Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: showSidebar ? 22 * scale : 18 * scale,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4 * scale),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
