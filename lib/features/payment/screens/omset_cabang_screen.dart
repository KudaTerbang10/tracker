import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../auth/providers/auth_provider.dart';

const _colorCash = Color(0xFF10B981);
const _colorCod = Color(0xFF6366F1);
const _colorTempo = Color(0xFFF59E0B);

class OmsetCabangScreen extends ConsumerStatefulWidget {
  const OmsetCabangScreen({super.key});

  @override
  ConsumerState<OmsetCabangScreen> createState() => _OmsetCabangScreenState();
}

class _OmsetCabangScreenState extends ConsumerState<OmsetCabangScreen> {
  List<Map<String, dynamic>> _data = [];
  bool _loading = true;
  String? _error;
  int _month = DateTime.now().month;
  int _year = DateTime.now().year;
  final _dateFmt = DateFormat('MMMM yyyy', 'id_ID');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ref
          .read(transactionRepositoryProvider)
          .getWajibSetor(month: _month, year: _year);
      if (mounted)
        setState(() {
          _data = res;
          _loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _loading = false;
        });
    }
  }

  num _num(Map<String, dynamic> m, String key) {
    final v = m[key];
    return v is num ? v : 0;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final branchName =
        user?.lokasi?['name']?.toString() ??
        user?.lokasi?['cabang_name']?.toString() ??
        'Cabang';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Omset Cabang'),
        actions: [
          TextButton.icon(
            onPressed: () async {
              final result = await showDialog<Map<String, int>>(
                context: context,
                builder: (ctx) => _MonthYearPickerDialog(
                  initialMonth: _month,
                  initialYear: _year,
                ),
              );
              if (result != null && mounted) {
                setState(() {
                  _month = result['month']!;
                  _year = result['year']!;
                });
                _load();
              }
            },
            icon: const Icon(Icons.calendar_month_rounded, size: 18),
            label: Text(
              _dateFmt.format(DateTime(_year, _month)),
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
      body: _buildBody(branchName),
    );
  }

  Widget _buildBody(String branchName) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_error != null) {
      return Center(
        child: Card(
          margin: const EdgeInsets.all(16),
          child: SizedBox(
            height: 120,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Gagal memuat data: $_error',
                  style: const TextStyle(color: AppTheme.error, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      );
    }
    if (_data.isEmpty) {
      return const Center(
        child: Card(
          margin: EdgeInsets.all(16),
          child: SizedBox(
            height: 120,
            child: Center(
              child: Text(
                'Belum ada omset di bulan ini',
                style: TextStyle(color: Color(0xFF94A3B8)),
              ),
            ),
          ),
        ),
      );
    }

    final e = _data.first;
    final namaCabang =
        (e['nama_cabang'] as String?)?.isNotEmpty == true
            ? (e['nama_cabang'] as String)
            : branchName;
    final cash = _num(e, 'cash');
    final cod = _num(e, 'cod_total');
    final tempo = _num(e, 'tempo');
    final total = _num(e, 'total');

    final currency = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Omset Cabang $namaCabang',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Rincian omset : Cash, COD, & Tempo',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Omset Cabang',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                      ),
                      Text(
                        currency.format(total),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _Legend(),
                const SizedBox(height: 16),
                Container(
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Row(
                      children: [
                        if (cash > 0)
                          Flexible(
                            flex: cash.toInt(),
                            child: Container(color: _colorCash),
                          ),
                        if (cod > 0)
                          Flexible(
                            flex: cod.toInt(),
                            child: Container(color: _colorCod),
                          ),
                        if (tempo > 0)
                          Flexible(
                            flex: tempo.toInt(),
                            child: Container(color: _colorTempo),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _MiniLabel(color: _colorCash, label: 'Cash', value: cash),
                    _MiniLabel(color: _colorCod, label: 'COD', value: cod),
                    _MiniLabel(
                      color: _colorTempo,
                      label: 'Tempo',
                      value: tempo,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _LegendItem(color: _colorCash, label: 'Cash'),
        const SizedBox(width: 14),
        _LegendItem(color: _colorCod, label: 'COD (Last Mile + Retur)'),
        const SizedBox(width: 14),
        _LegendItem(color: _colorTempo, label: 'Tempo (Lunas)'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
        ),
      ],
    );
  }
}

class _MiniLabel extends StatelessWidget {
  final Color color;
  final String label;
  final num value;
  const _MiniLabel({
    required this.color,
    required this.label,
    required this.value,
  });
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 3),
        Text(
          '$label ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(value)}',
          style: const TextStyle(fontSize: 9, color: Color(0xFF64748B)),
        ),
      ],
    );
  }
}

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
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
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
      title: const Text('Pilih Bulan & Tahun'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Builder(
            builder: (context) {
              const perRow = 3;
              final rows = <List<int>>[];
              for (var i = 0; i < 12; i += perRow) {
                rows.add(
                  List.generate(
                    (i + perRow > 12 ? 12 - i : perRow),
                    (j) => i + j,
                  ),
                );
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
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _month = m),
                            child: Container(
                              margin: const EdgeInsets.all(3),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppTheme.primary
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Text(
                                _months[i],
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: selected
                                      ? Colors.white
                                      : const Color(0xFF475569),
                                ),
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
                onPressed: years.contains(_year - 1)
                    ? () => setState(() => _year--)
                    : null,
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$_year',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: years.contains(_year + 1)
                    ? () => setState(() => _year++)
                    : null,
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
                onPressed: () =>
                    Navigator.of(context).pop({'month': _month, 'year': _year}),
                child: const Text('Lihat'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
