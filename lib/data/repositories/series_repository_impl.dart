import 'dart:math';

import '../../domain/entities/series.dart';
import '../../domain/repositories/series_repository.dart';
import '../../core/utils/retry.dart';
import '../local/database/daos/vod_dao.dart';
import '../remote/api/xtream_api.dart';

class SeriesRepositoryImpl implements SeriesRepository {
  SeriesRepositoryImpl(this._api, this._dao);
  final XtreamApi _api;
  final VodDao    _dao;

  @override
  Future<List<SeriesCategory>> getCategories() => _dao.getSeriesCategories();

  @override
  Future<List<SeriesItem>> getSeriesByCategory(int categoryId) async {
    var items = await _dao.getSeriesByCategory(categoryId);
    if (items.isEmpty) {
      // Fetch only this category from the server on demand
      final fresh = await withRetry(
        () => _api.getSeries(categoryId: categoryId),
      );
      if (fresh != null && fresh.isNotEmpty) {
        await _dao.insertSeries(fresh);
        items = await _dao.getSeriesByCategory(categoryId);
      }
    }
    return items;
  }

  @override
  Future<SeriesItem?> getSeriesById(int id) => _dao.getSeriesById(id);

  @override
  Future<Episode?> getEpisodeById(int id) => _dao.getEpisodeById(id);

  @override
  Future<List<SeriesItem>> getAllSeries({int limit = 500}) => _dao.getAllSeries(limit: limit);

  @override
  Future<List<SeriesItem>> searchSeries(String query) => _dao.searchSeries(query);

  @override
  Future<List<Season>> getSeasons(int seriesId) async {
    // Always fetch from API — ensures episode IDs, extensions and URLs are
    // never stale. DB is updated as a side-effect for offline fallback.
    bool apiSucceeded = false;
    try {
      final (meta, apiEpisodes) = await _api.getSeriesInfo(seriesId);
      apiSucceeded = true;
      if (meta != null) {
        try { await _dao.updateSeriesMeta(seriesId, meta); } catch (_) {}
      }
      if (apiEpisodes.isNotEmpty) {
        await _dao.insertEpisodes(seriesId, apiEpisodes);
        return _groupIntoSeasons(apiEpisodes.map(_withFreshUrl).toList());
      }
      // API responded but returned no valid episodes — don't serve stale DB data
      return [];
    } catch (_) {
      // API unavailable — fall back to DB only if we never got a response
    }
    if (apiSucceeded) return [];
    // Offline fallback: use cached episodes with refreshed URLs
    final cached = await _dao.getEpisodesBySeries(seriesId);
    return _groupIntoSeasons(cached.map(_withFreshUrl).toList());
  }

  Episode _withFreshUrl(Episode ep) {
    final ext = (ep.containerExtension?.isNotEmpty == true)
        ? ep.containerExtension!
        : 'mkv';
    final url = _api.getEpisodeStreamUrl(ep.id, ext);
    if (url == ep.streamUrl) return ep;
    return Episode(
      id:                 ep.id,
      seriesId:           ep.seriesId,
      seasonNumber:       ep.seasonNumber,
      episodeNumber:      ep.episodeNumber,
      title:              ep.title,
      streamUrl:          url,
      thumbnailUrl:       ep.thumbnailUrl,
      plot:               ep.plot,
      durationSecs:       ep.durationSecs,
      containerExtension: ep.containerExtension,
    );
  }

  @override
  Future<void> syncSeries() async {
    final cats   = await _api.getSeriesCategories();
    final series = await _api.getSeries();
    await _dao.insertSeriesCategories(cats);
    await _dao.insertSeries(series);
  }

  @override
  Future<void> enrichAll({void Function(int done, int total)? onProgress}) async {
    final ids = await _dao.getSeriesIdsMissingMeta();
    final total = ids.length;
    var done = 0;
    const concurrency = 3;
    for (var i = 0; i < ids.length; i += concurrency) {
      final batch = ids.sublist(i, min(i + concurrency, ids.length));
      await Future.wait(batch.map((id) async {
        final result = await withRetry(() => _api.getSeriesInfo(id));
        if (result != null) {
          final (meta, episodes) = result;
          if (meta != null) {
            try { await _dao.updateSeriesMeta(id, meta); } catch (_) {}
          }
          // Skip episode insertion if they're already in DB — avoids redundant
          // writes when enrichAll is called more than once for the same series.
          if (episodes.isNotEmpty) {
            final existing = await _dao.getEpisodesBySeries(id);
            if (existing.isEmpty) await _dao.insertEpisodes(id, episodes);
          }
        }
        done++;
        onProgress?.call(done, total);
      }));
    }
  }

  @override
  Future<void> toggleFavourite(int seriesId, bool isFav) =>
      _dao.setSeriesFavourite(seriesId, isFav);

  @override
  Future<List<SeriesItem>> getFavourites() => _dao.getSeriesFavourites();

  @override
  Future<void> saveSeriesCategoryOrder(List<SeriesCategory> ordered) =>
      _dao.saveSeriesCategoryOrder(ordered);


  List<Season> _groupIntoSeasons(List<Episode> episodes) {
    // Sort by season then episode first — insertion order into the map is correct
    final sorted = [...episodes]
      ..sort((a, b) {
        final s = a.seasonNumber.compareTo(b.seasonNumber);
        return s != 0 ? s : a.episodeNumber.compareTo(b.episodeNumber);
      });
    final map = <int, List<Episode>>{};
    for (final ep in sorted) {
      map.putIfAbsent(ep.seasonNumber, () => []).add(ep);
    }
    return map.entries
        .map((e) => Season(number: e.key, episodes: e.value))
        .toList()
      ..sort((a, b) => a.number.compareTo(b.number));
  }
}
