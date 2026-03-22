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
      // Enrich the series record with metadata from get_series_info
      // (cover, plot, genre — often missing from the bulk get_series response)
      if (meta != null) await _dao.updateSeriesMeta(seriesId, meta);
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
