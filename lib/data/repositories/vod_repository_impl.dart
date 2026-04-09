import 'dart:math';

import '../../domain/entities/vod.dart';
import '../../domain/repositories/vod_repository.dart';
import '../../core/utils/retry.dart';
import '../local/database/daos/vod_dao.dart';
import '../remote/api/xtream_api.dart';

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
      final fresh = await withRetry(
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
      added:              v.added,
      cast:               v.cast,
      director:           v.director,
      tmdbId:             v.tmdbId,
      youtubeTrailer:     v.youtubeTrailer,
    );
  }

  @override
  Future<VodItem?> getVodById(int id) async {
    final item = await _dao.getVodById(id);
    return item == null ? null : _withFreshUrl(item);
  }

  @override
  Future<List<VodItem>> getAllVod({int limit = 500}) async {
    final items = await _dao.getAllVod(limit: limit);
    return items.map(_withFreshUrl).toList();
  }

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
        final meta = await withRetry(() => _api.getVodInfo(id));
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

  @override
  Future<void> saveVodCategoryOrder(List<VodCategory> ordered) =>
      _dao.saveVodCategoryOrder(ordered);
}
