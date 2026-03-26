import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../data/local/database/daos/channel_dao.dart';
import '../../data/local/database/daos/history_dao.dart';
import '../../data/local/database/daos/vod_dao.dart';
import '../../data/remote/api/xtream_api.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../services/activation_service.dart';
import '../../data/repositories/channel_repository_impl.dart';
import '../../data/repositories/favourites_repository_impl.dart';
import '../../data/repositories/history_repository_impl.dart';
import '../../data/repositories/series_repository_impl.dart';
import '../../data/repositories/vod_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/channel_repository.dart';
import '../../domain/repositories/favourites_repository.dart';
import '../../domain/repositories/history_repository.dart';
import '../../domain/repositories/series_repository.dart';
import '../../domain/repositories/vod_repository.dart';
import '../../services/sync_service.dart';
export '../../services/sync_service.dart' show SyncState, SyncIdle, SyncDownloading, SyncEnriching, SyncDone, SyncNotifier;

// ─── Infrastructure ──────────────────────────────────────────────────────────

final dioProvider = Provider<Dio>((_) {
  return Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 120), // 120s — large IPTV libraries
    headers: {'User-Agent': 'IZO-IPTV/1.0'},
  ));
});

final secureStorageProvider = Provider<FlutterSecureStorage>((_) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
});

// ─── API ──────────────────────────────────────────────────────────────────────

final xtreamApiProvider = Provider<XtreamApi>((ref) => XtreamApi(ref.read(dioProvider)));

final activationServiceProvider = Provider<ActivationService>((ref) => ActivationService(ref.read(dioProvider)));

// ─── DAOs ─────────────────────────────────────────────────────────────────────

final channelDaoProvider = Provider<ChannelDao>   ((_) => ChannelDao.instance);
final vodDaoProvider     = Provider<VodDao>        ((_) => VodDao.instance);
final historyDaoProvider = Provider<HistoryDao>    ((_) => HistoryDao.instance);

// ─── Repositories ─────────────────────────────────────────────────────────────

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    ref.read(secureStorageProvider),
    ref.read(xtreamApiProvider),
  );
});

final channelRepositoryProvider = Provider<ChannelRepository>((ref) {
  return ChannelRepositoryImpl(
    ref.read(xtreamApiProvider),
    ref.read(channelDaoProvider),
  );
});

final vodRepositoryProvider = Provider<VodRepository>((ref) {
  return VodRepositoryImpl(
    ref.read(xtreamApiProvider),
    ref.read(vodDaoProvider),
  );
});

final seriesRepositoryProvider = Provider<SeriesRepository>((ref) {
  return SeriesRepositoryImpl(
    ref.read(xtreamApiProvider),
    ref.read(vodDaoProvider),
  );
});

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  return HistoryRepositoryImpl(ref.read(historyDaoProvider));
});

final favouritesRepositoryProvider = Provider<FavouritesRepository>((ref) {
  return FavouritesRepositoryImpl(
    ref.read(channelDaoProvider),
    ref.read(vodDaoProvider),
  );
});

final syncProvider = StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  return SyncNotifier(
    ref.read(vodRepositoryProvider),
    ref.read(seriesRepositoryProvider),
    ref.read(channelRepositoryProvider),
    ref.read(secureStorageProvider),
  );
});
