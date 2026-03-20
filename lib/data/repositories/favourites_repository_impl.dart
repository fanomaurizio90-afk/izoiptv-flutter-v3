import '../../domain/entities/channel.dart';
import '../../domain/entities/vod.dart';
import '../../domain/entities/series.dart';
import '../../domain/repositories/favourites_repository.dart';
import '../local/database/daos/channel_dao.dart';
import '../local/database/daos/vod_dao.dart';

class FavouritesRepositoryImpl implements FavouritesRepository {
  FavouritesRepositoryImpl(this._channelDao, this._vodDao);
  final ChannelDao _channelDao;
  final VodDao     _vodDao;

  @override
  Future<List<Channel>>    getFavouriteChannels() => _channelDao.getFavourites();
  @override
  Future<List<VodItem>>    getFavouriteVod()      => _vodDao.getVodFavourites();
  @override
  Future<List<SeriesItem>> getFavouriteSeries()   => _vodDao.getSeriesFavourites();
}
