import 'dart:math';

import '../../domain/entities/series.dart';
import '../../domain/repositories/series_repository.dart';
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
      final fresh = await _withRetry(
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
  Future<List<SeriesItem>> searchSeries(String query) => _dao.searchSeries(query);

  @override
  Future<List<Season>> getSeasons(int seriesId) async {
    var episodes = await _dao.getEpisodesBySeries(seriesId);
    if (episodes.isEmpty) {
      try {
        final (meta, apiEpisodes) = await _api.getSeriesInfo(seriesId);
        // Best-effort metadata enrichment — must never block episode insertion
        if (meta != null) {
          try { await _dao.updateSeriesMeta(seriesId, meta); } catch (_) {}
        }
        episodes = apiEpisodes;
        if (episodes.isNotEmpty) await _dao.insertEpisodes(seriesId, episodes);
      } catch (e) {
        // Timeout / 503 — return empty list; UI will show error state
        rethrow;
      }
    }
    return _groupIntoSeasons(episodes);
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
        final result = await _withRetry(() => _api.getSeriesInfo(id));
        if (result != null) {
          final (meta, episodes) = result;
          if (meta != null) {
            try { await _dao.updateSeriesMeta(id, meta); } catch (_) {}
          }
          if (episodes.isNotEmpty) await _dao.insertEpisodes(id, episodes);
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
