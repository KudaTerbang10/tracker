import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/transaction_repository.dart';

const _colorCash = Color(0xFF10B981);
const _colorCod = Color(0xFF6366F1);
const _colorTempo = Color(0xFFF59E0B);

class RekonsiliasiSetoranTab extends ConsumerStatefulWidget {
  final int month;
  final int year;
  const RekonsiliasiSetoranTab({
    super.key,
    required this.month,
    required this.year,
  });

  @override
  ConsumerState<RekonsiliasiSetoranTab> createState() =>
      _RekonsiliasiSetoranTabState();
}

class _RekonsiliasiSetoranTabState
    extends ConsumerState<RekonsiliasiSetoranTab> {
  List<Map<String, dynamic>> _data = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant RekonsiliasiSetoranTab old) {
    super.didUpdateWidget(old);
    if (old.month != widget.month || old.year != widget.year) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ref
          .read(transactionRepositoryProvider)
          .getWajibSetor(month: widget.month, year: widget.year);
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
                'Belum ada wajib setor di bulan ini',
                style: TextStyle(color: Color(0xFF94A3B8)),
              ),
            ),
          ),
        ),
      );
    }

    final totalNasional = _data.fold<num>(0, (p, e) => p + _num(e, 'total'));
    final maxTotal = _data.fold<num>(
      0,
      (p, e) => _num(e, 'total') > p ? _num(e, 'total') : p,
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
                const Text(
                  'Rekonsiliasi Setoran Per Cabang',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Rincian nominal setoran : Cash, COD, & Tempo',
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
                        'Total Nasional Wajib Setor',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                      ),
                      Text(
                        NumberFormat.currency(
                          locale: 'id_ID',
                          symbol: 'Rp ',
                          decimalDigits: 0,
                        ).format(totalNasional),
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
                ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: _data.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (_, i) {
                    final e = _data[i];
                    final nama =
                        (e['nama_cabang'] as String?) ??
                        (e['kode_cabang'] as String?) ??
                        'Cabang';
                    final cash = _num(e, 'cash');
                    final cod = _num(e, 'cod_total');
                    final tempo = _num(e, 'tempo');
                    final total = _num(e, 'total');
                    final fraction = maxTotal > 0
                        ? total / maxTotal.toDouble()
                        : 0.0;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                nama,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0F172A),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              NumberFormat.currency(
                                locale: 'id_ID',
                                symbol: 'Rp ',
                                decimalDigits: 0,
                              ).format(total),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF475569),
                              ),
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
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                      ),
                                      FractionallySizedBox(
                                        widthFactor: fraction.clamp(0.02, 1.0),
                                        child: Container(
                                          height: 28,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          clipBehavior: Clip.antiAlias,
                                          child: Row(
                                            children: [
                                              if (cash > 0)
                                                Flexible(
                                                  flex: cash.toInt(),
                                                  child: Container(
                                                    color: _colorCash,
                                                  ),
                                                ),
                                              if (cod > 0)
                                                Flexible(
                                                  flex: cod.toInt(),
                                                  child: Container(
                                                    color: _colorCod,
                                                  ),
                                                ),
                                              if (tempo > 0)
                                                Flexible(
                                                  flex: tempo.toInt(),
                                                  child: Container(
                                                    color: _colorTempo,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _MiniLabel(
                              color: _colorCash,
                              label: 'Cash',
                              value: cash,
                            ),
                            const SizedBox(width: 8),
                            _MiniLabel(
                              color: _colorCod,
                              label: 'COD',
                              value: cod,
                            ),
                            const SizedBox(width: 8),
                            _MiniLabel(
                              color: _colorTempo,
                              label: 'Tempo',
                              value: tempo,
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
