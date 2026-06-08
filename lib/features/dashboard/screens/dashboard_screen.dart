import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/sync_repository.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../data/models/user.dart';

final _connectionProvider = FutureProvider<bool>((ref) => ref.read(syncRepositoryProvider).checkConnection());

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
        title: Text('${user?.lokasi?['nama'] as String? ?? 'Dashboard'}'),
        automaticallyImplyLeading: false,
        actions: [
          _SyncButton(
            syncing: _syncing,
            lastSuccess: _lastSyncSuccess,
            onTap: _sync,
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'logout') {
                ref.read(authProvider.notifier).logout();
                context.go('/');
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'profile', child: Text('${user?.name} (${user?.roleLabel})')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'logout', child: ListTile(leading: Icon(Icons.logout), title: Text('Logout'), dense: true)),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _greetingCard(user),
          const SizedBox(height: 16),

          if (role == 'super_admin') ...[
            _menuCard(Icons.bar_chart, 'Analitik Traffic', () => _comingSoon(), color: AppTheme.primary),
            const SizedBox(height: 8),
            _menuCard(Icons.people, 'Manajemen Akun', () => context.go('/dashboard/users'), color: AppTheme.primary),
          ],

          if (role == 'admin_konter') ...[
            _menuCard(Icons.add_box, 'Input Transaksi Baru', () => context.go('/dashboard/transaksi-baru'), color: Colors.orange.shade700),
            const SizedBox(height: 8),
            _menuCard(Icons.qr_code_scanner, 'Scan Barang Keluar', () => context.go('/dashboard/scan-keluar'), color: Colors.blue.shade700),
          ],

          if (role == 'staff_gudang') ...[
            _menuCard(Icons.qr_code_scanner, 'Scan Barang Datang', () => context.go('/dashboard/scan-datang'), color: Colors.teal.shade700),
            const SizedBox(height: 8),
            _menuCard(Icons.qr_code_scanner, 'Scan Barang Keluar', () => context.go('/dashboard/scan-keluar'), color: Colors.indigo.shade700),
          ],

          if (role == 'driver') ...[
            _menuCard(Icons.check_circle, 'Scan Barang Diterima', () => context.go('/dashboard/scan-diterima'), color: Colors.green.shade700),
            const SizedBox(height: 8),
            _menuCard(Icons.list_alt, 'Daftar Transaksi Driver', () => context.go('/dashboard/driver-tab'), color: Colors.blue.shade700),
          ],

          if (role != 'driver') ...[
            const SizedBox(height: 16),
            _menuCard(Icons.list_alt, 'Daftar Transaksi', () => context.go('/dashboard/daftar-transaksi'), color: Colors.grey.shade700),
          ],
          const SizedBox(height: 16),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  connectionAsync.when(
                    data: (ok) => Icon(ok ? Icons.cloud_done : Icons.cloud_off, color: ok ? Colors.green : Colors.red),
                    loading: () => const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    error: (_, __) => const Icon(Icons.cloud_off, color: Colors.red),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(connectionAsync.valueOrNull == true ? 'Terhubung ke Database' : 'Tidak Terhubung', style: const TextStyle(fontWeight: FontWeight.w500)),
                      Text('Role: ${user?.roleLabel}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
                    ],
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
    return Card(
      color: AppTheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Halo, ${user?.name ?? 'User'}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(user?.roleLabel ?? '', style: const TextStyle(color: Colors.white70)),
            if (user?.lokasi != null) Text(user!.lokasi!['name'] as String? ?? '', style: const TextStyle(color: Colors.white60, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _menuCard(IconData icon, String label, VoidCallback onTap, {Color? color}) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: (color ?? AppTheme.primary).withValues(alpha: 0.15),
          child: Icon(icon, color: color ?? AppTheme.primary),
        ),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Future<void> _sync() async {
    setState(() => _syncing = true);
    final role = ref.read(authProvider).user?.role ?? '';
    final result = await ref.read(syncRepositoryProvider).syncAll(canSyncKonters: role == 'super_admin');
    final driversOk = result['drivers'] ?? false;
    final gudangsOk = result['gudangs'] ?? false;
    final kontersOk = result['konters'] ?? false;
    final allOk = driversOk && gudangsOk && kontersOk;
    setState(() {
      _syncing = false;
      _lastSyncSuccess = allOk;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(allOk ? 'Sinkronisasi berhasil' : 'Sinkronisasi gagal'),
        backgroundColor: allOk ? Colors.green : AppTheme.warning,
      ));
    }
  }

  void _comingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fitur dalam pengembangan')));
  }
}

class _SyncButton extends StatelessWidget {
  final bool syncing;
  final bool? lastSuccess;
  final VoidCallback onTap;

  const _SyncButton({required this.syncing, this.lastSuccess, required this.onTap});

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
              color: syncing ? Colors.orange : (lastSuccess ?? true ? Colors.green : Colors.red),
            ),
          ),
          IconButton(
            icon: syncing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.sync),
            onPressed: syncing ? null : onTap,
            tooltip: 'Sync Data',
          ),
        ],
      ),
    );
  }
}
