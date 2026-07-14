import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/tracking/screens/landing_screen.dart';
import '../features/tracking/screens/track_result_screen.dart';
import '../features/scan_batch/screens/scan_datang_screen.dart';
import '../features/scan_batch/screens/scan_keluar_screen.dart';
import '../features/scan_batch/screens/scan_diterima_screen.dart';
import '../features/transaction/screens/create_transaction_screen.dart';
import '../features/transaction/screens/transaction_list_screen.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/admin/screens/user_management_screen.dart';
import '../features/admin/screens/cabang_management_screen.dart';
import '../features/admin/screens/tariff_management_screen.dart';
import '../features/admin/screens/tariff_bulk_screen.dart';
import '../features/admin/screens/traffic_analytics_screen.dart';
import '../features/admin/screens/cabang_contact_screen.dart';
import '../features/admin/screens/problematic_transactions_screen.dart';
import '../features/payment/screens/payment_management_screen.dart';
import '../features/payment/screens/omset_cabang_screen.dart';
import '../features/driver/screens/driver_tab_screen.dart';
import '../features/manifest/screens/manifest_list_screen.dart';
import '../features/manifest/screens/manifest_detail_screen.dart';

class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    ref.listen<AuthState>(authProvider, (_, __) => notifyListeners());
  }
}

  final routerProvider = Provider<GoRouter>((ref) {
  final listenable = _AuthListenable(ref);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: listenable,
    redirect: (context, state) {
      final current = ref.read(authProvider);
      final isAuth = current.status == AuthStatus.authenticated;
      final loc = state.matchedLocation;
      final isLogin = loc == '/login';
      final isPublic = loc == '/' || loc.startsWith('/track/');

      if (current.status == AuthStatus.uninitialized || current.status == AuthStatus.loading) return null;

      if (!isAuth && !isPublic && !isLogin) return '/login';
      if (isAuth && isLogin) return '/dashboard';

      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const LandingScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/track/:noResi', builder: (_, state) => TrackResultScreen(noResi: state.pathParameters['noResi']!)),
      GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen(), routes: [
        GoRoute(path: 'scan-datang', builder: (_, __) => const ScanDatangScreen()),
        GoRoute(path: 'scan-keluar', builder: (_, __) => const ScanKeluarScreen()),
        GoRoute(path: 'scan-diterima', builder: (_, __) => const ScanDiterimaScreen()),
        GoRoute(path: 'transaksi-baru', builder: (_, __) => const CreateTransactionScreen()),
        GoRoute(path: 'daftar-transaksi', builder: (_, __) => const TransactionListScreen()),
        GoRoute(path: 'users', builder: (_, __) => const UserManagementScreen()),
        GoRoute(path: 'cabangs', builder: (_, __) => const CabangManagementScreen()),
        GoRoute(path: 'driver-tab', builder: (_, __) => const DriverTabScreen()),
        GoRoute(path: 'tariffs', builder: (_, __) => const TariffManagementScreen()),
        GoRoute(path: 'tariffs-bulk', builder: (_, __) => const TariffBulkScreen()),
        GoRoute(path: 'traffic', builder: (_, __) => const TrafficAnalyticsScreen()),
        GoRoute(path: 'manifests', builder: (_, __) => const ManifestListScreen()),
        GoRoute(path: 'manifest/:id', builder: (_, state) => ManifestDetailScreen(manifestId: state.pathParameters['id']!)),
        GoRoute(path: 'cabang-kontak', builder: (_, __) => const CabangContactScreen()),
        GoRoute(path: 'barang-bermasalah', builder: (_, __) => const ProblematicTransactionsScreen()),
        GoRoute(path: 'pembayaran', builder: (_, __) => const PaymentManagementScreen()),
        GoRoute(path: 'omset-cabang', builder: (_, __) => const OmsetCabangScreen()),
      ]),
    ],
  );
});
