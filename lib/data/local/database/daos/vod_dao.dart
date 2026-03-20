import 'package:sqflite/sqflite.dart';
import '../../../../domain/entities/vod.dart';
import '../../../../domain/entities/series.dart';
import '../app_database.dart';

class VodDao {
  VodDao._();
  static final VodDao instance = VodDao._();

  Future<Database> get _db async => AppDatabase.instance.database;

  // ─── VOD Categories ─────────────────────────────────────────────────────────

  Future<List<VodCategory>> getVodCategories() async {
    final db   = await _db;
    final rows = await db.query('vod_categories', orderBy: 'name ASC');
    return rows.map((r) => VodCategory(id: r['id'] as int, name: r['name'] as String)).toList();
  }

  Future<void> insertVodCategories(List<VodCategory> cats) async {
    final db    = await _db;
    final batch = db.batch();
    for (final c in cats) {
      batch.insert('vod_categories', {'id': c.id, 'name': c.name},
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  // ─── VOD ────────────────────────────────────────────────────────────────────

  Future<List<VodItem>> getVodByCategory(int categoryId) async {
    final db   = await _db;
    final rows = await db.query('vod', where: 'category_id = ?', whereArgs: [categoryId]);
    return rows.map(_rowToVod).toList();
  }

  Future<VodItem?> getVodById(int id) async {
    final db   = await _db;
    final rows = await db.query('vod', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return _rowToVod(rows.first);
  }

  Future<List<VodItem>> searchVod(String query) async {
    final db   = await _db;
    final rows = await db.query('vod', where: 'name LIKE ?', whereArgs: ['%$query%'], limit: 200);
    return rows.map(_rowToVod).toList();
  }

  Future<List<VodItem>> getVodFavourites() async {
    final db   = await _db;
    final rows = await db.query('vod', where: 'is_favourite = 1', orderBy: 'name ASC');
    return rows.map(_rowToVod).toList();
  }

  Future<void> insertVod(List<VodItem> items) async {
    final db    = await _db;
    final batch = db.batch();
    for (final v in items) {
      batch.insert(
        'vod',
        {
          'id':                  v.id,
          'name':                v.name,
          'stream_url':          v.streamUrl,
          'category_id':         v.categoryId,
          'poster_url':          v.posterUrl,
          'backdrop_url':        v.backdropUrl,
          'plot':                v.plot,
          'genre':               v.genre,
          'release_date':        v.releaseDate,
          'rating':              v.rating,
          'duration_secs':       v.durationSecs,
          'container_extension': v.containerExtension,
          'is_favourite':        v.isFavourite ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> setVodFavourite(int id, bool isFav) async {
    final db = await _db;
    await db.update('vod', {'is_favourite': isFav ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> vodCount() async {
    final db  = await _db;
    final res = await db.rawQuery('SELECT COUNT(*) FROM vod');
    return Sqflite.firstIntValue(res) ?? 0;
  }

  // ─── Series Categories ───────────────────────────────────────────────────────

  Future<List<SeriesCategory>> getSeriesCategories() async {
    final db   = await _db;
    final rows = await db.query('series_categories', orderBy: 'name ASC');
    return rows.map((r) => SeriesCategory(id: r['id'] as int, name: r['name'] as String)).toList();
  }

  Future<void> insertSeriesCategories(List<SeriesCategory> cats) async {
    final db    = await _db;
    final batch = db.batch();
    for (final c in cats) {
      batch.insert('series_categories', {'id': c.id, 'name': c.name},
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  // ─── Series ──────────────────────────────────────────────────────────────────

  Future<List<SeriesItem>> getSeriesByCategory(int categoryId) async {
    final db   = await _db;
    final rows = await db.query('series', where: 'category_id = ?', whereArgs: [categoryId]);
    return rows.map(_rowToSeries).toList();
  }

  Future<SeriesItem?> getSeriesById(int id) async {
    final db   = await _db;
    final rows = await db.query('series', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return _rowToSeries(rows.first);
  }

  Future<List<SeriesItem>> searchSeries(String query) async {
    final db   = await _db;
    final rows = await db.query('series', where: 'name LIKE ?', whereArgs: ['%$query%'], limit: 200);
    return rows.map(_rowToSeries).toList();
  }

  Future<List<SeriesItem>> getSeriesFavourites() async {
    final db   = await _db;
    final rows = await db.query('series', where: 'is_favourite = 1', orderBy: 'name ASC');
    return rows.map(_rowToSeries).toList();
  }

  Future<void> insertSeries(List<SeriesItem> items) async {
    final db    = await _db;
    final batch = db.batch();
    for (final s in items) {
      batch.insert(
        'series',
        {
          'id':           s.id,
          'name':         s.name,
          'category_id':  s.categoryId,
          'poster_url':   s.posterUrl,
          'backdrop_url': s.backdropUrl,
          'plot':         s.plot,
          'genre':        s.genre,
          'release_date': s.releaseDate,
          'rating':       s.rating,
          'is_favourite': s.isFavourite ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> setSeriesFavourite(int id, bool isFav) async {
    final db = await _db;
    await db.update('series', {'is_favourite': isFav ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> seriesCount() async {
    final db  = await _db;
    final res = await db.rawQuery('SELECT COUNT(*) FROM series');
    return Sqflite.firstIntValue(res) ?? 0;
  }

  // ─── Episodes ────────────────────────────────────────────────────────────────

  Future<List<Episode>> getEpisodesBySeries(int seriesId) async {
    final db   = await _db;
    final rows = await db.query(
      'episodes',
      where: 'series_id = ?',
      whereArgs: [seriesId],
      orderBy: 'season_number ASC, episode_number ASC',
    );
    return rows.map(_rowToEpisode).toList();
  }

  Future<void> insertEpisodes(int seriesId, List<Episode> episodes) async {
    final db    = await _db;
    final batch = db.batch();
    for (final ep in episodes) {
      batch.insert(
        'episodes',
        {
          'id':                  ep.id,
          'series_id':           seriesId,
          'season_number':       ep.seasonNumber,
          'episode_number':      ep.episodeNumber,
          'title':               ep.title,
          'stream_url':          ep.streamUrl,
          'thumbnail_url':       ep.thumbnailUrl,
          'plot':                ep.plot,
          'duration_secs':       ep.durationSecs,
          'container_extension': ep.containerExtension,
          'is_watched':          ep.isWatched ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  // ─── Mappers ─────────────────────────────────────────────────────────────────

  VodItem _rowToVod(Map<String, dynamic> r) => VodItem(
    id:                 r['id'] as int,
    name:               r['name'] as String,
    streamUrl:          r['stream_url'] as String,
    categoryId:         r['category_id'] as int,
    posterUrl:          r['poster_url'] as String?,
    backdropUrl:        r['backdrop_url'] as String?,
    plot:               r['plot'] as String?,
    genre:              r['genre'] as String?,
    releaseDate:        r['release_date'] as String?,
    rating:             r['rating'] as double?,
    durationSecs:       r['duration_secs'] as int?,
    containerExtension: r['container_extension'] as String?,
    isFavourite:        (r['is_favourite'] as int? ?? 0) == 1,
  );

  SeriesItem _rowToSeries(Map<String, dynamic> r) => SeriesItem(
    id:          r['id'] as int,
    name:        r['name'] as String,
    categoryId:  r['category_id'] as int,
    posterUrl:   r['poster_url'] as String?,
    backdropUrl: r['backdrop_url'] as String?,
    plot:        r['plot'] as String?,
    genre:       r['genre'] as String?,
    releaseDate: r['release_date'] as String?,
    rating:      r['rating'] as double?,
    isFavourite: (r['is_favourite'] as int? ?? 0) == 1,
  );

  Episode _rowToEpisode(Map<String, dynamic> r) => Episode(
    id:                 r['id'] as int,
    seriesId:           r['series_id'] as int,
    seasonNumber:       r['season_number'] as int,
    episodeNumber:      r['episode_number'] as int,
    title:              r['title'] as String,
    streamUrl:          r['stream_url'] as String,
    thumbnailUrl:       r['thumbnail_url'] as String?,
    plot:               r['plot'] as String?,
    durationSecs:       r['duration_secs'] as int?,
    containerExtension: r['container_extension'] as String?,
    isWatched:          (r['is_watched'] as int? ?? 0) == 1,
  );
}
