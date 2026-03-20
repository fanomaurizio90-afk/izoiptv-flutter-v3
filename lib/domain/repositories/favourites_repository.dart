import '../entities/channel.dart';
import '../entities/vod.dart';
import '../entities/series.dart';

abstract interface class FavouritesRepository {
  Future<List<Channel>>     getFavouriteChannels();
  Future<List<VodItem>>     getFavouriteVod();
  Future<List<SeriesItem>>  getFavouriteSeries();
}
