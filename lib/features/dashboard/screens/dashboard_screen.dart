import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/sync_repository.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../data/models/user.dart';
import '../../../shared/utils/ongkir_service.dart';
import '../../../shared/utils/cabang_lokasi_service.dart';

final _connectionProvider = FutureProvider<bool>(
  (ref) => ref.read(syncRepositoryProvider).checkConnection(),
);

class _DashboardMenuItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color iconColor;
  final Color pastelColor;

  _DashboardMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.iconColor,
    required this.pastelColor,
  });
}

List<_DashboardMenuItem> _getMenuItemsForRole(String role, BuildContext context) {
  switch (role) {
    case 'super_admin':
      return [
        _DashboardMenuItem(
          icon: Icons.bar_chart_rounded,
          label: 'Analisis Traffic',
          onTap: () => context.go('/dashboard/traffic'),
          iconColor: const Color(0xFF2563EB),
          pastelColor: const Color(0xFFDBEAFE),
        ),
        _DashboardMenuItem(
          icon: Icons.format_list_bulleted_rounded,
          label: 'Daftar Transaksi',
          onTap: () => context.go('/dashboard/daftar-transaksi'),
          iconColor: const Color(0xFF7C3AED),
          pastelColor: const Color(0xFFE9D5FF),
        ),
        _DashboardMenuItem(
          icon: Icons.people_alt_rounded,
          label: 'Manajemen Akun',
          onTap: () => context.go('/dashboard/users'),
          iconColor: const Color(0xFFDB2777),
          pastelColor: const Color(0xFFFCE7F3),
        ),
        _DashboardMenuItem(
          icon: Icons.business_rounded,
          label: 'Manajemen Cabang',
          onTap: () => context.go('/dashboard/cabangs'),
          iconColor: const Color(0xFF059669),
          pastelColor: const Color(0xFFD1FAE5),
        ),
        _DashboardMenuItem(
          icon: Icons.payments_rounded,
          label: 'Manajemen Tarif',
          onTap: () => context.go('/dashboard/tariffs'),
          iconColor: const Color(0xFFD97706),
          pastelColor: const Color(0xFFFEF3C7),
        ),
        _DashboardMenuItem(
          icon: Icons.report_problem_rounded,
          label: 'Transaksi Bermasalah',
          onTap: () => context.go('/dashboard/barang-bermasalah'),
          iconColor: const Color(0xFFEF4444),
          pastelColor: const Color(0xFFFEE2E2),
        ),
      ];
    case 'admin_cabang':
      return [
        _DashboardMenuItem(
          icon: Icons.add_box_rounded,
          label: 'Input Transaksi Baru',
          onTap: () => context.go('/dashboard/transaksi-baru'),
          iconColor: const Color(0xFF2563EB),
          pastelColor: const Color(0xFFDBEAFE),
        ),
        _DashboardMenuItem(
          icon: Icons.format_list_bulleted_rounded,
          label: 'Daftar Transaksi',
          onTap: () => context.go('/dashboard/daftar-transaksi'),
          iconColor: const Color(0xFF475569),
          pastelColor: const Color(0xFFF1F5F9),
        ),
        _DashboardMenuItem(
          icon: Icons.move_to_inbox_rounded,
          label: 'Scan Barang Datang',
          onTap: () => context.go('/dashboard/scan-datang'),
          iconColor: const Color(0xFF0D9488),
          pastelColor: const Color(0xFFCCFBF1),
        ),
        _DashboardMenuItem(
          icon: Icons.unarchive_rounded,
          label: 'Scan Barang Keluar',
          onTap: () => context.go('/dashboard/scan-keluar'),
          iconColor: const Color(0xFFDC2626),
          pastelColor: const Color(0xFFFEE2E2),
        ),
        _DashboardMenuItem(
          icon: Icons.description_rounded,
          label: 'Daftar Manifest',
          onTap: () => context.go('/dashboard/manifests'),
          iconColor: const Color(0xFFD97706),
          pastelColor: const Color(0xFFFEF3C7),
        ),
        _DashboardMenuItem(
          icon: Icons.report_problem_rounded,
          label: 'Transaksi Bermasalah',
          onTap: () => context.go('/dashboard/barang-bermasalah'),
          iconColor: const Color(0xFFEF4444),
          pastelColor: const Color(0xFFFEE2E2),
        ),
        _DashboardMenuItem(
          icon: Icons.contacts_rounded,
          label: 'Daftar Kontak Cabang',
          onTap: () => context.go('/dashboard/cabang-kontak'),
          iconColor: const Color(0xFF4F46E5),
          pastelColor: const Color(0xFFE0E7FF),
        ),
        _DashboardMenuItem(
          icon: Icons.check_circle_rounded,
          label: 'Scan Barang Diterima',
          onTap: () => context.go('/dashboard/scan-diterima'),
          iconColor: const Color(0xFF059669),
          pastelColor: const Color(0xFFD1FAE5),
        ),
      ];
    case 'driver':
      return [
        _DashboardMenuItem(
          icon: Icons.check_circle_rounded,
          label: 'Scan Barang Diterima',
          onTap: () => context.go('/dashboard/scan-diterima'),
          iconColor: const Color(0xFF059669),
          pastelColor: const Color(0xFFD1FAE5),
        ),
        _DashboardMenuItem(
          icon: Icons.list_alt_rounded,
          label: 'Daftar Transaksi Driver',
          onTap: () => context.go('/dashboard/driver-tab'),
          iconColor: const Color(0xFFD97706),
          pastelColor: const Color(0xFFFEF3C7),
        ),
      ];
    default:
      return [];
  }
}

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _syncing = false;
  bool? _lastSyncSuccess;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final user = auth.user;
    final role = user?.role ?? '';
    final connectionAsync = ref.watch(_connectionProvider);
    final menuItems = _getMenuItemsForRole(role, context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 10),
              child: Image.asset('assets/pics/hiralogo.webp', width: 32, height: 32),
            ),
            Text(
              user?.lokasi?['nama'] as String? ?? 'Dashboard',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            ),
          ],
        ),
        actions: [
          _SyncButton(
            syncing: _syncing,
            lastSuccess: _lastSyncSuccess,
            onTap: _sync,
          ),
          PopupMenuButton<String>(
            surfaceTintColor: Colors.transparent,
            color: Colors.white,
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_outline_rounded,
                color: AppTheme.primary,
                size: 20,
              ),
            ),
            onSelected: (v) {
              if (v == 'logout') {
                ref.read(authProvider.notifier).logout();
                context.go('/');
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'profile',
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      user?.name ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      user?.email ?? '',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        user?.roleLabel ?? '',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  leading: Icon(
                    Icons.logout_rounded,
                    color: AppTheme.error,
                    size: 20,
                  ),
                  title: Text(
                    'Keluar dari Akun',
                    style: TextStyle(
                      color: AppTheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _greetingCard(user),
          const SizedBox(height: 24),
          const Text(
            'MENU NAVIGASI',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          
          if (menuItems.isNotEmpty)
            LayoutBuilder(
              builder: (context, constraints) {
                int crossAxisCount;
                if (constraints.maxWidth > 800) {
                  crossAxisCount = 4;
                } else if (constraints.maxWidth > 600) {
                  crossAxisCount = 3;
                } else {
                  crossAxisCount = 2;
                }

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: menuItems.length,
                  itemBuilder: (context, index) {
                    final item = menuItems[index];
                    return _gridMenuCard(
                      item.icon,
                      item.label,
                      item.onTap,
                      iconColor: item.iconColor,
                      pastelColor: item.pastelColor,
                    );
                  },
                );
              },
            ),
            
          const SizedBox(height: 24),

          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200, width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  connectionAsync.when(
                    data: (ok) => Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (ok ? Colors.green : Colors.red).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        ok ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                        color: ok ? Colors.green : Colors.red,
                        size: 22,
                      ),
                    ),
                    loading: () => const SizedBox(
                      width: 42,
                      height: 42,
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    error: (_, __) => Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.cloud_off_rounded,
                        color: Colors.red,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          connectionAsync.valueOrNull == true
                              ? 'Terhubung ke Database'
                              : 'Koneksi Offline',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Hira Express',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _greetingCard(User? user) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Halo, ${user?.name ?? 'User'}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.email ?? '',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    user?.roleLabel ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (user?.lokasi != null) ...[
              const SizedBox(height: 16),
              const Divider(color: Colors.white24, height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    color: Colors.white70,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      user!.lokasi!['name'] as String? ?? '',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _gridMenuCard(
    IconData icon,
    String label,
    VoidCallback onTap, {
    required Color iconColor,
    required Color pastelColor,
  }) {
    return Card(
      elevation: 0,
      color: pastelColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: iconColor.withValues(alpha: 0.2), width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: iconColor.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(height: 14),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF334155),
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sync() async {
    setState(() => _syncing = true);
    final result = await ref.read(syncRepositoryProvider).syncAll();
    final driversOk = result['drivers'] ?? false;
    final cabangsOk = result['cabangs'] ?? false;
    final tariffsOk = result['tariffs'] ?? false;
    // Refresh cabang dulu agar OngkirService.availableCities pakai data terbaru
    if (cabangsOk) {
      CabangLokasiService.updateFromHive();
    }
    if (tariffsOk) {
      OngkirService.updateFromHive();
    }
    final allOk = driversOk && cabangsOk && tariffsOk;
    setState(() {
      _syncing = false;
      _lastSyncSuccess = allOk;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(allOk ? 'Sinkronisasi berhasil' : 'Sinkronisasi gagal'),
          backgroundColor: allOk ? Colors.green : AppTheme.warning,
        ),
      );
    }
  }
}

class _SyncButton extends StatelessWidget {
  final bool syncing;
  final bool? lastSuccess;
  final VoidCallback onTap;

  const _SyncButton({
    required this.syncing,
    this.lastSuccess,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: syncing
                  ? Colors.orange
                  : (lastSuccess ?? true ? Colors.green : Colors.red),
            ),
          ),
          IconButton(
            icon: syncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            onPressed: syncing ? null : onTap,
            tooltip: 'Sync Data',
          ),
        ],
      ),
    );
  }
}