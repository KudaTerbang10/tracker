import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/transaction_repository.dart';

final _trafficProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, _MonthYear>((ref, my) {
  return ref.read(transactionRepositoryProvider).getPerCabangReport(month: my.month, year: my.year);
});

final _routesProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, _MonthYear>((ref, my) {
  return ref.read(transactionRepositoryProvider).getRoutesTop(month: my.month, year: my.year);
});

class _MonthYear {
  final int month;
  final int year;
  const _MonthYear(this.month, this.year);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _MonthYear && month == other.month && year == other.year;

  @override
  int get hashCode => Object.hash(month, year);
}

class TrafficAnalyticsScreen extends ConsumerStatefulWidget {
  const TrafficAnalyticsScreen({super.key});
  @override
  ConsumerState<TrafficAnalyticsScreen> createState() => _TrafficAnalyticsScreenState();
}

class _TrafficAnalyticsScreenState extends ConsumerState<TrafficAnalyticsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late int _month;
  late int _year;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = now.month;
    _year = now.year;
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickMonthYear() async {
    final result = await showDialog<Map<String, int>>(
      context: context,
      builder: (ctx) => _MonthYearPickerDialog(
        initialMonth: _month,
        initialYear: _year,
      ),
    );
    if (result != null) {
      setState(() {
        _month = result['month']!;
        _year = result['year']!;
      });
    }
  }

  Color _barColor(int index) {
    const colors = [
      Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFFA78BFA),
      Color(0xFF3B82F6), Color(0xFF60A5FA), Color(0xFF06B6D4),
      Color(0xFF10B981), Color(0xFFF59E0B), Color(0xFFF97316),
      Color(0xFFEF4444),
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final my = _MonthYear(_month, _year);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analisis Traffic'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _pickMonthYear,
              icon: const Icon(Icons.calendar_month_outlined, size: 18),
              label: Text(
                DateFormat('MMMM yyyy', 'id_ID').format(DateTime(_year, _month)),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Transaksi'),
            Tab(text: '10 Rute Terpadat'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Traffic per Cabang
          _buildTrafficTab(my),
          // Tab 2: Top 10 Rute
          _buildRoutesTab(my),
        ],
      ),
    );
  }

  Widget _buildTrafficTab(_MonthYear my) {
    final trafficAsync = ref.watch(_trafficProvider(my));
    return trafficAsync.when(
      data: (data) => data.isEmpty
          ? _emptyCard('Belum ada transaksi di bulan ini')
          : _TrafficBarChart(data: data, barColor: _barColor),
      loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (e, _) => _ErrorCard(e.toString()),
    );
  }

  Widget _buildRoutesTab(_MonthYear my) {
    final routesAsync = ref.watch(_routesProvider(my));
    return routesAsync.when(
      data: (data) => data.isEmpty
          ? _emptyCard('Belum ada data rute di bulan ini')
          : _RoutesBarChart(data: data, barColor: _barColor),
      loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (e, _) => _ErrorCard(e.toString()),
    );
  }

  Widget _emptyCard(String message) {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(16),
        child: SizedBox(
          height: 120,
          child: Center(
            child: Text(message, style: const TextStyle(color: Color(0xFF94A3B8))),
          ),
        ),
      ),
    );
  }
}

// ── Traffic per Cabang ──

class _TrafficBarChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final Color Function(int) barColor;

  const _TrafficBarChart({required this.data, required this.barColor});

  @override
  Widget build(BuildContext context) {
    final sorted = List<Map<String, dynamic>>.from(data)
      ..sort((a, b) {
        final resiCmp = (b['total_resi'] as num).compareTo(a['total_resi'] as num);
        if (resiCmp != 0) return resiCmp;
        return (b['total_biaya'] as num).compareTo(a['total_biaya'] as num);
      });
    final maxResi = sorted.fold<num>(0, (p, e) => (e['total_resi'] as num) > p ? (e['total_resi'] as num) : p);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Transaksi Per Cabang',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(width: 6),
                    TooltipMessage(
                      message: 'Data transaksi per cabang untuk strategi marketing.',
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'Jumlah transaksi & valuasi uang per cabang',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 16),
                ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: sorted.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final item = sorted[i];
                    final cabang = item['cabang_name'] as String? ?? item['kode_gerai'] as String;
                    final resi = (item['total_resi'] as num).toInt();
                    final biaya = (item['total_biaya'] as num).toInt();
                    final fraction = maxResi > 0 ? resi / maxResi.toDouble() : 0.0;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                cabang,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(biaya),
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: LayoutBuilder(
                                builder: (_, constraints) {
                                  return Stack(
                                    children: [
                                      Container(
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                      ),
                                      FractionallySizedBox(
                                        widthFactor: fraction.clamp(0.02, 1.0),
                                        child: Container(
                                          height: 28,
                                          decoration: BoxDecoration(
                                            color: barColor(i),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 48,
                              child: Text(
                                '$resi resi',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                                textAlign: TextAlign.end,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Top 10 Rute ──

class _RoutesBarChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final Color Function(int) barColor;

  const _RoutesBarChart({required this.data, required this.barColor});

  @override
  Widget build(BuildContext context) {
    final sorted = List<Map<String, dynamic>>.from(data)
      ..sort((a, b) {
        final resiCmp = (b['total_resi'] as num).compareTo(a['total_resi'] as num);
        if (resiCmp != 0) return resiCmp;
        return (b['total_biaya'] as num).compareTo(a['total_biaya'] as num);
      });
    final maxResi = sorted.fold<num>(0, (p, e) => (e['total_resi'] as num) > p ? (e['total_resi'] as num) : p);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      '10 Rute Terpadat',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(width: 6),
                    TooltipMessage(
                      message: '10 rute terpadat untuk strategi ketersediaan armada.',
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'Rute asal → tujuan dengan transaksi terbanyak',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 16),
                ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: sorted.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final item = sorted[i];
                    final asal = item['asal_nama'] as String? ?? item['asal_kode'] as String;
                    final tujuan = item['tujuan_kota'] as String? ?? '';
                    final resi = (item['total_resi'] as num).toInt();
                    final biaya = (item['total_biaya'] as num).toInt();
                    final fraction = maxResi > 0 ? resi / maxResi.toDouble() : 0.0;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Row: rank badge + route label + valuasi
                        Row(
                          children: [
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: barColor(i).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '#${i + 1}',
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: barColor(i)),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '$asal → $tujuan',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(biaya),
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Bar + jumlah resi
                        Row(
                          children: [
                            Expanded(
                              child: LayoutBuilder(
                                builder: (_, constraints) {
                                  return Stack(
                                    children: [
                                      Container(
                                        height: 24,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                      ),
                                      FractionallySizedBox(
                                        widthFactor: fraction.clamp(0.02, 1.0),
                                        child: Container(
                                          height: 24,
                                          decoration: BoxDecoration(
                                            color: barColor(i),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$resi resi',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Shared Widgets ──

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard(this.message);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(16),
        child: SizedBox(
          height: 120,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Gagal memuat data: $message',
                style: const TextStyle(color: AppTheme.error, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Tooltip Info ──

class TooltipMessage extends StatelessWidget {
  final String message;
  const TooltipMessage({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: message,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(fontSize: 12, color: Colors.white),
      child: Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF94A3B8)),
    );
  }
}

// ── Month-Year Picker Dialog ──

class _MonthYearPickerDialog extends StatefulWidget {
  final int initialMonth;
  final int initialYear;

  const _MonthYearPickerDialog({
    required this.initialMonth,
    required this.initialYear,
  });

  @override
  State<_MonthYearPickerDialog> createState() => _MonthYearPickerDialogState();
}

class _MonthYearPickerDialogState extends State<_MonthYearPickerDialog> {
  late int _month;
  late int _year;

  static const _months = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];

  @override
  void initState() {
    super.initState();
    _month = widget.initialMonth;
    _year = widget.initialYear;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final years = List.generate(now.year - 2022 + 1, (i) => 2023 + i);

    return AlertDialog(
      title: const Text(
        'Pilih Bulan & Tahun',
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Builder(
            builder: (context) {
              final perRow = MediaQuery.of(context).size.width > 380 ? 6 : 3;
              final rows = <List<int>>[];
              for (var i = 0; i < 12; i += perRow) {
                rows.add(List.generate(
                  (i + perRow > 12 ? 12 - i : perRow),
                  (j) => i + j,
                ));
              }
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: rows.map((rowIndices) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: rowIndices.map((i) {
                        final m = i + 1;
                        final selected = _month == m;
                        return GestureDetector(
                          onTap: () => setState(() => _month = m),
                          child: Container(
                            width: 68,
                            margin: const EdgeInsets.all(3),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: selected ? AppTheme.primary : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Text(
                              _months[i],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: selected ? Colors.white : const Color(0xFF475569),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: years.contains(_year - 1) ? () => setState(() => _year--) : null,
                iconSize: 20,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('$_year', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: years.contains(_year + 1) ? () => setState(() => _year++) : null,
                iconSize: 20,
              ),
            ],
          ),
        ],
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Batal'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop({'month': _month, 'year': _year}),
                child: const Text('Lihat'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
