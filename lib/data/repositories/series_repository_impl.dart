import 'dart:math';

import '../../domain/entities/series.dart';
import '../../domain/repositories/series_repository.dart';
import '../local/database/daos/vod_dao.dart';
import '../remote/api/xtream_api.dart';

class SeriesRepositoryImpl implements SeriesRepository {
  SeriesRepositoryImpl(this._api, this._dao);
  final XtreamApi _api;
  final VodDao    _dao;

  @override
  Future<List<SeriesCategory>> getCategories() => _dao.getSeriesCategories();

  @override
  Future<List<SeriesItem>> getSeriesByCategory(int categoryId) =>
      _dao.getSeriesByCategory(categoryId);

  @override
  Future<SeriesItem?> getSeriesById(int id) => _dao.getSeriesById(id);

  @override
  Future<List<SeriesItem>> searchSeries(String query) => _dao.searchSeries(query);

  @override
  Future<List<Season>> getSeasons(int seriesId) async {
    var episodes = await _dao.getEpisodesBySeries(seriesId);
    if (episodes.isEmpty) {
      final (meta, apiEpisodes) = await _api.getSeriesInfo(seriesId);
      // Best-effort metadata enrichment — must never block episode insertion
      if (meta != null) {
        try { await _dao.updateSeriesMeta(seriesId, meta); } catch (_) {}
      }
      episodes = apiEpisodes;
      await _dao.insertEpisodes(seriesId, episodes);
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
        try {
          final (meta, episodes) = await _api.getSeriesInfo(id);
          if (meta != null) {
            try { await _dao.updateSeriesMeta(id, meta); } catch (_) {}
          }
          if (episodes.isNotEmpty) await _dao.insertEpisodes(id, episodes);
        } catch (_) {}
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
    final map = <int, List<Episode>>{};
    for (final ep in episodes) {
      map.putIfAbsent(ep.seasonNumber, () => []).add(ep);
    }
    return map.entries
        .map((e) => Season(number: e.key, episodes: e.value..sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber))))
        .toList()
      ..sort((a, b) => a.number.compareTo(b.number));
  }
}
