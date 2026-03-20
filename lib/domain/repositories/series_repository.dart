import '../entities/series.dart';

abstract interface class SeriesRepository {
  Future<List<SeriesCategory>> getCategories();
  Future<List<SeriesItem>> getSeriesByCategory(int categoryId);
  Future<List<SeriesItem>> searchSeries(String query);
  Future<SeriesItem?> getSeriesById(int id);
  Future<List<Season>> getSeasons(int seriesId);
  Future<void> syncSeries();
  Future<void> toggleFavourite(int seriesId, bool isFav);
  Future<List<SeriesItem>> getFavourites();
}
