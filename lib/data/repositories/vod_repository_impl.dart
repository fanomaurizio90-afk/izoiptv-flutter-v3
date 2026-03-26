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
  Future<List<VodItem>> getVodByCategory(int categoryId) async {
    var items = await _dao.getVodByCategory(categoryId);
    if (items.isEmpty) {
      // Fetch only this category from the server on demand
      final fresh = await _withRetry(
        () => _api.getVodStreams(categoryId: categoryId),
      );
      if (fresh != null && fresh.isNotEmpty) {
        await _dao.insertVod(fresh);
        items = await _dao.getVodByCategory(categoryId);
      }
    }
    // Rebuild stream URLs from current API credentials.
    // Fixes stale URLs from old syncs and empty container_extension values.
    return items.map(_withFreshUrl).toList();
  }

  VodItem _withFreshUrl(VodItem v) {
    final ext = (v.containerExtension?.isNotEmpty == true) ? v.containerExtension! : 'mp4';
    final url = _api.getVodStreamUrl(v.id, ext);
    if (url == v.streamUrl) return v;
    return VodItem(
      id:                 v.id,
      name:               v.name,
      streamUrl:          url,
      categoryId:         v.categoryId,
      posterUrl:          v.posterUrl,
      backdropUrl:        v.backdropUrl,
      plot:               v.plot,
      genre:              v.genre,
      releaseDate:        v.releaseDate,
      rating:             v.rating,
      durationSecs:       v.durationSecs,
      containerExtension: v.containerExtension,
      isFavourite:        v.isFavourite,
    );
  }

  @override
  Future<VodItem?> getVodById(int id) => _dao.getVodById(id);

  @override
  Future<List<VodItem>> searchVod(String query) async {
    final items = await _dao.searchVod(query);
    return items.map(_withFreshUrl).toList();
  }

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
