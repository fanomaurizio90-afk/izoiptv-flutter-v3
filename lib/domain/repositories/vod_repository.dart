import '../entities/vod.dart';

abstract interface class VodRepository {
  Future<List<VodCategory>> getCategories();
  Future<List<VodItem>> getVodByCategory(int categoryId);
  Future<List<VodItem>> getAllVod({int limit = 500});
  Future<List<VodItem>> searchVod(String query);
  Future<VodItem?> getVodById(int id);
  Future<void> syncVod();
  Future<void> fetchVodInfo(int vodId);
  Future<void> enrichAll({void Function(int done, int total)? onProgress});
  Future<void>          toggleFavourite(int vodId, bool isFav);
  Future<List<VodItem>> getFavourites();
  Future<void>          saveVodCategoryOrder(List<VodCategory> ordered);
}
