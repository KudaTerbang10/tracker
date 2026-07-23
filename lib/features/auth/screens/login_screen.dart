import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailC = TextEditingController();
  final _passC = TextEditingController();
  final _passFocus = FocusNode();
  bool _obscure = true;
  List<Map<String, dynamic>> _testDrivers = [];
  bool _loadingDrivers = true;

  @override
  void initState() {
    super.initState();
    _fetchTestDrivers();
  }

  Future<void> _fetchTestDrivers() async {
    try {
      final dio = Dio(BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ));
      final res = await dio.get(ApiConstants.driversTestLogins);
      final data = res.data['data'] as List<dynamic>;
      if (mounted) {
        setState(() {
          _testDrivers = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _loadingDrivers = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingDrivers = false);
      }
    }
  }

  @override
  void dispose() {
    _emailC.dispose();
    _passC.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.status == AuthStatus.loading;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFEEF2F6), Color(0xFFF8FAFC)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Brand Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.shield_rounded,
                        size: 72,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Portal Staff',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                            letterSpacing: -0.5,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Silakan masuk menggunakan akun kredensial Anda',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF64748B),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // Login Card
                    Center(
                      child: SizedBox(
                        width: 420,
                        child: Card(
                          color: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextFormField(
                                  controller: _emailC,
                                  decoration: const InputDecoration(
                                    labelText: 'Email',
                                    hintText: 'email@contoh.com',
                                    prefixIcon: Icon(
                                      Icons.email_outlined,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  onFieldSubmitted: (_) =>
                                      _passFocus.requestFocus(),
                                  validator: (v) => (v == null || v.isEmpty)
                                      ? 'Email wajib diisi'
                                      : null,
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _passC,
                                  focusNode: _passFocus,
                                  obscureText: _obscure,
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    hintText: 'Masukkan password',
                                    prefixIcon: const Icon(
                                      Icons.lock_outlined,
                                      color: AppTheme.primary,
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscure
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        color: const Color(0xFF64748B),
                                      ),
                                      onPressed: () =>
                                          setState(() => _obscure = !_obscure),
                                    ),
                                  ),
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _login(),
                                  validator: (v) => (v == null || v.isEmpty)
                                      ? 'Password wajib diisi'
                                      : null,
                                ),
                                if (authState.error != null) ...[
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.error.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.error_outline_rounded,
                                          color: AppTheme.error,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            authState.error!,
                                            style: const TextStyle(
                                              color: AppTheme.error,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed: isLoading ? null : _login,
                                    child: isLoading
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: const [
                                              Icon(
                                                Icons.login_rounded,
                                                size: 18,
                                              ),
                                              SizedBox(width: 8),
                                              Text('Masuk'),
                                            ],
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Quick Test Login
                    Center(
                      child: SizedBox(
                        width: 420,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.science_outlined,
                                  size: 14,
                                  color: Color(0xFF64748B),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Testing Cepat',
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(
                                        color: const Color(0xFF64748B),
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Super Admin
                            _buildTestButton(
                              label: 'Super Admin',
                              email: 'superadmin@ekspedisi.id',
                              password: 'admin123',
                              color: const Color(0xFF7C3AED),
                              icon: Icons.admin_panel_settings_rounded,
                              isLoading: isLoading,
                            ),

                            const SizedBox(height: 8),

                            // Admin Cabang
                            Text(
                              'Admin Cabang',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: const Color(0xFF94A3B8),
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTestButton(
                                    label: 'Bandung',
                                    email: 'bdo@yulis.com',
                                    password: 'admin123',
                                    color: const Color(0xFF2563EB),
                                    icon: Icons.store_outlined,
                                    isLoading: isLoading,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildTestButton(
                                    label: 'Surabaya',
                                    email: 'sby@yulis.com',
                                    password: 'admin123',
                                    color: const Color(0xFF2563EB),
                                    icon: Icons.store_outlined,
                                    isLoading: isLoading,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            // Driver
                            Text(
                              'Driver',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: const Color(0xFF94A3B8),
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            if (_loadingDrivers)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: SizedBox(
                                  width: 16, height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            else if (_testDrivers.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  'Tidak ada driver terdaftar',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: const Color(0xFF94A3B8),
                                  ),
                                ),
                              )
                            else
                              Row(
                                children: _testDrivers.map((d) {
                                  final label = d['name'] as String? ?? 'Driver';
                                  final email = d['email'] as String? ?? '';
                                  return Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                        right: _testDrivers.last == d ? 0 : 4,
                                      ),
                                      child: _buildTestButton(
                                        label: label,
                                        email: email,
                                        password: 'driver123',
                                        color: const Color(0xFF059669),
                                        icon: Icons.directions_car_outlined,
                                        isLoading: isLoading,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Back Button
                    TextButton.icon(
                      onPressed: () => context.go('/'),
                      icon: const Icon(Icons.arrow_back_rounded, size: 16),
                      label: const Text('Kembali ke Beranda'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTestButton({
    required String label,
    required String email,
    required String password,
    required Color color,
    required IconData icon,
    required bool isLoading,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: isLoading ? null : () => _quickLogin(email, password),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.3)),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15),
            const SizedBox(width: 6),
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }

  void _quickLogin(String email, String password) {
    ref.read(authProvider.notifier).login(email, password);
  }

  void _login() {
    if (!_formKey.currentState!.validate()) return;
    ref.read(authProvider.notifier).login(_emailC.text.trim(), _passC.text);
  }
}
