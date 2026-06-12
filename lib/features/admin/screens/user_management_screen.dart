import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/datasources/remote/api_service.dart';
import '../../../data/models/user.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/utils/sound_player.dart';

final _usersProvider = FutureProvider.autoDispose<List<User>>((ref) async {
  final res = await ApiService().get(ApiConstants.users);
  final data = res.data['data'] as List<dynamic>;
  return data.map((e) => User.fromJson(Map<String, dynamic>.from(e as Map))).toList();
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
  final _searchC = TextEditingController();
  String _search = '';
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_usersProvider);
    final cabangsAsync = ref.watch(_cabangsProvider);
    final cabangs = cabangsAsync.valueOrNull ?? [];
    final activeCabangIds = cabangs
        .where((c) => c['is_active'] == true)
        .map((c) => c['cabang_id']?.toString())
        .whereType<String>()
        .toSet();
    final cabangNameById = <String, String>{};
    for (final c in cabangs) {
      final id = c['cabang_id']?.toString();
      if (id != null) cabangNameById[id] = '${c['kode']} - ${c['name']}';
    }

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
          _buildSearchBar(),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (users) {
                final counts = <String, int>{
                  'all': users.length,
                  'super_admin': users.where((u) => u.role == 'super_admin').length,
                  'admin_cabang': users.where((u) => u.role == 'admin_cabang').length,
                  'driver': users.where((u) => u.role == 'driver').length,
                  'unassigned': users.where((u) {
                    if (u.role != 'admin_cabang') return false;
                    if (u.cabangId == null || u.cabangId!.isEmpty) return true;
                    return !activeCabangIds.contains(u.cabangId);
                  }).length,
                };
                final filters = [
                  {'key': 'all', 'label': 'Semua'},
                  {'key': 'super_admin', 'label': 'Super Admin'},
                  {'key': 'admin_cabang', 'label': 'Admin Cabang'},
                  {'key': 'driver', 'label': 'Driver'},
                  if ((counts['unassigned'] ?? 0) > 0) {'key': 'unassigned', 'label': 'Belum Ditugaskan'},
                ];
                final q = _search.toLowerCase();
                final filtered = users.where((u) {
                  if (_filter == 'unassigned') {
                    if (u.role != 'admin_cabang') return false;
                    if (u.cabangId == null || u.cabangId!.isEmpty) return true;
                    return !activeCabangIds.contains(u.cabangId);
                  }
                  if (_filter != 'all' && u.role != _filter) return false;
                  if (q.isNotEmpty) {
                    if (!u.name.toLowerCase().contains(q) &&
                        !u.email.toLowerCase().contains(q)) return false;
                  }
                  return true;
                }).toList();
                return Column(
                  children: [
                    _buildFilterTabs(filters, counts),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text('Tidak ada akun'))
                          : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final u = filtered[i];
                    final rColor = _roleColor(u.role);
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: InkWell(
                        onTap: () => _showForm(context, ref, user: u),
                        onLongPress: () => _confirmDelete(context, ref, u),
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: rColor.withValues(alpha: 0.1),
                                radius: 24,
                                child: Icon(_roleIcon(u.role), color: rColor, size: 22),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            u.name,
                                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A)),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: rColor.withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: rColor.withValues(alpha: 0.15), width: 0.5),
                                          ),
                                          child: Text(
                                            u.roleLabel,
                                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: rColor),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      u.email,
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                    ),
                                    if (u.phone.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        u.phone,
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                    if (u.role == 'admin_cabang') ...[
                                      const SizedBox(height: 4),
                                      _cabangAssignmentRow(u, cabangNameById, activeCabangIds),
                                    ],
                                  ],
                                ),
                              ),
                              const Icon(Icons.edit_outlined, color: Color(0xFF94A3B8), size: 18),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    ),
  ],
),
);
}

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SizedBox(
        height: 40,
        child: TextField(
          controller: _searchC,
          onChanged: (v) => setState(() => _search = v),
          decoration: InputDecoration(
            hintText: 'Cari nama atau email...',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _search.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchC.clear();
                      setState(() => _search = '');
                    },
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            filled: true,
            fillColor: const Color(0xFFF1F5F9),
            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
          ),
          style: const TextStyle(fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildFilterTabs(List<Map<String, String>> filters, Map<String, int> counts) {
    return SizedBox(
      height: 44,
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < filters.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                () {
                  final f = filters[i];
                  final selected = _filter == f['key'];
                  final count = counts[f['key']] ?? 0;
                  return ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(f['label']!),
                        if (count > 0) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: selected ? const Color(0xFF8B5CF6) : const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$count',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: selected ? Colors.white : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    selected: selected,
                    onSelected: (_) => setState(() => _filter = f['key']!),
                    selectedColor: AppTheme.primary.withValues(alpha: 0.1),
                    checkmarkColor: AppTheme.primary,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? AppTheme.primary : const Color(0xFF64748B),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: selected ? AppTheme.primary : const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                  );
                }(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _cabangAssignmentRow(User u, Map<String, String> cabangNameById, Set<String> activeCabangIds) {
    final hasActiveCabang = u.cabangId != null && u.cabangId!.isNotEmpty && activeCabangIds.contains(u.cabangId);
    final cabangLabel = u.cabangId != null && u.cabangId!.isNotEmpty
        ? (cabangNameById[u.cabangId] ?? 'Cabang tidak dikenal')
        : 'Belum ditugaskan';

    return Row(
      children: [
        Icon(
          hasActiveCabang ? Icons.business_rounded : Icons.warning_amber_rounded,
          size: 13,
          color: hasActiveCabang ? const Color(0xFF94A3B8) : Colors.orange.shade400,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            cabangLabel,
            style: TextStyle(
              fontSize: 11,
              color: hasActiveCabang ? const Color(0xFF94A3B8) : Colors.orange.shade400,
              fontWeight: FontWeight.w500,
              decoration: hasActiveCabang ? null : TextDecoration.lineThrough,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'super_admin': return const Color(0xFFEF4444); // Red
      case 'admin_cabang': return const Color(0xFF8B5CF6); // Purple
      case 'driver': return const Color(0xFF3B82F6); // Blue
      default: return const Color(0xFF64748B);
    }
  }

  IconData _roleIcon(String role) {
    switch (role) {
      case 'super_admin': return Icons.admin_panel_settings_rounded;
      case 'admin_cabang': return Icons.business_rounded;
      case 'driver': return Icons.directions_car_filled_rounded;
      default: return Icons.person_rounded;
    }
  }

  void _showForm(BuildContext context, WidgetRef ref, {User? user}) {
    final isEdit = user != null;
    final nameC = TextEditingController(text: user?.name ?? '');
    final emailC = TextEditingController(text: user?.email ?? '');
    final phoneC = TextEditingController(text: user?.phone ?? '');
    final passC = TextEditingController(text: isEdit ? user.password : '');
    String selectedRole = user?.role ?? 'driver';
    String? selectedCabangId = user?.cabangId;
    bool passVisible = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
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
                const SizedBox(height: 8),
                TextField(
                  controller: passC,
                  obscureText: !passVisible,
                  decoration: InputDecoration(
                    labelText: isEdit ? 'Password' : 'Password',
                    suffixIcon: IconButton(
                      icon: Icon(passVisible ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setDialogState(() => passVisible = !passVisible),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  items: ['super_admin', 'admin_cabang', 'driver'].map((r) => DropdownMenuItem(value: r, child: Text(r.replaceAll('_', ' ').toUpperCase()))).toList(),
                  onChanged: (v) => setDialogState(() {
                    selectedRole = v ?? 'driver';
                    if (selectedRole != 'admin_cabang') selectedCabangId = null;
                  }),
                  decoration: const InputDecoration(labelText: 'Role'),
                ),
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
                  if (isEdit && passC.text.isNotEmpty) data['password'] = passC.text;
                  if (selectedRole == 'admin_cabang' && selectedCabangId != null) data['cabang_id'] = selectedCabangId;

                  if (isEdit) {
                    await ApiService().put('${ApiConstants.users}/${user.id}', data: data);
                  } else {
                    await ApiService().post(ApiConstants.users, data: data);
                  }
                  Navigator.pop(ctx);
                  ref.invalidate(_usersProvider);
                  SoundPlayer.instance.playSuccess();
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text(isEdit ? 'Akun berhasil diperbarui' : 'Akun berhasil ditambahkan'),
                        backgroundColor: const Color(0xFF10B981),
                      ),
                    );
                  }
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
        backgroundColor: Colors.white,
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

  Widget _cabangDropdown(WidgetRef ref, String? selectedId, void Function(String?) onChanged) {
    final async = ref.watch(_cabangsProvider);
    return async.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Error: $e', style: const TextStyle(color: Colors.red)),
      data: (cabangs) {
        final active = cabangs.where((c) => c['is_active'] == true).toList();
          return DropdownButtonFormField<String>(
            isExpanded: true,
            value: active.any((c) => c['cabang_id']?.toString() == selectedId) ? selectedId : null,
            items: [
              const DropdownMenuItem<String>(value: null, child: Text('-- Pilih Cabang --')),
              ...active.map((c) => DropdownMenuItem<String>(
                value: c['cabang_id']?.toString(),
                child: Text('${c['kode']} - ${c['name']}', overflow: TextOverflow.ellipsis),
              )),
            ],
            onChanged: onChanged,
          decoration: const InputDecoration(labelText: 'Cabang Penugasan *', prefixIcon: Icon(Icons.business)),
        );
      },
    );
  }
}
