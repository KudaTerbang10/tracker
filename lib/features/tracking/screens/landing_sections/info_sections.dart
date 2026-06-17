import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/utils/launcher.dart';

class AboutSection extends StatelessWidget {
  final GlobalKey sectionKey;
  const AboutSection({super.key, required this.sectionKey});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    return KeyedSubtree(
      key: sectionKey,
      child: Container(
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1))),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: isMobile
                ? _mobileLayout()
                : _webLayout(),
          ),
        ),
      ),
    );
  }

  Widget _image(double height) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Image.asset('assets/pics/tentang-kami.webp', width: double.infinity, height: height, fit: BoxFit.contain, alignment: Alignment.topCenter,
        errorBuilder: (context, error, stackTrace) => Container(width: double.infinity, height: height, color: Colors.grey.shade200, child: const Icon(Icons.image_not_supported, size: 50, color: Colors.grey)),
      ),
    );
  }

  Widget _textContent({bool centerAlign = false}) {
    return Column(
      crossAxisAlignment: centerAlign ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text('Tentang Kami', style: TextStyle(fontWeight: FontWeight.w800, fontSize: centerAlign ? 28 : 32, color: AppTheme.primary), textAlign: centerAlign ? TextAlign.center : null),
        const SizedBox(height: 12),
        const Text(
          'Hira Express adalah perusahaan logistik dan pengiriman yang berkomitmen memberikan layanan tercepat, teraman, dan terpercaya. Dengan jaringan cabang yang luas dan teknologi pelacakan real-time, kami memastikan setiap paket Anda sampai di tujuan dengan tepat waktu.',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 16, height: 1.7),
          textAlign: TextAlign.justify,
        ),
      ],
    );
  }

  Widget _mobileLayout() => Column(children: [_image(200), const SizedBox(height: 24), _textContent(centerAlign: true)]);

  Widget _webLayout() => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [Expanded(flex: 1, child: _image(280)), const SizedBox(width: 48), Expanded(flex: 1, child: _textContent())],
  );
}

// ---------- Services Section ----------

class ServicesSection extends StatelessWidget {
  final GlobalKey sectionKey;
  const ServicesSection({super.key, required this.sectionKey});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return KeyedSubtree(
      key: sectionKey,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              children: [
                const Text('Layanan Kami', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 28, color: AppTheme.primary)),
                const SizedBox(height: 8),
                const Text('Menerima pengiriman barang dan paket di area Pulau Jawa dan Bali', style: TextStyle(color: Color(0xFF64748B), fontSize: 16), textAlign: TextAlign.center),
                const SizedBox(height: 40),
                if (isMobile) _mobileServices() else _webServices(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _mobileServices() => Column(
    children: [
      _serviceCard(Icons.local_shipping_rounded, 'Pengiriman Barang', 'Pengiriman barang secara umum seperti pakaian, sepatu, alat medis, sepeda motor dan lain-lain.', AppTheme.primary),
      const SizedBox(height: 16),
      _serviceCard(Icons.inventory_2_rounded, 'Pengiriman Paket Retail', 'Pengiriman barang dengan jumlah yang besar, dihitung per koli.', Colors.teal),
      const SizedBox(height: 16),
      _serviceCard(Icons.fire_truck_rounded, 'Sewa Truk Carter', 'Sewa truck untuk pengiriman barang dalam jumlah yang besar, dengan berat maksimal up to 12 ton.', Colors.orange),
      const SizedBox(height: 16),
      _serviceCard(Icons.payments_rounded, 'Bayar Tujuan & Bayar Nanti', 'Pembayaran dan transaksi dilakukan di tempat, tujuan atau dilakukan di hari lain.', Colors.purple),
      const SizedBox(height: 16),
      _serviceCard(Icons.monetization_on_rounded, 'Jaminan Uang Kembali', 'Ganti rugi untuk barang rusak atau hilang akibat pengiriman pihak ekspedisi sesuai dengan syarat dan ketentuan.', Colors.red),
      const SizedBox(height: 16),
      _serviceCard(Icons.track_changes_rounded, 'Tracking', 'Layanan informasi posisi barang di saat proses pengiriman dengan Hira Tracking System.', Colors.indigo),
    ],
  );

  Widget _webServices() => Column(
    children: [
      IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: _serviceCard(Icons.local_shipping_rounded, 'Pengiriman Barang', 'Pengiriman barang secara umum seperti pakaian, sepatu, alat medis, sepeda motor dan lain-lain.', AppTheme.primary, stretchHeight: true)),
          const SizedBox(width: 24),
          Expanded(child: _serviceCard(Icons.inventory_2_rounded, 'Pengiriman Paket Retail', 'Pengiriman barang dengan jumlah yang besar, dihitung per koli.', Colors.teal, stretchHeight: true)),
          const SizedBox(width: 24),
          Expanded(child: _serviceCard(Icons.fire_truck_rounded, 'Sewa Truk Carter', 'Sewa truck untuk pengiriman barang dalam jumlah yang besar, dengan berat maksimal up to 12 ton.', Colors.orange, stretchHeight: true)),
        ]),
      ),
      const SizedBox(height: 24),
      IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: _serviceCard(Icons.payments_rounded, 'Bayar Tujuan & Bayar Nanti', 'Pembayaran dan transaksi dilakukan di tempat, tujuan atau dilakukan di hari lain.', Colors.purple, stretchHeight: true)),
          const SizedBox(width: 24),
          Expanded(child: _serviceCard(Icons.monetization_on_rounded, 'Jaminan Uang Kembali', 'Ganti rugi untuk barang rusak atau hilang akibat pengiriman pihak ekspedisi sesuai dengan syarat dan ketentuan.', Colors.red, stretchHeight: true)),
          const SizedBox(width: 24),
          Expanded(child: _serviceCard(Icons.track_changes_rounded, 'Tracking', 'Layanan informasi posisi barang di saat proses pengiriman via Hira Tracking System.', Colors.indigo, stretchHeight: true)),
        ]),
      ),
    ],
  );

  Widget _serviceCard(IconData icon, String title, String desc, Color color, {bool stretchHeight = false}) {
    final descWidget = Text(desc, style: const TextStyle(color: Color(0xFF64748B), fontSize: 14, height: 1.5), textAlign: TextAlign.justify);
    return Card(
      elevation: 0, color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade100)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: Color(0xFF0F172A))),
          const SizedBox(height: 8),
          stretchHeight ? Expanded(child: descWidget) : descWidget,
        ]),
      ),
    );
  }
}

// ---------- Contact Section ----------

class ContactSection extends StatelessWidget {
  final GlobalKey sectionKey;
  const ContactSection({super.key, required this.sectionKey});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return KeyedSubtree(
      key: sectionKey,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              children: [
                const Text('Hubungi Kami', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 28, color: AppTheme.primary)),
                const SizedBox(height: 32),
                if (isMobile) _mobileContent(context) else _webContent(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _mobileContent(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _contactItem(context, Icons.location_on_rounded, 'Alamat', 'Komplek Pangkalan Truck Genuk Blok AA 57 - 58, Jl. Kaligawe, Genuksari, 50117, Semarang.'),
      const SizedBox(height: 16),
      _contactItem(context, Icons.phone_rounded, 'Telepon', '(024) 6584125'),
      const SizedBox(height: 16),
      _contactItem(context, Icons.phone_android_rounded, 'WhatsApp', '0811-2696-515'),
      const SizedBox(height: 16),
      _contactItem(context, Icons.email_rounded, 'Email', 'marketing@hira-express.com'),
      const SizedBox(height: 16),
      _buildSocialButtons(),
    ],
  );

  Widget _webContent(BuildContext context) => Column(
    children: [
      IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: _contactItem(context, Icons.location_on_rounded, 'Alamat', 'Komplek Pangkalan Truck Genuk Blok AA 57 - 58, Jl. Kaligawe, Genuksari, 50117, Semarang.')),
          const SizedBox(width: 16),
          Expanded(child: _contactItem(context, Icons.phone_rounded, 'Telepon', '(024) 6584125')),
          const SizedBox(width: 16),
          Expanded(child: _contactItem(context, Icons.phone_android_rounded, 'WhatsApp', '0811-2696-515')),
          const SizedBox(width: 16),
          Expanded(child: _contactItem(context, Icons.email_rounded, 'Email', 'marketing@hira-express.com')),
        ]),
      ),
      const SizedBox(height: 16),
      _buildSocialButtons(),
    ],
  );

  Widget _contactItem(BuildContext context, IconData icon, String label, String value) {
    return Card(
      color: Colors.white, clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200, width: 1)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: AppTheme.primary.withValues(alpha: 0.08),
          child: Row(
            children: [
              Icon(icon, size: 16, color: AppTheme.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(label, style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 13))),
              InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: value));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label berhasil disalin'), duration: const Duration(seconds: 2)));
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                  child: const Icon(Icons.copy_rounded, size: 14, color: AppTheme.primary),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(value, style: const TextStyle(fontSize: 14, color: Color(0xFF475569), height: 1.5)),
        ),
      ]),
    );
  }

  Widget _buildSocialButtons() {
    return Card(
      color: Colors.white, clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200, width: 1)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: AppTheme.primary.withValues(alpha: 0.08),
          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.alternate_email_rounded, size: 16, color: AppTheme.primary),
            SizedBox(width: 8),
            Text('Ikuti Kami', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 13)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _socialButton(Icons.camera_alt_rounded, 'Instagram', 'https://www.instagram.com/hiraexpress.id/'),
            _socialButton(Icons.facebook_rounded, 'Facebook', 'https://www.facebook.com/profile.php?id=100066689462724'),
          ]),
        ),
      ]),
    );
  }

  Widget _socialButton(IconData icon, String label, String url) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => openUrl(url),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: AppTheme.primary),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
        ]),
      ),
    );
  }
}

// ---------- Footer ----------

class FooterSection extends StatelessWidget {
  const FooterSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text('© ${DateTime.now().year} Hira Express. All rights reserved.', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
      ),
    );
  }
}
