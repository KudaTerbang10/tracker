import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/api_constants.dart';
import '../datasources/remote/api_service.dart';
import '../models/transaction.dart';

final trackRepositoryProvider = Provider<TrackRepository>((ref) => TrackRepository());

class TrackRepository {
  final _api = ApiService();

  Future<Transaction> trackByResi(String noResi) async {
    final res = await _api.get('${ApiConstants.track}/$noResi');
    return Transaction.fromJson(res.data as Map<String, dynamic>);
  }
}
