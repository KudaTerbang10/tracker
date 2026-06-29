import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/api_constants.dart';
import '../datasources/remote/api_service.dart';
import '../models/transaction.dart';

final trackRepositoryProvider = Provider<TrackRepository>((ref) => TrackRepository());

class _CacheEntry {
  final Transaction data;
  final DateTime cachedAt;
  _CacheEntry(this.data) : cachedAt = DateTime.now();

  bool get isExpired => DateTime.now().difference(cachedAt).inSeconds >= 60;
}

class TrackRepository {
  final _api = ApiService();
  static final Map<String, _CacheEntry> _cache = {};

  Transaction? _getCached(String noResi) {
    final entry = _cache[noResi];
    if (entry == null) return null;
    if (entry.isExpired) {
      _cache.remove(noResi);
      return null;
    }
    return entry.data;
  }

  void _setCache(String noResi, Transaction tx) {
    _cache[noResi] = _CacheEntry(tx);
  }

  Future<Transaction> trackByResi(String noResi) async {
    final cached = _getCached(noResi);
    if (cached != null) return cached;

    final res = await _api.get('${ApiConstants.track}/$noResi');
    final tx = Transaction.fromJson(res.data as Map<String, dynamic>);
    _setCache(noResi, tx);
    return tx;
  }
}
