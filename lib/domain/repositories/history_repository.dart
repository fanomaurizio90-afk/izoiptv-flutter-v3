abstract interface class HistoryRepository {
  Future<void> savePosition({
    required int contentId,
    required String contentType,
    required String contentName,
    required int positionSecs,
    required int durationSecs,
    int? episodeId,
    String? thumbnailUrl,
  });
  Future<List<Map<String, dynamic>>> getRecentHistory({int limit = 20});
  Future<Map<String, dynamic>?> getPosition(int contentId, String contentType, {int? episodeId});
  Future<void> clearHistory();
}
