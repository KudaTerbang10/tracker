import 'dart:async';
import 'package:flutter/material.dart';

class HomeSection extends StatefulWidget {
  final bool isMobile;
  final VoidCallback? onKirimSekarang;
  const HomeSection({super.key, required this.isMobile, this.onKirimSekarang});

  @override
  State<HomeSection> createState() => HomeSectionState();
}

class HomeSectionState extends State<HomeSection>
    with SingleTickerProviderStateMixin {
  final _pageController = PageController();
  final _carouselImages = [
    'assets/pics/beranda1.webp',
    'assets/pics/beranda2.webp',
    'assets/pics/beranda3.webp',
    'assets/pics/beranda4.webp',
  ];
  int _currentPage = 0;
  Timer? _carouselTimer;
  late final AnimationController _heroCtrl;

  @override
  void initState() {
    super.initState();
    _heroCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startCarousel());
  }

  void restartHero() {
    _heroCtrl.forward(from: 0.0);
  }

  void _startCarousel() {
    _carouselTimer?.cancel();
    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_pageController.hasClients) return;
      final current = _pageController.page!.round();
      final next = (current + 1) % _carouselImages.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _heroCtrl.dispose();
    _carouselTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Widget _fadeSlide(Widget child, {required double delay}) {
    final end = (delay + 0.35).clamp(0.0, 1.0);
    final curve = Interval(delay, end, curve: Curves.easeOut);
    return AnimatedBuilder(
      animation: _heroCtrl,
      builder: (context, child) {
        final progress = curve.transform(_heroCtrl.value);
        return Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: Offset(0, 24 * (1 - progress)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.isMobile ? _buildMobile() : _buildWeb(context);
  }

  Widget _buildCarousel({double? height}) {
    final h = height ?? (widget.isMobile ? 360.0 : 520.0);
    return SizedBox(
      height: h,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemCount: _carouselImages.length,
            itemBuilder: (context, index) => Image.asset(
              _carouselImages[index],
              width: double.infinity,
              height: h,
              fit: BoxFit.cover,
              alignment: const Alignment(0.15, 0.0),
              errorBuilder: (context, error, stackTrace) => Container(
                color: Colors.grey.shade200,
                child: const Center(
                  child: Icon(
                    Icons.image_not_supported,
                    size: 50,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
          ),
          Container(
            height: h,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.55),
                  Colors.black.withValues(alpha: 0.25),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          // Left chevron
          Positioned(
            left: 8,
            top: 0,
            bottom: 0,
            child: Center(
              child: GestureDetector(
                onTap: () {
                  if (!_pageController.hasClients) return;
                  final prev =
                      (_currentPage - 1 + _carouselImages.length) %
                      _carouselImages.length;
                  _pageController.animateToPage(
                    prev,
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                  );
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chevron_left,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
          // Right chevron
          Positioned(
            right: 8,
            top: 0,
            bottom: 0,
            child: Center(
              child: GestureDetector(
                onTap: () {
                  if (!_pageController.hasClients) return;
                  final next = (_currentPage + 1) % _carouselImages.length;
                  _pageController.animateToPage(
                    next,
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                  );
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chevron_right,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _carouselImages.length,
                (i) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == i ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == i
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobile() {
    final screenHeight = MediaQuery.of(context).size.height;
    final targetHeight =
        screenHeight - kToolbarHeight - MediaQuery.of(context).padding.top;
    return SizedBox(
      height: targetHeight,
      child: Stack(
        children: [
          _buildCarousel(height: targetHeight),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  SizedBox(height: targetHeight * 0.2),
                  _fadeSlide(
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/pics/hiralogo.webp',
                        width: 48,
                        height: 48,
                      ),
                    ),
                    delay: 0.417,
                  ),
                  const SizedBox(height: 12),
                  _fadeSlide(
                    const Text(
                      'Hira Express',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        fontSize: 28,
                        letterSpacing: -0.5,
                      ),
                    ),
                    delay: 0.542,
                  ),
                  const SizedBox(height: 4),
                  _fadeSlide(
                    const Text(
                      'Berat di timbang, ringan di kantong.',
                      style: TextStyle(color: Colors.white70, fontSize: 15),
                      textAlign: TextAlign.center,
                    ),
                    delay: 0.667,
                  ),
                  _fadeSlide(
                    const Text(
                      'Solusi logistik terpercaya untuk kebutuhan pengiriman Anda.',
                      style: TextStyle(color: Colors.white70, fontSize: 15),
                      textAlign: TextAlign.center,
                    ),
                    delay: 0.667,
                  ),
                  const SizedBox(height: 20),
                  _fadeSlide(
                    ElevatedButton(
                      onPressed: widget.onKirimSekarang,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 50),
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF0F172A),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                      ),
                      child: const Text('Kirim Sekarang'),
                    ),
                    delay: 0.792,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeb(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final carouselHeight = screenHeight - kToolbarHeight;

    return Stack(
      children: [
        SizedBox(
          height: carouselHeight,
          child: _buildCarousel(height: carouselHeight),
        ),
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 64),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _fadeSlide(
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 12,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Image.asset(
                                'assets/pics/hiralogo.webp',
                                width: 80,
                                height: 80,
                              ),
                            ),
                            delay: 0.417,
                          ),
                          const SizedBox(height: 24),
                          _fadeSlide(
                            const Text(
                              'Hira Express',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                fontSize: 42,
                                letterSpacing: -1,
                              ),
                            ),
                            delay: 0.542,
                          ),
                          const SizedBox(height: 12),
                          _fadeSlide(
                            const Text(
                              'Berat di timbang, ringan di kantong. Solusi logistik terpercaya untuk kebutuhan pengiriman Anda.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 17,
                                height: 1.6,
                              ),
                            ),
                            delay: 0.667,
                          ),
                          const SizedBox(height: 24),
                          _fadeSlide(
                            ElevatedButton(
                              onPressed: widget.onKirimSekarang,
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(0, 50),
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF0F172A),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 32),
                              ),
                              child: const Text('Kirim Sekarang'),
                            ),
                            delay: 0.792,
                          ),
                        ],
                      ),
                    ),
                    const Spacer(flex: 1),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
