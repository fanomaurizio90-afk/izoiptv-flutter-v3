import '../../domain/entities/vod.dart';
import '../../domain/repositories/vod_repository.dart';
import '../local/database/daos/vod_dao.dart';
import '../remote/api/xtream_api.dart';

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
  Future<void> toggleFavourite(int vodId, bool isFav) =>
      _dao.setVodFavourite(vodId, isFav);

  @override
  Future<List<VodItem>> getFavourites() => _dao.getVodFavourites();
}
