import '../../domain/entities/channel.dart';
import '../../domain/repositories/channel_repository.dart';
import '../local/database/daos/channel_dao.dart';
import '../remote/api/xtream_api.dart';

class ChannelRepositoryImpl implements ChannelRepository {
  ChannelRepositoryImpl(this._api, this._dao);
  final XtreamApi  _api;
  final ChannelDao _dao;

  @override
  Future<List<ChannelCategory>> getCategories() => _dao.getCategories();

  @override
  Future<List<Channel>> getChannelsByCategory(int categoryId) =>
      _dao.getByCategory(categoryId);

  @override
  Future<List<Channel>> searchChannels(String query) => _dao.search(query);

  @override
  Future<void> syncChannels() async {
    final cats     = await _api.getLiveCategories();
    final channels = await _api.getLiveStreams();
    await _dao.insertCategories(cats);
    await _dao.insertChannels(channels);
  }

  @override
  Future<void> toggleFavourite(int channelId, bool isFav) =>
      _dao.setFavourite(channelId, isFav);

  @override
  Future<List<Channel>> getFavourites() => _dao.getFavourites();

  @override
  Future<void> saveCategoryOrder(List<ChannelCategory> ordered) =>
      _dao.saveCategoryOrder(ordered);

  @override
  Future<List<Map<String, String>>> getShortEpg(int streamId) =>
      _api.getShortEpg(streamId);
}
