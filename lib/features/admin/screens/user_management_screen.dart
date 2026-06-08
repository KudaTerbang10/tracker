import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../data/datasources/remote/api_service.dart';
import '../../../data/datasources/local/hive_cache.dart';
import '../../../data/repositories/sync_repository.dart';
import '../../../data/models/user.dart';
import '../../auth/providers/auth_provider.dart';

final _usersProvider = FutureProvider.autoDispose<List<User>>((ref) async {
  final res = await ApiService().get(ApiConstants.users);
  final data = res.data['data'] as List<dynamic>;
  return data.map((e) => User.fromJson(Map<String, dynamic>.from(e as Map))).toList();
});

final _kontersProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final sync = ref.read(syncRepositoryProvider);
  await sync.syncKonters();
  return await sync.getKonters();
});

final _gudangsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final sync = ref.read(syncRepositoryProvider);
  await sync.syncGudangs();
  return HiveCache.getGudangs();
});

final _cabangsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ApiService().get('/cabangs');
  final data = res.data['data'] as List<dynamic>;
  return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
});

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  String _filter = 'all';

  static const _filters = [
    {'key': 'all', 'label': 'Semua'},
    {'key': 'admin_konter', 'label': 'Admin Konter'},
    {'key': 'staff_gudang', 'label': 'Staff Gudang'},
    {'key': 'admin_cabang', 'label': 'Admin Cabang'},
    {'key': 'driver', 'label': 'Driver'},
  ];

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_usersProvider);
    final kontersAsync = ref.watch(_kontersProvider);
    final gudangsAsync = ref.watch(_gudangsProvider);
    final konters = kontersAsync.maybeWhen(data: (v) => v, orElse: () => <Map<String, dynamic>>[]);
    final gudangs = gudangsAsync.maybeWhen(data: (v) => v, orElse: () => <Map<String, dynamic>>[]);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Akun'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => _showForm(context, ref),
      ),
      body: Column(
        children: [
          _buildFilterTabs(),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (users) {
                final filtered = _filter == 'all'
                    ? users
                    : users.where((u) => u.role == _filter).toList();
                if (filtered.isEmpty) {
                  return const Center(child: Text('Tidak ada akun'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final u = filtered[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _roleColor(u.role).withValues(alpha: 0.15),
                          child: Icon(_roleIcon(u.role), color: _roleColor(u.role)),
                        ),
                        title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: Text('${u.email}\n${_roleWithLocation(u, konters, gudangs)}'),
                        isThreeLine: true,
                        trailing: null,
                        onTap: () => _showForm(context, ref, user: u),
                        onLongPress: () => _confirmDelete(context, ref, u),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    return SizedBox(
      height: 50,
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < _filters.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                () {
                  final f = _filters[i];
                  final selected = _filter == f['key'];
                  return ChoiceChip(
                    label: Text(f['label']!),
                    selected: selected,
                    onSelected: (_) => setState(() => _filter = f['key']!),
                  );
                }(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _roleWithLocation(User u, List<Map<String, dynamic>> konters, List<Map<String, dynamic>> gudangs) {
    String? name;
    if (u.isAdminKonter && u.konterId != null) {
      final match = konters.firstWhere(
        (k) => (k['_id']?.toString() ?? k['konter_id']?.toString()) == u.konterId,
        orElse: () => const {},
      );
      name = match.isNotEmpty ? match['name']?.toString() : null;
    } else if (u.isStaffGudang && u.gudangId != null) {
      final match = gudangs.firstWhere(
        (g) => (g['_id']?.toString() ?? g['gudang_id']?.toString()) == u.gudangId,
        orElse: () => const {},
      );
      name = match.isNotEmpty ? match['name']?.toString() : null;
    }
    name ??= u.lokasi?['nama']?.toString();
    if (name != null && name.isNotEmpty) {
      return '${u.roleLabel} - $name';
    }
    return u.roleLabel;
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'super_admin': return Colors.red;
      case 'admin_konter': return Colors.orange;
      case 'staff_gudang': return Colors.teal;
      case 'admin_cabang': return Colors.purple;
      case 'driver': return Colors.blue;
      default: return Colors.grey;
    }
  }

  IconData _roleIcon(String role) {
    switch (role) {
      case 'super_admin': return Icons.admin_panel_settings;
      case 'admin_konter': return Icons.store;
      case 'staff_gudang': return Icons.warehouse;
      case 'admin_cabang': return Icons.business;
      case 'driver': return Icons.local_shipping;
      default: return Icons.person;
    }
  }

  void _showForm(BuildContext context, WidgetRef ref, {User? user}) {
    final isEdit = user != null;
    final nameC = TextEditingController(text: user?.name ?? '');
    final emailC = TextEditingController(text: user?.email ?? '');
    final phoneC = TextEditingController(text: user?.phone ?? '');
    final passC = TextEditingController();
    String selectedRole = user?.role ?? 'driver';
    String? selectedKonterId = user?.konterId;
    String? selectedGudangId = user?.gudangId;
    String? selectedCabangId = user?.cabangId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit Akun' : 'Tambah Akun'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Nama')),
                const SizedBox(height: 8),
                TextField(controller: emailC, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 8),
                TextField(controller: phoneC, decoration: const InputDecoration(labelText: 'Kontak'), keyboardType: TextInputType.phone),
                if (!isEdit) ...[
                  const SizedBox(height: 8),
                  TextField(controller: passC, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
                ],
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  items: ['super_admin', 'admin_konter', 'staff_gudang', 'admin_cabang', 'driver'].map((r) => DropdownMenuItem(value: r, child: Text(r.replaceAll('_', ' ').toUpperCase()))).toList(),
                  onChanged: (v) => setDialogState(() {
                    selectedRole = v ?? 'driver';
                    if (selectedRole != 'admin_konter') selectedKonterId = null;
                    if (selectedRole != 'staff_gudang') selectedGudangId = null;
                    if (selectedRole != 'admin_cabang') selectedCabangId = null;
                  }),
                  decoration: const InputDecoration(labelText: 'Role'),
                ),
                if (selectedRole == 'admin_konter') ...[
                  const SizedBox(height: 8),
                  Consumer(builder: (context, ref, child) => _konterDropdown(ref, selectedKonterId, (v) => setDialogState(() => selectedKonterId = v))),
                ],
                if (selectedRole == 'staff_gudang') ...[
                  const SizedBox(height: 8),
                  Consumer(builder: (context, ref, child) => _gudangDropdown(ref, selectedGudangId, (v) => setDialogState(() => selectedGudangId = v))),
                ],
                if (selectedRole == 'admin_cabang') ...[
                  const SizedBox(height: 8),
                  Consumer(builder: (context, ref, child) => _cabangDropdown(ref, selectedCabangId, (v) => setDialogState(() => selectedCabangId = v))),
                ],
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                try {
                  final data = <String, dynamic>{
                    'name': nameC.text,
                    'email': emailC.text,
                    'phone': phoneC.text,
                    'role': selectedRole,
                  };
                  if (!isEdit) data['password'] = passC.text;
                  if (selectedRole == 'admin_konter' && selectedKonterId != null) data['konter_id'] = selectedKonterId;
                  if (selectedRole == 'staff_gudang' && selectedGudangId != null) data['gudang_id'] = selectedGudangId;
                  if (selectedRole == 'admin_cabang' && selectedCabangId != null) data['cabang_id'] = selectedCabangId;

                  if (isEdit) {
                    await ApiService().put('${ApiConstants.users}/${user.id}', data: data);
                  } else {
                    await ApiService().post(ApiConstants.users, data: data);
                  }
                  Navigator.pop(ctx);
                  ref.invalidate(_usersProvider);
                } catch (e) {
                  final msg = e is DioException ? (e.response?.data?['message'] as String? ?? 'Error') : 'Error';
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                }
              },
              child: Text(isEdit ? 'Simpan' : 'Tambah'),
            ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('BATAL')),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, User user) {
    final currentUser = ref.read(authProvider).user;
    if (currentUser?.id == user.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak dapat menghapus akun sendiri')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Akun'),
        content: Text('Yakin hapus akun "${user.name}" (${user.email})?\n\nAkun akan dinonaktifkan.'),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                onPressed: () => _deleteUser(ctx, ref, user),
                child: const Text('HAPUS'),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('BATAL')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _deleteUser(BuildContext ctx, WidgetRef ref, User user) async {
    final navigator = Navigator.of(ctx);
    final messenger = ScaffoldMessenger.of(ctx);
    try {
      await ApiService().delete('${ApiConstants.users}/${user.id}');
      navigator.pop();
      ref.invalidate(_usersProvider);
      messenger.showSnackBar(
        SnackBar(content: Text('Akun "${user.name}" berhasil dihapus')),
      );
    } catch (e) {
      final msg = e is DioException
          ? (e.response?.data?['message'] as String? ?? 'Gagal menghapus')
          : 'Gagal menghapus';
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Widget _konterDropdown(WidgetRef ref, String? selectedId, void Function(String?) onChanged) {
    final async = ref.watch(_kontersProvider);
    return async.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Error: $e', style: const TextStyle(color: Colors.red)),
      data: (konters) => DropdownButtonFormField<String>(
        value: selectedId,
        items: [
          const DropdownMenuItem<String>(value: null, child: Text('-- Pilih Konter --')),
          ...konters.map((k) => DropdownMenuItem<String>(
            value: k['_id']?.toString() ?? k['konter_id']?.toString(),
            child: Text('${k['kode_singkat']} - ${k['name']}'),
          )),
        ],
        onChanged: onChanged,
        decoration: const InputDecoration(labelText: 'Konter Penugasan *', prefixIcon: Icon(Icons.store)),
      ),
    );
  }

  Widget _gudangDropdown(WidgetRef ref, String? selectedId, void Function(String?) onChanged) {
    final async = ref.watch(_gudangsProvider);
    return async.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Error: $e', style: const TextStyle(color: Colors.red)),
      data: (gudangs) => DropdownButtonFormField<String>(
        value: selectedId,
        items: [
          const DropdownMenuItem<String>(value: null, child: Text('-- Pilih Gudang --')),
          ...gudangs.map((g) => DropdownMenuItem<String>(
            value: g['_id']?.toString() ?? g['gudang_id']?.toString(),
            child: Text('${g['kode']} - ${g['name']}'),
          )),
        ],
        onChanged: onChanged,
        decoration: const InputDecoration(labelText: 'Gudang Penugasan *', prefixIcon: Icon(Icons.warehouse)),
      ),
    );
  }

  Widget _cabangDropdown(WidgetRef ref, String? selectedId, void Function(String?) onChanged) {
    final async = ref.watch(_cabangsProvider);
    return async.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Error: $e', style: const TextStyle(color: Colors.red)),
      data: (cabangs) => DropdownButtonFormField<String>(
        value: selectedId,
        items: [
          const DropdownMenuItem<String>(value: null, child: Text('-- Pilih Cabang --')),
          ...cabangs.map((c) => DropdownMenuItem<String>(
            value: c['cabang_id']?.toString(),
            child: Text('${c['kode']} - ${c['name']}'),
          )),
        ],
        onChanged: onChanged,
        decoration: const InputDecoration(labelText: 'Cabang Penugasan *', prefixIcon: Icon(Icons.business)),
      ),
    );
  }
}
