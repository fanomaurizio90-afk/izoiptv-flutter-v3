import '../../domain/entities/continue_watching.dart';
import '../../domain/repositories/history_repository.dart';
import '../local/database/daos/history_dao.dart';

class HistoryRepositoryImpl implements HistoryRepository {
  HistoryRepositoryImpl(this._dao);
  final HistoryDao _dao;

  @override
  Future<void> savePosition({
    required int contentId,
    required String contentType,
    required String contentName,
    required int positionSecs,
    required int durationSecs,
    int? episodeId,
    String? thumbnailUrl,
  }) => _dao.upsertPosition(
    contentId:    contentId,
    contentType:  contentType,
    contentName:  contentName,
    positionSecs: positionSecs,
    durationSecs: durationSecs,
    episodeId:    episodeId,
    thumbnailUrl: thumbnailUrl,
  );

  @override
  Future<List<Map<String, dynamic>>> getRecentHistory({int limit = 20}) =>
      _dao.getRecent(limit: limit);

  @override
  Future<Map<String, dynamic>?> getPosition(
    int contentId,
    String contentType, {
    int? episodeId,
  }) => _dao.getPosition(contentId, contentType, episodeId: episodeId);

  @override
  Future<void> clearHistory() => _dao.clear();

  @override
  Future<List<ContinueWatchingItem>> getInProgressMovies({int limit = 20}) =>
      _dao.getInProgressMovies(limit: limit);

  @override
  Future<List<ContinueWatchingItem>> getInProgressEpisodes({int limit = 20}) =>
      _dao.getInProgressEpisodes(limit: limit);
}
