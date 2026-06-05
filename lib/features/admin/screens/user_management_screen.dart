import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../data/datasources/remote/api_service.dart';
import '../../../data/datasources/local/hive_cache.dart';
import '../../../data/repositories/sync_repository.dart';
import '../../../data/models/user.dart';

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

class UserManagementScreen extends ConsumerWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_usersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Akun'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => _showForm(context, ref),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (users) => ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: users.length,
          itemBuilder: (_, i) {
            final u = users[i];
            final lokasiText = u.lokasi?['nama']?.toString();
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _roleColor(u.role).withValues(alpha: 0.15),
                  child: Icon(_roleIcon(u.role), color: _roleColor(u.role)),
                ),
                title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text('${u.email}\n${u.roleLabel}${lokasiText != null ? ' • $lokasiText' : ''}'),
                isThreeLine: lokasiText != null,
                trailing: null,
                onTap: () => _showForm(context, ref, user: u),
              ),
            );
          },
        ),
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'super_admin': return Colors.red;
      case 'admin_konter': return Colors.orange;
      case 'staff_gudang': return Colors.teal;
      case 'driver': return Colors.blue;
      default: return Colors.grey;
    }
  }

  IconData _roleIcon(String role) {
    switch (role) {
      case 'super_admin': return Icons.admin_panel_settings;
      case 'admin_konter': return Icons.store;
      case 'staff_gudang': return Icons.warehouse;
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
                  items: ['super_admin', 'admin_konter', 'staff_gudang', 'driver'].map((r) => DropdownMenuItem(value: r, child: Text(r.replaceAll('_', ' ').toUpperCase()))).toList(),
                  onChanged: (v) => setDialogState(() {
                    selectedRole = v ?? 'driver';
                    if (selectedRole != 'admin_konter') selectedKonterId = null;
                    if (selectedRole != 'staff_gudang') selectedGudangId = null;
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
}
