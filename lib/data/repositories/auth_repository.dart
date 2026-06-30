import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/api_constants.dart';
import '../datasources/remote/api_service.dart';
import '../datasources/local/auth_local.dart';
import '../models/user.dart';
import '../../shared/utils/cabang_lokasi_service.dart';
import 'sync_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());

class AuthRepository {
  final _api = ApiService();
  final _sync = SyncRepository();
  User? _currentUser;

  User? get currentUser => _currentUser;

  Future<bool> isLoggedIn() async {
    final token = await AuthLocal.getToken();
    if (token == null) return false;
    try {
      await getMe();
      return true;
    } catch (_) {
      await AuthLocal.clear();
      return false;
    }
  }

  Future<User> login(String email, String password) async {
    final res = await _api.post(ApiConstants.login, data: { 'email': email, 'password': password });
    final data = res.data as Map<String, dynamic>;
    await AuthLocal.saveToken(data['token'] as String);
    final user = User.fromJson(data['user'] as Map<String, dynamic>);
    _currentUser = user;
    unawaited(_autoSyncOnLogin());
    return user;
  }

  Future<User> getMe() async {
    final res = await _api.get(ApiConstants.me);
    final data = res.data as Map<String, dynamic>;
    final user = User.fromJson(data);
    _currentUser = user;
    return user;
  }

  Future<void> logout() async {
    _currentUser = null;
    await AuthLocal.clear();
  }

  Future<void> _autoSyncOnLogin() async {
    try {
      await Future.wait([
        _sync.syncDrivers(),
        _sync.syncCabangs(),
      ]);
      CabangLokasiService.updateFromHive();
    } catch (_) {}
  }
}

void unawaited(Future<void> future) {
  future.catchError((_) {});
}
