import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/sync_repository.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../data/models/user.dart';

final _connectionProvider = FutureProvider<bool>(
  (ref) => ref.read(syncRepositoryProvider).checkConnection(),
);

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

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 10),
              child: Image.asset('assets/pics/hiralogo.webp', width: 32, height: 32),
            ),
            Text(
              user?.lokasi?['nama'] as String? ?? 'Dashboard',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
          const SizedBox(height: 20),
          const Text(
            'MENU NAVIGASI',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),

          if (role == 'super_admin') ...[
            _menuCard(
              Icons.bar_chart_rounded,
              'Analitik Traffic',
              () => _comingSoon(),
              color: AppTheme.primary,
            ),
            const SizedBox(height: 8),
            _menuCard(
              Icons.people_alt_rounded,
              'Manajemen Akun',
              () => context.go('/dashboard/users'),
              color: AppTheme.primary,
            ),
            const SizedBox(height: 8),
            _menuCard(
              Icons.business_rounded,
              'Manajemen Cabang',
              () => context.go('/dashboard/cabangs'),
              color: AppTheme.primary,
            ),
          ],

          if (role == 'admin_cabang') ...[
            _menuCard(
              Icons.add_box_rounded,
              'Input Transaksi Baru',
              () => context.go('/dashboard/transaksi-baru'),
              color: Colors.orange.shade700,
            ),
            const SizedBox(height: 8),
            _menuCard(
              Icons.move_to_inbox_rounded,
              'Scan Barang Datang',
              () => context.go('/dashboard/scan-datang'),
              color: Colors.teal.shade700,
            ),
            const SizedBox(height: 8),
            _menuCard(
              Icons.unarchive_rounded,
              'Scan Barang Keluar',
              () => context.go('/dashboard/scan-keluar'),
              color: Colors.indigo.shade700,
            ),
          ],

          if (role == 'driver') ...[
            _menuCard(
              Icons.check_circle_rounded,
              'Scan Barang Diterima',
              () => context.go('/dashboard/scan-diterima'),
              color: Colors.green.shade700,
            ),
            const SizedBox(height: 8),
            _menuCard(
              Icons.list_alt_rounded,
              'Daftar Transaksi Driver',
              () => context.go('/dashboard/driver-tab'),
              color: Colors.blue.shade700,
            ),
          ],

          if (role != 'driver') ...[
            const SizedBox(height: 8),
            _menuCard(
              Icons.format_list_bulleted_rounded,
              'Daftar Transaksi',
              () => context.go('/dashboard/daftar-transaksi'),
              color: const Color(0xFF475569),
            ),
          ],
          const SizedBox(height: 24),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  connectionAsync.when(
                    data: (ok) => Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (ok ? Colors.green : Colors.red).withValues(
                          alpha: 0.1,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        ok ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                        color: ok ? Colors.green : Colors.red,
                        size: 20,
                      ),
                    ),
                    loading: () => const SizedBox(
                      width: 36,
                      height: 36,
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    error: (_, __) => Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.cloud_off_rounded,
                        color: Colors.red,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
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
        ],
      ),
    );
  }

  Widget _greetingCard(User? user) {
    return Container(
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 61, 64, 255),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
                        fontWeight: FontWeight.w600,
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
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    user?.roleLabel ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
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
                  Text(
                    user!.lokasi!['name'] as String? ?? '',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
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

  Widget _menuCard(
    IconData icon,
    String label,
    VoidCallback onTap, {
    Color? color,
  }) {
    final activeColor = color ?? AppTheme.primary;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: activeColor.withValues(alpha: 0.1),
                radius: 20,
                child: Icon(icon, color: activeColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                    fontSize: 14,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF94A3B8),
                size: 20,
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
    final allOk = driversOk && cabangsOk;
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

  void _comingSoon() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Fitur dalam pengembangan')));
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
