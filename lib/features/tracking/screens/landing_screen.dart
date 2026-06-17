import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/launcher.dart';
import '../../../shared/utils/ongkir_service.dart';
import '../../../shared/utils/cabang_lokasi_service.dart';
import '../../../shared/widgets/barcode_scanner_dialog.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});
  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final _resiC = TextEditingController();
  final _scrollController = ScrollController();

  final _homeKey = GlobalKey();
  final _cabangKey = GlobalKey();
  final _cekTarifKey = GlobalKey();
  final _aboutKey = GlobalKey();
  final _servicesKey = GlobalKey();
  final _contactKey = GlobalKey();

  // State untuk Cek Tarif
  String? _cekTarifAsal;
  String? _cekTarifTujuan;
  final _cekTarifBeratC = TextEditingController();
  OngkirResult? _cekTarifResult;
  bool _cekTarifNotFound = false;

  // State untuk Cabang Terdekat
  bool _locating = false;
  bool _locationError = false;
  Position? _userPosition;
  List<CabangTerdekat> _cabangTerdekat = [];
  final _cabangMapController = MapController();
  bool _cabangMapReady = false;

  Future<void> _cariCabangTerdekat() async {
    setState(() {
      _locating = true;
      _locationError = false;
      _cabangTerdekat = [];
    });

    try {
      final locationPermission = await Geolocator.checkPermission();
      if (locationPermission == LocationPermission.denied) {
        final granted = await Geolocator.requestPermission();
        if (granted == LocationPermission.denied ||
            granted == LocationPermission.deniedForever) {
          setState(() {
            _locating = false;
            _locationError = true;
          });
          return;
        }
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      final hasil = CabangLokasiService.cariTerdekat(
        userLat: pos.latitude,
        userLng: pos.longitude,
        radiusKm: 20.0,
      );

      setState(() {
        _userPosition = pos;
        _cabangTerdekat = hasil;
        _locating = false;
      });
    } catch (e) {
      setState(() {
        _locating = false;
        _locationError = true;
      });
    }
  }

  @override
  void dispose() {
    _resiC.dispose();
    _cekTarifBeratC.dispose();
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
    if (Navigator.of(this.context).canPop()) {
      Navigator.of(this.context).pop();
    }
  }

  void _hitungCekTarif() {
    if (_cekTarifAsal == null || _cekTarifTujuan == null) {
      setState(() {
        _cekTarifResult = null;
        _cekTarifNotFound = false;
      });
      return;
    }
    if (_cekTarifAsal == _cekTarifTujuan) {
      setState(() {
        _cekTarifResult = null;
        _cekTarifNotFound = true;
      });
      return;
    }

    // Ganti koma dengan titik untuk antisipasi input pengguna
    final beratStr = _cekTarifBeratC.text.replaceAll(',', '.').trim();
    final berat = double.tryParse(beratStr);

    if (berat == null || berat <= 0) {
      setState(() {
        _cekTarifResult = null;
        _cekTarifNotFound = false;
      });
      return;
    }

    final r = OngkirService.hitung(_cekTarifAsal!, _cekTarifTujuan!, berat);
    setState(() {
      _cekTarifResult = r;
      _cekTarifNotFound = r == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cities = List<String>.from(OngkirService.availableCities)
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
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
          clipBehavior:
              Clip.hardEdge, // Mencegah konten bocor keluar batas scroll
          controller: _scrollController,
          child: Column(
            children: [
              _buildHomeSection(context, isMobile),
              _buildCabangSection(context),
              _buildCekTarifSection(context, cities),
              _buildAboutSection(context),
              _buildServicesSection(context),
              _buildContactSection(context),
              _buildFooter(context),
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
            child: Text(
              'Hira Express',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                fontSize: 18,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: isMobile
          ? [
              Builder(
                builder: (context) => IconButton(
                  icon: const Icon(
                    Icons.menu_rounded,
                    color: Color(0xFF0F172A),
                  ),
                  onPressed: () => Scaffold.of(context).openEndDrawer(),
                ),
              ),
            ]
          : [
              _navLink('Beranda', _homeKey),
              _navLink('Cabang', _cabangKey),
              _navLink('Cek Tarif', _cekTarifKey),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Login',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
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
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFF475569),
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
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
              child: Row(
                children: [
                  Image(
                    image: AssetImage('assets/pics/hiralogo.webp'),
                    width: 40,
                    height: 40,
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Hira Express',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            _drawerLink('Beranda', _homeKey),
            _drawerLink('Cabang', _cabangKey),
            _drawerLink('Cek Tarif', _cekTarifKey),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Login Akun',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerLink(String text, GlobalKey key) {
    return ListTile(
      title: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Color(0xFF0F172A),
        ),
      ),
      onTap: () => _scrollToSection(key),
    );
  }

  Widget _buildHomeSection(BuildContext context, bool isMobile) {
    return KeyedSubtree(
      key: _homeKey,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 24 : 64,
          vertical: isMobile ? 48 : 80,
        ),
        child: isMobile ? _buildMobileHome(context) : _buildWebHome(context),
      ),
    );
  }

  Widget _buildWebHome(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final targetHeight = (screenHeight * 0.55).clamp(300.0, 500.0);

    return LayoutBuilder(
      builder: (context, innerConstraints) {
        final maxWidth = innerConstraints.maxWidth > 1100
            ? 1100.0
            : innerConstraints.maxWidth;
        final colWidth = (maxWidth - 64) / 2;

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: colWidth,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 16,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/pics/hiralogo.webp',
                          width: 112,
                          height: 112,
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'Hira Express',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          fontSize: 48,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Lacak kiriman Anda secara real-time dengan mudah dan cepat. Solusi logistik terpercaya untuk kebutuhan pengiriman Anda.',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 18,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 64),
                SizedBox(
                  width: colWidth,
                  child: SizedBox(
                    height: targetHeight,
                    child: Center(child: _buildTrackingCard(false)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileHome(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Image.asset(
            'assets/pics/hiralogo.webp',
            width: 72,
            height: 72,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Hira Express',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
            fontSize: 32,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Lacak kiriman Anda secara real-time',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 16),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        _buildTrackingCard(true),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildTrackingCard(bool isMobile) {
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment
              .spaceEvenly, // Ruang terbagi rata antara segmen 1 dan 2
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Segmen 1: Ikon & Judul
            isMobile
                ? Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.route_rounded,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Hira Tracking System',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.route_rounded,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Flexible(
                        child: Text(
                          'Hira Tracking System',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                            color: Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

            // Segmen 2: Field Input & Tombol Lacak
            Column(
              children: [
                TextFormField(
                  controller: _resiC,
                  decoration: InputDecoration(
                    labelText: 'Masukkan No. Resi',
                    hintText: 'Contoh: CKG-20270710-0002',
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppTheme.primary,
                      size: 22,
                    ),
                    suffixIcon: Container(
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.qr_code_scanner_rounded,
                          color: AppTheme.primary,
                          size: 22,
                        ),
                        onPressed: _scanBarcode,
                      ),
                    ),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  onFieldSubmitted: (_) => _track(),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _track,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.track_changes_rounded, size: 22),
                        SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            'Lacak Sekarang',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCabangSection(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;

    Widget header = Column(
      children: [
        Text(
          'Cari Cabang Terdekat',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 28,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Temukan cabang Hira Express di sekitar lokasi Anda dalam radius 20 km',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 16),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        if (_cabangTerdekat.isEmpty && !_locating && !_locationError)
          _buildCabangCta()
        else if (_locating)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  'Mencari lokasi Anda...',
                  style: TextStyle(color: Color(0xFF64748B)),
                ),
              ],
            ),
          )
        else if (_locationError)
          _buildLocationError()
        else
          _buildCabangMap(),
      ],
    );

    return KeyedSubtree(
      key: _cabangKey,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
        child: Column(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: header,
              ),
            ),
            if (!_locating && !_locationError && _cabangTerdekat.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildCabangGrid(isMobile),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCabangCta() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.my_location_rounded,
                color: AppTheme.primary,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Izinkan akses lokasi untuk melihat cabang terdekat',
              style: TextStyle(fontSize: 16, color: Color(0xFF475569)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 240,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _cariCabangTerdekat,
                icon: const Icon(Icons.search_rounded),
                label: const Text(
                  'Cari Cabang Terdekat',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationError() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.location_off_rounded,
                color: Color(0xFFDC2626),
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Tidak dapat mengakses lokasi',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Pastikan izin lokasi telah diaktifkan',
              style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 200,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: _cariCabangTerdekat,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Coba Lagi'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCabangMap() {
    final isMobile = MediaQuery.of(context).size.width < 800;
    final userLatLng = LatLng(
      _userPosition!.latitude,
      _userPosition!.longitude,
    );

    return Column(
      children: [
        // Map preview
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              SizedBox(
                height: isMobile ? 250 : 350,
                child: FlutterMap(
                  mapController: _cabangMapController,
                  options: MapOptions(
                    initialCenter: userLatLng,
                    initialZoom: 13,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all,
                    ),
                    onMapReady: () {
                      _cabangMapReady = true;
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.tracker',
                    ),
                    MarkerLayer(
                      markers: [
                        // User marker
                        Marker(
                          point: userLatLng,
                          width: 140,
                          height: 60,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.15),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: const Text(
                                  'Lokasi Anda',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primary,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.my_location_rounded,
                                color: AppTheme.primary,
                                size: 36,
                              ),
                            ],
                          ),
                        ),
                        // Cabang markers
                        for (final ct in _cabangTerdekat)
                          Marker(
                            point: LatLng(
                              ct.cabang.latitude!,
                              ct.cabang.longitude!,
                            ),
                            width: 180,
                            height: 60,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(4),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.15),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    'Cabang ${ct.cabang.name}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.red,
                                      height: 1.2,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.location_on_rounded,
                                  color: Colors.red,
                                  size: 36,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 12,
                top: 12,
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  elevation: 3,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      if (!_cabangMapReady) return;
                      _cabangMapController.move(
                        LatLng(_userPosition!.latitude, _userPosition!.longitude),
                        13,
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(
                        Icons.my_location_rounded,
                        color: AppTheme.primary,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildCabangGrid(bool isMobile) {

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: isMobile
          ? Column(
              children: _cabangTerdekat
                  .map((ct) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SizedBox(
                          width: double.infinity,
                          child: _cabangCard(ct),
                        ),
                      ))
                  .toList(),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final w = (constraints.maxWidth - 16 * 3) / 4;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: _cabangTerdekat.map((ct) => SizedBox(
                    width: w,
                    height: 150,
                    child: _cabangCard(ct),
                  )).toList(),
                );
              },
            ),
    );
  }

  Widget _cabangCard(CabangTerdekat ct) {
    final c = ct.cabang;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.store_rounded,
                color: AppTheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          ct.jarakLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (c.address.isNotEmpty)
                    Text(
                      c.address,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (c.phone.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      c.phone,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCekTarifSection(BuildContext context, List<String> cities) {
    return KeyedSubtree(
      key: _cekTarifKey,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              children: [
                Text(
                  'Cek Tarif Pengiriman',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 28,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Hitung estimasi biaya pengiriman dengan cepat dan transparan',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Autocomplete<String>(
                          optionsBuilder: (textEditingValue) {
                            if (textEditingValue.text.isEmpty) return cities;
                            return cities.where(
                              (c) => c.toLowerCase().contains(
                                textEditingValue.text.toLowerCase(),
                              ),
                            );
                          },
                          onSelected: (v) {
                            setState(() {
                              _cekTarifAsal = v.toLowerCase();
                            });
                            FocusScope.of(
                              context,
                            ).unfocus(); // Menutup dropdown
                            _hitungCekTarif();
                          },
                          fieldViewBuilder:
                              (context, controller, focusNode, onSubmitted) {
                                return TextField(
                                  controller: controller,
                                  focusNode: focusNode,
                                  onSubmitted: (_) => onSubmitted(),
                                  decoration: const InputDecoration(
                                    labelText: 'Kota Asal',
                                    prefixIcon: Icon(
                                      Icons.trip_origin,
                                      size: 20,
                                    ),
                                  ),
                                );
                              },
                        ),
                        const SizedBox(height: 16),
                        Autocomplete<String>(
                          optionsBuilder: (textEditingValue) {
                            if (textEditingValue.text.isEmpty) return cities;
                            return cities.where(
                              (c) => c.toLowerCase().contains(
                                textEditingValue.text.toLowerCase(),
                              ),
                            );
                          },
                          onSelected: (v) {
                            setState(() {
                              _cekTarifTujuan = v.toLowerCase();
                            });
                            FocusScope.of(
                              context,
                            ).unfocus(); // Menutup dropdown
                            _hitungCekTarif();
                          },
                          fieldViewBuilder:
                              (context, controller, focusNode, onSubmitted) {
                                return TextField(
                                  controller: controller,
                                  focusNode: focusNode,
                                  onSubmitted: (_) => onSubmitted(),
                                  decoration: const InputDecoration(
                                    labelText: 'Kota Tujuan',
                                    prefixIcon: Icon(
                                      Icons.location_on,
                                      size: 20,
                                    ),
                                  ),
                                );
                              },
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _cekTarifBeratC,
                          decoration: const InputDecoration(
                            labelText: 'Berat (kg)',
                            prefixIcon: Icon(Icons.scale, size: 20),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => _hitungCekTarif(),
                        ),
                        if (_cekTarifResult != null) ...[
                          const SizedBox(height: 24),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFBBF7D0),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Rincian Tarif',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    color: Color(0xFF166534),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _rincianRow(
                                  'Harga 5 kg pertama',
                                  'Rp${_format(_cekTarifResult!.min)}',
                                ),
                                const SizedBox(height: 8),
                                _rincianRow(
                                  'Per kg berikutnya',
                                  'Rp${_format(_cekTarifResult!.perkg)}',
                                ),
                                const SizedBox(height: 8),
                                _rincianRow('Estimasi', _cekTarifResult!.est),
                                const Divider(height: 24),
                                _rincianRow(
                                  'Total',
                                  'Rp${_format(_cekTarifResult!.total)}',
                                  bold: true,
                                ),
                              ],
                            ),
                          ),
                        ] else if (_cekTarifNotFound) ...[
                          const SizedBox(height: 24),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7ED),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFFED7AA),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.info_outline_rounded,
                                  color: Color(0xFFC2410C),
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                const Flexible(
                                  child: Text(
                                    'Rute belum tersedia',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFC2410C),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;

    return KeyedSubtree(
      key: _aboutKey,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 800,
            ), // Disesuaikan agar sejajar dengan segmen Cek Tarif & Kontak
            child: isMobile
                ? Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        clipBehavior: Clip.antiAlias,
                        child: Image.asset(
                          'assets/pics/tentang-kami.webp',
                          width: double.infinity,
                          height: 200,
                          fit: BoxFit.contain,
                          alignment: Alignment.topCenter,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: double.infinity,
                              height: 200,
                              color: Colors.grey.shade200,
                              child: const Icon(
                                Icons.image_not_supported,
                                size: 50,
                                color: Colors.grey,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Tentang Kami',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 28,
                          color: AppTheme.primary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Hira Express adalah perusahaan logistik dan pengiriman yang berkomitmen memberikan layanan tercepat, teraman, dan terpercaya. Dengan jaringan cabang yang luas dan teknologi pelacakan real-time, kami memastikan setiap paket Anda sampai di tujuan dengan tepat waktu.',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 16,
                          height: 1.7,
                        ),
                        textAlign: TextAlign.justify,
                      ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 1,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          clipBehavior: Clip.antiAlias,
                          child: Image.asset(
                            'assets/pics/tentang-kami.webp',
                            width: double.infinity,
                            height: 280,
                            fit: BoxFit.contain,
                            alignment: Alignment.topCenter,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: double.infinity,
                                height: 280,
                                color: Colors.grey.shade200,
                                child: const Icon(
                                  Icons.image_not_supported,
                                  size: 50,
                                  color: Colors.grey,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Tentang Kami',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 32,
                                color: AppTheme.primary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Hira Express adalah perusahaan logistik dan pengiriman yang berkomitmen memberikan layanan tercepat, teraman, dan terpercaya. Dengan jaringan cabang yang luas dan teknologi pelacakan real-time, kami memastikan setiap paket Anda sampai di tujuan dengan tepat waktu.',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 16,
                                height: 1.7,
                              ),
                              textAlign: TextAlign.justify,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildServicesSection(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return KeyedSubtree(
      key: _servicesKey,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              children: [
                const Text(
                  'Layanan Kami',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 28,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Menerima pengiriman barang dan paket di area Pulau Jawa dan Bali',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                isMobile
                    ? Column(
                        children: [
                          _serviceCard(
                            Icons.local_shipping_rounded,
                            'Pengiriman Barang',
                            'Pengiriman barang secara umum seperti pakaian, sepatu, alat medis, sepeda motor dan lain-lain.',
                            AppTheme.primary,
                          ),
                          const SizedBox(height: 16),
                          _serviceCard(
                            Icons.inventory_2_rounded,
                            'Pengiriman Paket Retail',
                            'Pengiriman barang dengan jumlah yang besar, dihitung per koli.',
                            Colors.teal,
                          ),
                          const SizedBox(height: 16),
                          _serviceCard(
                            Icons.fire_truck_rounded,
                            'Sewa Truk Carter',
                            'Sewa truck untuk pengiriman barang dalam jumlah yang besar, dengan berat maksimal up to 12 ton.',
                            Colors.orange,
                          ),
                          const SizedBox(height: 16),
                          _serviceCard(
                            Icons.payments_rounded,
                            'Bayar Tujuan & Bayar Nanti',
                            'Pembayaran dan transaksi dilakukan di tempat, tujuan atau dilakukan di hari lain.',
                            Colors.purple,
                          ),
                          const SizedBox(height: 16),
                          _serviceCard(
                            Icons.monetization_on_rounded,
                            'Jaminan Uang Kembali',
                            'Ganti rugi untuk barang rusak atau hilang akibat pengiriman pihak ekspedisi sesuai dengan syarat dan ketentuan.',
                            Colors.red,
                          ),
                          const SizedBox(height: 16),
                          _serviceCard(
                            Icons.track_changes_rounded,
                            'Tracking',
                            'Layanan informasi posisi barang di saat proses pengiriman dengan Hira Tracking System.',
                            Colors.indigo,
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: _serviceCard(
                                    Icons.local_shipping_rounded,
                                    'Pengiriman Barang',
                                    'Pengiriman barang secara umum seperti pakaian, sepatu, alat medis, sepeda motor dan lain-lain.',
                                    AppTheme.primary,
                                    stretchHeight: true,
                                  ),
                                ),
                                const SizedBox(width: 24),
                                Expanded(
                                  child: _serviceCard(
                                    Icons.inventory_2_rounded,
                                    'Pengiriman Paket Retail',
                                    'Pengiriman barang dengan jumlah yang besar, dihitung per koli.',
                                    Colors.teal,
                                    stretchHeight: true,
                                  ),
                                ),
                                const SizedBox(width: 24),
                                Expanded(
                                  child: _serviceCard(
                                    Icons.fire_truck_rounded,
                                    'Sewa Truk Carter',
                                    'Sewa truck untuk pengiriman barang dalam jumlah yang besar, dengan berat maksimal up to 12 ton.',
                                    Colors.orange,
                                    stretchHeight: true,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: _serviceCard(
                                    Icons.payments_rounded,
                                    'Bayar Tujuan & Bayar Nanti',
                                    'Pembayaran dan transaksi dilakukan di tempat, tujuan atau dilakukan di hari lain.',
                                    Colors.purple,
                                    stretchHeight: true,
                                  ),
                                ),
                                const SizedBox(width: 24),
                                Expanded(
                                  child: _serviceCard(
                                    Icons.monetization_on_rounded,
                                    'Jaminan Uang Kembali',
                                    'Ganti rugi untuk barang rusak atau hilang akibat pengiriman pihak ekspedisi sesuai dengan syarat dan ketentuan.',
                                    Colors.red,
                                    stretchHeight: true,
                                  ),
                                ),
                                const SizedBox(width: 24),
                                Expanded(
                                  child: _serviceCard(
                                    Icons.track_changes_rounded,
                                    'Tracking',
                                    'Layanan informasi posisi barang di saat proses pengiriman via Hira Tracking System.',
                                    Colors.indigo,
                                    stretchHeight: true,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _serviceCard(
    IconData icon,
    String title,
    String desc,
    Color color, {
    bool stretchHeight = false,
  }) {
    final descWidget = Text(
      desc,
      style: const TextStyle(
        color: Color(0xFF64748B),
        fontSize: 14,
        height: 1.5,
      ),
      textAlign: TextAlign.justify,
    );

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            stretchHeight ? Expanded(child: descWidget) : descWidget,
          ],
        ),
      ),
    );
  }

  Widget _buildContactSection(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return KeyedSubtree(
      key: _contactKey,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              children: [
                const Text(
                  'Hubungi Kami',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 28,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 32),
                isMobile
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _contactItem(
                            Icons.location_on_rounded,
                            'Alamat',
                            'Komplek Pangkalan Truck Genuk Blok AA 57 - 58, Jl. Kaligawe, Genuksari, 50117, Semarang.',
                          ),
                          const SizedBox(height: 16),
                          _contactItem(
                            Icons.phone_rounded,
                            'Telepon',
                            '(024) 6584125',
                          ),
                          const SizedBox(height: 16),
                          _contactItem(
                            Icons.phone_android_rounded,
                            'WhatsApp',
                            '0811-2696-515',
                          ),
                          const SizedBox(height: 16),
                          _contactItem(
                            Icons.email_rounded,
                            'Email',
                            'marketing@hira-express.com',
                          ),
                          const SizedBox(height: 16),
                          _buildSocialButtons(),
                        ],
                      )
                    : Column(
                        children: [
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: _contactItem(
                                    Icons.location_on_rounded,
                                    'Alamat',
                                    'Komplek Pangkalan Truck Genuk Blok AA 57 - 58, Jl. Kaligawe, Genuksari, 50117, Semarang.',
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _contactItem(
                                    Icons.phone_rounded,
                                    'Telepon',
                                    '(024) 6584125',
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _contactItem(
                                    Icons.phone_android_rounded,
                                    'WhatsApp',
                                    '0811-2696-515',
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _contactItem(
                                    Icons.email_rounded,
                                    'Email',
                                    'marketing@hira-express.com',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildSocialButtons(),
                        ],
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _contactItem(IconData icon, String label, String value) {
    return Card(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize
            .min, // Mencegah error layout di mobile (unbounded height)
        children: [
          // Header Kartu (mirip dengan kartu pengirim/penerima di halaman resi)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppTheme.primary.withValues(alpha: 0.08),
            child: Row(
              children: [
                Icon(icon, size: 16, color: AppTheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: value));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$label berhasil disalin'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(
                      Icons.copy_rounded,
                      size: 14,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Konten (Rata Kiri-Atas)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF475569),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialButtons() {
    return Card(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppTheme.primary.withValues(alpha: 0.08),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.alternate_email_rounded,
                  size: 16,
                  color: AppTheme.primary,
                ),
                SizedBox(width: 8),
                Text(
                  'Ikuti Kami',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _socialButton(
                  Icons.camera_alt_rounded,
                  'Instagram',
                  'https://www.instagram.com/hiraexpress.id/',
                ),
                _socialButton(
                  Icons.facebook_rounded,
                  'Facebook',
                  'https://www.facebook.com/profile.php?id=100066689462724',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _socialButton(IconData icon, String label, String url) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => openUrl(url),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppTheme.primary),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          '© ${DateTime.now().year} Hira Express. All rights reserved.',
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
        ),
      ),
    );
  }

  Widget _rincianRow(String label, String value, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: const Color(0xFF166534),
            fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
            color: const Color(0xFF166534),
          ),
        ),
      ],
    );
  }

  String _format(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
  }

  Future<void> _scanBarcode() async {
    final code = await BarcodeScannerDialog.show(context);
    if (code != null && code.isNotEmpty) {
      _resiC.text = code.toUpperCase();
      _track();
    }
  }

  void _track() {
    final resi = _resiC.text.trim().toUpperCase();
    if (resi.isEmpty) return;
    context.go('/track/$resi');
  }
}
