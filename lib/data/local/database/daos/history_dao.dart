import 'package:sqflite/sqflite.dart';
import '../app_database.dart';

class HistoryDao {
  HistoryDao._();
  static final HistoryDao instance = HistoryDao._();

  Future<Database> get _db async => AppDatabase.instance.database;

  Future<void> upsertPosition({
    required int contentId,
    required String contentType,
    required String contentName,
    required int positionSecs,
    required int durationSecs,
    int? episodeId,
    String? thumbnailUrl,
  }) async {
    final db = await _db;
    await db.insert(
      'watch_history',
      {
        'content_id':    contentId,
        'content_type':  contentType,
        'content_name':  contentName,
        'position_secs': positionSecs,
        'duration_secs': durationSecs,
        'episode_id':    episodeId,
        'thumbnail_url': thumbnailUrl,
        'updated_at':    DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getRecent({int limit = 20}) async {
    final db = await _db;
    return db.query(
      'watch_history',
      orderBy: 'updated_at DESC',
      limit: limit,
    );
  }

  Future<Map<String, dynamic>?> getPosition(
    int contentId,
    String contentType, {
    int? episodeId,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'watch_history',
      where: episodeId != null
          ? 'content_id = ? AND content_type = ? AND episode_id = ?'
          : 'content_id = ? AND content_type = ? AND episode_id IS NULL',
      whereArgs: episodeId != null ? [contentId, contentType, episodeId] : [contentId, contentType],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> clear() async {
    final db = await _db;
    await db.delete('watch_history');
  }
}
