import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/datetime_utils.dart';
import '../../../data/models/manifest.dart';
import '../providers/manifest_provider.dart';
import '../utils/manifest_print.dart';

class ManifestListScreen extends ConsumerStatefulWidget {
  const ManifestListScreen({super.key});
  @override
  ConsumerState<ManifestListScreen> createState() =>
      _ManifestListScreenState();
}

class _ManifestListScreenState extends ConsumerState<ManifestListScreen> {
  final _scrollController = ScrollController();
  int _page = 1;
  final _allManifests = <Manifest>[];
  bool _loadingMore = false;
  bool _hasMore = true;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  void _loadMore() {
    if (_loadingMore || !_hasMore) return;
    setState(() {
      _page++;
      _loadingMore = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    final filter = ManifestFilter(
      page: _page,
      startDate: _startDate,
      endDate: _endDate,
    );
    final async = ref.watch(manifestListProvider(filter));

    // Sync data from async to _allManifests + update _hasMore
    async.whenData((data) {
      if (_allManifests.isEmpty && data.manifests.isNotEmpty) {
        _allManifests.addAll(data.manifests);
        if (data.manifests.length < 20) _hasMore = false;
      }
      // Saat loadMore selesai, append & update hasMore
      if (_loadingMore && data.manifests.isNotEmpty) {
        final existingIds = _allManifests.map((m) => m.id).toSet();
        final newItems =
            data.manifests.where((m) => !existingIds.contains(m.id)).toList();
        if (newItems.isNotEmpty) {
          _allManifests.addAll(newItems);
        }
        _hasMore = data.manifests.length >= 20;
        _loadingMore = false;
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Daftar Manifest'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // Tanggal filter
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: InkWell(
              onTap: () async {
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  initialDateRange: _startDate != null && _endDate != null
                      ? DateTimeRange(start: _startDate!, end: _endDate!)
                      : null,
                  helpText: 'Pilih rentang tanggal',
                  initialEntryMode: DatePickerEntryMode.calendarOnly,
                );
                if (picked != null) {
                  setState(() {
                    _startDate = picked.start;
                    _endDate = picked.end;
                    _page = 1;
                    _allManifests.clear();
                    _hasMore = true;
                  });
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.date_range,
                      size: 16,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _startDate != null && _endDate != null
                            ? '${fmt.format(_startDate!)} — ${fmt.format(_endDate!)}'
                            : 'Filter berdasarkan tanggal',
                        style: TextStyle(
                          fontSize: 12,
                          color: _startDate != null
                              ? const Color(0xFF0F172A)
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                    if (_startDate != null)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _startDate = null;
                            _endDate = null;
                            _page = 1;
                            _allManifests.clear();
                            _hasMore = true;
                          });
                        },
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // List
          Expanded(
            child: async.when(
              loading: () => _allManifests.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _buildList(),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (_) => _allManifests.isEmpty
                  ? _buildEmptyState()
                  : _buildList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.description_rounded,
              size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('Belum ada manifest',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: _allManifests.length + (_hasMore ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == _allManifests.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        return _ManifestCard(manifest: _allManifests[i]);
      },
    );
  }
}

class _ManifestCard extends ConsumerWidget {
  final Manifest manifest;
  const _ManifestCard({required this.manifest});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: icon + nomor manifest + status badge + print
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: manifest.isAntarCabang
                        ? AppTheme.primary.withValues(alpha: 0.08)
                        : Colors.orange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.description_rounded,
                    size: 20,
                    color: manifest.isAntarCabang ? AppTheme.primary : Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    manifest.noManifest,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      fontFamily: 'monospace',
                      letterSpacing: 0.5,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.print_rounded,
                      size: 16,
                      color: Colors.blue,
                    ),
                  ),
                  tooltip: 'Cetak',
                  color: Colors.white,
                  surfaceTintColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  onSelected: (value) =>
                      _handlePrint(context, ref, manifest, value),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'a4',
                      child: Row(
                        children: [
                          Icon(Icons.description_outlined, size: 18, color: Color(0xFF3B82F6)),
                          SizedBox(width: 10),
                          Text('Print A4'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: '80mm',
                      child: Row(
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 18, color: Color(0xFF3B82F6)),
                          SizedBox(width: 10),
                          Text('Print 80 mm'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Row 2: driver name
            Row(
              children: [
                Icon(
                  Icons.person_rounded,
                  size: 12,
                  color: const Color(0xFF64748B),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    manifest.driverName,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF475569),
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Row 3: route
            Row(
              children: [
                Icon(
                  manifest.isAntarCabang
                      ? Icons.store_rounded
                      : Icons.location_on_rounded,
                  size: 12,
                  color: const Color(0xFF94A3B8),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${manifest.asalCabangName} → ${manifest.tujuanNama}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Row 4: tanggal dibuat
            Row(
              children: [
                const Icon(
                  Icons.access_time_rounded,
                  size: 12,
                  color: Color(0xFF94A3B8),
                ),
                const SizedBox(width: 4),
                Text(
                  DateFormat('dd/MM/yyyy HH:mm', 'id_ID')
                      .format(toJakarta(manifest.createdAt)),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Detail button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () =>
                    context.push('/dashboard/manifest/${manifest.id}'),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('Lihat Detail'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _handlePrint(
  BuildContext context,
  WidgetRef ref,
  Manifest manifest,
  String format,
) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  try {
    final detail = await ref.read(manifestDetailProvider(manifest.id).future);
    if (detail == null || context.mounted == false) {
      if (context.mounted) Navigator.of(context).pop();
      return;
    }

    Navigator.of(context).pop();

    if (format == 'a4') {
      await printManifestA4(detail);
    } else {
      await printManifest80mm(detail);
    }
  } catch (_) {
    if (context.mounted) Navigator.of(context).pop();
  }
}
