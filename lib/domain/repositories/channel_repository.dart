import '../entities/channel.dart';

abstract interface class ChannelRepository {
  Future<List<ChannelCategory>> getCategories();
  Future<List<Channel>> getChannelsByCategory(int categoryId);
  Future<List<Channel>> searchChannels(String query);
  Future<void> syncChannels();
  Future<void> toggleFavourite(int channelId, bool isFav);
  Future<List<Channel>>         getFavourites();
  Future<void>                  saveCategoryOrder(List<ChannelCategory> ordered);
}
