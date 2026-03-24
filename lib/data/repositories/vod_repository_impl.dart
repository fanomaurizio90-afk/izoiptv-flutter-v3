import 'dart:math';

import '../../domain/entities/vod.dart';
import '../../domain/repositories/vod_repository.dart';
import '../local/database/daos/vod_dao.dart';
import '../remote/api/xtream_api.dart';

/// Retries [fn] up to [maxAttempts] times with [delay] between attempts.
/// Returns null silently if all attempts fail.
Future<T?> _withRetry<T>(
  Future<T> Function() fn, {
  int      maxAttempts = 3,
  Duration delay       = const Duration(seconds: 2),
}) async {
  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    try {
      return await fn();
    } catch (_) {
      if (attempt < maxAttempts - 1) await Future.delayed(delay);
    }
  }
  return null;
}

class VodRepositoryImpl implements VodRepository {
  VodRepositoryImpl(this._api, this._dao);
  final XtreamApi _api;
  final VodDao    _dao;

  @override
  Future<List<VodCategory>> getCategories() => _dao.getVodCategories();

  @override
  Future<List<VodItem>> getVodByCategory(int categoryId) =>
      _dao.getVodByCategory(categoryId);

  @override
  Future<VodItem?> getVodById(int id) => _dao.getVodById(id);

  @override
  Future<List<VodItem>> searchVod(String query) => _dao.searchVod(query);

  @override
  Future<void> syncVod() async {
    final cats  = await _api.getVodCategories();
    final items = await _api.getVodStreams();
    await _dao.insertVodCategories(cats);
    await _dao.insertVod(items);
  }

  @override
  Future<void> fetchVodInfo(int vodId) async {
    final meta = await _api.getVodInfo(vodId);
    if (meta != null) await _dao.updateVodMeta(vodId, meta);
  }

  @override
  Future<void> enrichAll({void Function(int done, int total)? onProgress}) async {
    final ids = await _dao.getVodIdsMissingMeta();
    final total = ids.length;
    var done = 0;
    const concurrency = 5;
    for (var i = 0; i < ids.length; i += concurrency) {
      final batch = ids.sublist(i, min(i + concurrency, ids.length));
      await Future.wait(batch.map((id) async {
        final meta = await _withRetry(() => _api.getVodInfo(id));
        if (meta != null) await _dao.updateVodMeta(id, meta);
        done++;
        onProgress?.call(done, total);
      }));
    }
  }

  @override
  Future<void> toggleFavourite(int vodId, bool isFav) =>
      _dao.setVodFavourite(vodId, isFav);

  @override
  Future<List<VodItem>> getFavourites() => _dao.getVodFavourites();
}
