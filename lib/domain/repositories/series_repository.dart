import '../entities/series.dart';

abstract interface class SeriesRepository {
  Future<List<SeriesCategory>> getCategories();
  Future<List<SeriesItem>> getSeriesByCategory(int categoryId);
  Future<List<SeriesItem>> getAllSeries({int limit = 500});
  Future<List<SeriesItem>> searchSeries(String query);
  Future<SeriesItem?> getSeriesById(int id);
  Future<List<Season>> getSeasons(int seriesId);
  Future<Episode?> getEpisodeById(int id);
  Future<void> syncSeries();
  Future<void> enrichAll({void Function(int done, int total)? onProgress});
  Future<void>             toggleFavourite(int seriesId, bool isFav);
  Future<List<SeriesItem>> getFavourites();
  Future<void>             saveSeriesCategoryOrder(List<SeriesCategory> ordered);
}
