import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers.dart';

final recentHistoryProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(historyRepositoryProvider).getRecentHistory(limit: 10);
});
