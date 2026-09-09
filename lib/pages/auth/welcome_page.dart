import 'dart:async';
import 'package:flutter/material.dart';
import 'login_page.dart';

/// ============================================================
/// SIMTAS - WELCOME & ONBOARDING
/// Sistem Informasi Manajemen Tugas dan Staff
/// ============================================================

class AppColors {
  // Warna bernuansa identitas Kominfo
  static const Color navy = Color(0xFF003B7A);
  static const Color blue = Color(0xFF0056B3);
  static const Color blueLight = Color(0xFF1976D2);
  static const Color cyan = Color(0xFF00AEEF);

  static const Color background = Color(0xFFF7FAFE);
  static const Color textDark = Color(0xFF172B4D);
  static const Color textGrey = Color(0xFF667085);
  static const Color white = Colors.white;
}

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final PageController _pageController = PageController();

  int _currentPage = 0;

  // ============================================================
  // DATA ONBOARDING
  // ============================================================

  final List<OnboardingData> _pages = [
    OnboardingData(
      icon: Icons.assignment_rounded,
      title: 'Kelola Penugasan\nDengan Mudah',
      description:
          'Atasan dapat membuat dan memberikan tugas kepada staff secara cepat dan terstruktur.',
      color: AppColors.blue,
    ),
    OnboardingData(
      icon: Icons.calendar_month_rounded,
      title: 'Atur Jadwal Kerja\nSecara Terencana',
      description:
          'Susun dan kelola jadwal penugasan agar pekerjaan berjalan sesuai waktu yang telah ditentukan.',
      color: AppColors.blueLight,
    ),
    OnboardingData(
      icon: Icons.bar_chart_rounded,
      title: 'Pantau Tugas\nSecara Teratur',
      description:
          'Pantau status dan perkembangan tugas sehingga pekerjaan dapat dikontrol dengan lebih mudah.',
      color: AppColors.cyan,
    ),
    OnboardingData(
      icon: Icons.groups_rounded,
      title: 'Bekerja Lebih Terstruktur,\nTim Lebih Produktif',
      description:
          'SIMTAS membantu atasan dan staff mengelola penugasan serta jadwal kerja secara lebih efisien.',
      color: AppColors.navy,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ============================================================
  // PINDAH HALAMAN
  // ============================================================

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _goToLogin();
    }
  }

  void _goToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ====================================================
            // HEADER
            // ====================================================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // LOGO MINI SIMTAS
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.navy, AppColors.blueLight],
                          ),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: const Icon(
                          Icons.assignment_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'SIMTAS',
                        style: TextStyle(
                          color: AppColors.navy,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),

                  // LEWATI
                  if (_currentPage < _pages.length - 1)
                    TextButton(
                      onPressed: _goToLogin,
                      child: const Text(
                        'Lewati',
                        style: TextStyle(
                          color: AppColors.textGrey,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ====================================================
            // PAGE VIEW
            // ====================================================
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  return _buildOnboardingPage(_pages[index], index);
                },
              ),
            ),

            // ====================================================
            // BOTTOM NAVIGATION
            // ====================================================
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 28),
              child: Column(
                children: [
                  // DOT INDICATOR
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == index ? 26 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? AppColors.blue
                              : const Color(0xFFD6DFEA),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 26),

                  // BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.navy,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _currentPage == _pages.length - 1
                                ? 'Mulai Sekarang'
                                : 'Lanjutkan',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Icon(
                            _currentPage == _pages.length - 1
                                ? Icons.arrow_forward_rounded
                                : Icons.arrow_forward_rounded,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // FOOTER
                  const Text(
                    'Sistem Informasi Manajemen Tugas dan Staff',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textGrey, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ONBOARDING PAGE
  // ============================================================

  Widget _buildOnboardingPage(OnboardingData data, int index) {
    final bool isLastPage = index == _pages.length - 1;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 8),

            // ==================================================
            // ILUSTRASI / ICON AREA
            // ==================================================
            SizedBox(
              height: 320,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // LINGKARAN BESAR
                  Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: data.color.withOpacity(0.07),
                    ),
                  ),

                  // LINGKARAN SEDANG
                  Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: data.color.withOpacity(0.09),
                    ),
                  ),

                  // ICON CARD
                  Container(
                    width: 145,
                    height: 145,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(36),
                      boxShadow: [
                        BoxShadow(
                          color: data.color.withOpacity(0.16),
                          blurRadius: 35,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // ICON
                        Container(
                          width: 92,
                          height: 92,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                data.color,
                                data.color.withOpacity(0.72),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: Icon(data.icon, color: Colors.white, size: 52),
                        ),

                        // AKSEN CHECK
                        if (index == 0)
                          Positioned(
                            right: 10,
                            top: 10,
                            child: _smallBadge(
                              Icons.check_rounded,
                              AppColors.cyan,
                            ),
                          ),

                        // AKSEN CLOCK
                        if (index == 1)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: _smallBadge(
                              Icons.access_time_rounded,
                              AppColors.cyan,
                            ),
                          ),

                        // AKSEN MONITORING
                        if (index == 2)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: _smallBadge(
                              Icons.trending_up_rounded,
                              AppColors.cyan,
                            ),
                          ),

                        // AKSEN TEAM
                        if (index == 3)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: _smallBadge(
                              Icons.people_alt_rounded,
                              AppColors.cyan,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // DECORATIVE DOTS
                  Positioned(
                    left: 20,
                    top: 55,
                    child: _dotDecoration(data.color),
                  ),

                  Positioned(
                    right: 15,
                    bottom: 45,
                    child: _dotDecoration(data.color),
                  ),

                  // DECORATIVE SMALL CIRCLE
                  Positioned(
                    left: 50,
                    bottom: 35,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: data.color.withOpacity(0.35),
                          width: 2,
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    right: 45,
                    top: 30,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: data.color.withOpacity(0.25),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ==================================================
            // BADGE
            // ==================================================
            if (!isLastPage)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: data.color.withOpacity(0.09),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  'FITUR SIMTAS',
                  style: TextStyle(
                    color: data.color,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),

            if (!isLastPage) const SizedBox(height: 18),

            // ==================================================
            // TITLE
            // ==================================================
            Text(
              data.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textDark,
                fontSize: 25,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),

            const SizedBox(height: 14),

            // ==================================================
            // DESCRIPTION
            // ==================================================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                data.description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textGrey,
                  fontSize: 14,
                  height: 1.65,
                ),
              ),
            ),

            // ==================================================
            // LAST PAGE EXTRA
            // ==================================================
            if (isLastPage) ...[
              const SizedBox(height: 22),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _featureMini(Icons.assignment_turned_in_rounded, 'Penugasan'),
                  const SizedBox(width: 10),
                  _featureMini(Icons.calendar_today_rounded, 'Jadwal'),
                  const SizedBox(width: 10),
                  _featureMini(Icons.analytics_rounded, 'Monitoring'),
                ],
              ),
            ],

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SMALL BADGE
  // ============================================================

  Widget _smallBadge(IconData icon, Color color) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color.withOpacity(0.25), blurRadius: 10)],
      ),
      child: Icon(icon, color: color, size: 17),
    );
  }

  // ============================================================
  // DOT DECORATION
  // ============================================================

  Widget _dotDecoration(Color color) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: List.generate(
          9,
          (index) => Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: color.withOpacity(0.28),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // MINI FEATURE
  // ============================================================

  Widget _featureMini(IconData icon, String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4EAF2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.blue),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// MODEL ONBOARDING
// ============================================================

class OnboardingData {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  OnboardingData({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}
