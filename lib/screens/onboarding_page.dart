import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

class OnboardingPage extends StatefulWidget {
  final VoidCallback onFinish;
  const OnboardingPage({Key? key, required this.onFinish}) : super(key: key);

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage>
    with SingleTickerProviderStateMixin {
  int _pageIndex = 0;
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  final List<Map<String, String>> _pages = [
    {
      'title': 'Selamat Datang di Daily Planner!',
      'desc': 'Aplikasi manajemen tugas harian modern, offline & online.',
      'img': 'assets/empty_tasks.svg',
    },
    {
      'title': 'Widget Android',
      'desc': 'Lihat dan tambah task langsung dari home screen.',
      'img': 'assets/empty_task.svg',
    },
    {
      'title': 'Offline Mode',
      'desc': 'Tambah/edit task walau tanpa internet, auto sync saat online.',
      'img': 'assets/empty_tasks.svg',
    },
    {
      'title': 'Custom Avatar & Gravatar',
      'desc': 'Pilih avatar sendiri atau gunakan Gravatar dengan style unik.',
      'img': 'assets/empty_task.svg',
    },
    {
      'title': 'Ayo mulai produktif!',
      'desc': 'Klik mulai untuk menggunakan aplikasi.',
      'img': 'assets/empty_tasks.svg',
    },
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() async {
    if (_pageIndex < _pages.length - 1) {
      _controller.reverse().then((_) {
        setState(() => _pageIndex++);
        _controller.forward();
      });
    } else {
      final box = await Hive.openBox('settings');
      await box.put('onboarding_done', true);
      widget.onFinish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_pageIndex];
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF8AB4F8), Color(0xFF3C5A99)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SvgPicture.asset(page['img']!, height: 160),
                    const SizedBox(height: 32),
                    Text(
                      page['title']!,
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      page['desc']!,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        color: Colors.white70,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF3C5A99),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        onPressed: _next,
                        child: Text(
                          _pageIndex == _pages.length - 1 ? 'Mulai' : 'Lanjut',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _pages.length,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: i == _pageIndex ? 18 : 10,
                          height: 10,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color: i == _pageIndex
                                ? Colors.white
                                : Colors.white24,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
