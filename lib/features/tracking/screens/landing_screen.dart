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

  final _homeKey = GlobalKey();
  final _cekResiKey = GlobalKey();
  final _cabangKey = GlobalKey();
  final _cekTarifKey = GlobalKey();
  final _aboutKey = GlobalKey();
  final _servicesKey = GlobalKey();
  final _contactKey = GlobalKey();

  // Ref ke CabangSection agar bisa trigger cari lokasi dari navbar/drawer
  final _cabangSectionKey = GlobalKey<CabangSectionState>();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
              KeyedSubtree(key: _homeKey, child: HomeSection(isMobile: isMobile)),
              CekResiSection(sectionKey: _cekResiKey),
              CekTarifSection(sectionKey: _cekTarifKey),
              CabangSection(key: _cabangSectionKey, sectionKey: _cabangKey),
              AboutSection(sectionKey: _aboutKey),
              ServicesSection(sectionKey: _servicesKey),
              ContactSection(sectionKey: _contactKey),
              const FooterSection(),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildNavbar(bool isMobile) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 1,
      title: Row(
        children: [
          Image.asset('assets/pics/hiralogo.webp', width: 32, height: 32),
          const SizedBox(width: 8),
          const Flexible(
            child: Text('Hira Express', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F172A), fontSize: 18), overflow: TextOverflow.ellipsis),
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
              _navLink('Beranda', _homeKey),
              _navLink('Cek Resi', _cekResiKey),
              _navLink('Cek Tarif', _cekTarifKey),
              _navLink('Cabang', _cabangKey),
              _navLink('Tentang', _aboutKey),
              _navLink('Layanan', _servicesKey),
              _navLink('Kontak', _contactKey),
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

  Widget _navLink(String text, GlobalKey key) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: TextButton(
        onPressed: () => _scrollToSection(key),
        child: Text(text, style: const TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w600, fontSize: 15)),
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
                Image(image: AssetImage('assets/pics/hiralogo.webp'), width: 40, height: 40),
                SizedBox(width: 12),
                Text('Hira Express', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
              ]),
            ),
            const Divider(height: 1),
            _drawerLink('Beranda', _homeKey),
            _drawerLink('Cek Resi', _cekResiKey),
            _drawerLink('Cek Tarif', _cekTarifKey),
            _drawerLink('Cabang', _cabangKey),
            _drawerLink('Tentang', _aboutKey),
            _drawerLink('Layanan', _servicesKey),
            _drawerLink('Kontak', _contactKey),
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

  Widget _drawerLink(String text, GlobalKey key) {
    return ListTile(
      title: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
      onTap: () => _scrollToSection(key),
    );
  }
}
