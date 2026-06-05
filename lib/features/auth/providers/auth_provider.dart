import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/models/user.dart';

enum AuthStatus { uninitialized, authenticated, unauthenticated, loading }

class AuthState {
  final AuthStatus status;
  final User? user;
  final String? error;

  const AuthState({this.status = AuthStatus.uninitialized, this.user, this.error});

  AuthState copyWith({AuthStatus? status, User? user, String? error}) =>
      AuthState(
        status: status ?? this.status,
        user: user ?? this.user,
        error: error,
      );
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier(ref));

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref _ref;
  AuthNotifier(this._ref) : super(const AuthState()) {
    _init();
  }

  Future<void> _init() async {
    state = state.copyWith(status: AuthStatus.loading);
    final repo = _ref.read(authRepositoryProvider);
    final loggedIn = await repo.isLoggedIn();
    if (loggedIn) {
      state = state.copyWith(status: AuthStatus.authenticated, user: repo.currentUser);
    } else {
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final repo = _ref.read(authRepositoryProvider);
      final user = await repo.login(email, password);
      state = state.copyWith(status: AuthStatus.authenticated, user: user);
    } catch (e) {
      String msg;
      if (e is DioException) {
        switch (e.type) {
          case DioExceptionType.connectionTimeout:
          case DioExceptionType.sendTimeout:
          case DioExceptionType.receiveTimeout:
            msg = 'Waktu koneksi habis. Pastikan backend berjalan.';
            break;
          case DioExceptionType.connectionError:
            msg = 'Tidak bisa terhubung ke server.\nCek: backend sudah jalan? URL sudah benar?';
            break;
          case DioExceptionType.badResponse:
            msg = e.response?.statusCode == 401
                ? 'Email atau password salah'
                : 'Server error (${e.response?.statusCode})';
            break;
          default:
            msg = 'Koneksi error: ${e.message}';
        }
      } else {
        msg = 'Terjadi kesalahan: $e';
      }
      state = state.copyWith(status: AuthStatus.unauthenticated, error: msg);
    }
  }

  void logout() async {
    final repo = _ref.read(authRepositoryProvider);
    await repo.logout();
    state = state.copyWith(status: AuthStatus.unauthenticated, user: null);
  }
}
