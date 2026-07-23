import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

import 'landing_sections/home_section.dart';
import 'landing_sections/cek_resi_section.dart';
import 'landing_sections/cabang_section.dart';
import 'landing_sections/cek_tarif_section.dart';
import 'landing_sections/info_sections.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});
  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final _scrollController = ScrollController();
  bool _showScrollTop = false;

  final _homeKey = GlobalKey();
  final _cekResiKey = GlobalKey();
  final _cabangKey = GlobalKey();
  final _cekTarifKey = GlobalKey();
  final _aboutKey = GlobalKey();
  final _servicesKey = GlobalKey();
  final _contactKey = GlobalKey();

  // Ref ke CabangSection agar bisa trigger cari lokasi dari navbar/drawer
  final _cabangSectionKey = GlobalKey<CabangSectionState>();
  final _homeSectionKey = GlobalKey<HomeSectionState>();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final show = _scrollController.offset > 400;
      if (show != _showScrollTop) setState(() => _showScrollTop = show);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _goToBeranda() {
    _scrollToSection(_homeKey);
    _homeSectionKey.currentState?.restartHero();
  }

  void _scrollToSection(GlobalKey key) {
    final targetContext = key.currentContext;
    if (targetContext != null) {
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
        alignment: 0.0,
      );
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      appBar: _buildNavbar(isMobile),
      endDrawer: isMobile ? _buildMobileDrawer() : null,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFEEF2F6), Color(0xFFF8FAFC)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          clipBehavior: Clip.hardEdge,
          controller: _scrollController,
          child: Column(
            children: [
              KeyedSubtree(key: _homeKey, child: HomeSection(key: _homeSectionKey, isMobile: isMobile, onKirimSekarang: () => _scrollToSection(_cekTarifKey))),
              CekResiSection(sectionKey: _cekResiKey),
              CekTarifSection(sectionKey: _cekTarifKey),
              CabangSection(key: _cabangSectionKey, sectionKey: _cabangKey),
              ServicesSection(sectionKey: _servicesKey),
              AboutSection(sectionKey: _aboutKey),
              ContactSection(sectionKey: _contactKey),
              const FooterSection(),
            ],
          ),
        ),
      ),
      floatingActionButton: _showScrollTop
          ? FloatingActionButton.small(
              onPressed: () => _scrollController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeOut),
              backgroundColor: AppTheme.primary,
              child: const Icon(Icons.arrow_upward_rounded, color: Colors.white),
            )
          : null,
    );
  }

  PreferredSizeWidget _buildNavbar(bool isMobile) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 1,
      title: Row(
        children: [
          Image.asset('assets/pics/yulislogo.webp', width: 38, height: 38),
          const SizedBox(width: 8),
          const Flexible(
            child: Text('Yulis Cargo', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F172A), fontSize: 18), overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
      actions: isMobile
          ? [
              Builder(builder: (context) => IconButton(
                icon: const Icon(Icons.menu_rounded, color: Color(0xFF0F172A)),
                onPressed: () => Scaffold.of(context).openEndDrawer(),
              )),
            ]
          : [
              _navLink('Beranda', null, Icons.home_rounded, _goToBeranda),
              _navLink('Cek Resi', _cekResiKey, Icons.search_rounded),
              _navLink('Cek Tarif', _cekTarifKey, Icons.receipt_long_rounded),
              _navLink('Cabang', _cabangKey, Icons.store_rounded),
              _navLink('Layanan', _servicesKey, Icons.miscellaneous_services_rounded),
              _navLink('Tentang', _aboutKey, Icons.info_outline_rounded),
              _navLink('Kontak', _contactKey, Icons.mail_outline_rounded),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: InkWell(
                  onTap: () => context.go('/login'),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(8)),
                    child: const Text('Login', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                  ),
                ),
              ),
            ],
    );
  }

  Widget _navLink(String text, GlobalKey? key, IconData icon, [VoidCallback? onPressed]) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: TextButton(
        onPressed: onPressed ?? (key != null ? () => _scrollToSection(key) : null),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: const Color(0xFF475569)),
            const SizedBox(width: 4),
            Text(text, style: const TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w600, fontSize: 15)),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Row(children: [
                Image(image: AssetImage('assets/pics/yulislogo.webp'), width: 48, height: 48),
                SizedBox(width: 12),
                Text('Yulis Cargo', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
              ]),
            ),
            const Divider(height: 1),
            _drawerLink('Beranda', null, Icons.home_rounded, _goToBeranda),
            _drawerLink('Cek Resi', _cekResiKey, Icons.search_rounded),
            _drawerLink('Cek Tarif', _cekTarifKey, Icons.receipt_long_rounded),
            _drawerLink('Cabang', _cabangKey, Icons.store_rounded),
            _drawerLink('Layanan', _servicesKey, Icons.miscellaneous_services_rounded),
            _drawerLink('Tentang', _aboutKey, Icons.info_outline_rounded),
            _drawerLink('Kontak', _contactKey, Icons.mail_outline_rounded),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: ElevatedButton(
                onPressed: () => context.go('/login'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Login Akun', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerLink(String text, GlobalKey? key, IconData icon, [VoidCallback? onPressed]) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF475569)),
      title: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
      onTap: onPressed ?? (key != null ? () => _scrollToSection(key) : null),
    );
  }
}
