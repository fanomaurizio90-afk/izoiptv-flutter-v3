import 'package:sqflite/sqflite.dart';
import '../../../../domain/entities/vod.dart';
import '../../../../domain/entities/series.dart';
import '../../../../domain/entities/continue_watching.dart';
import '../app_database.dart';

class VodDao {
  VodDao._();
  static final VodDao instance = VodDao._();

  Future<Database> get _db async => AppDatabase.instance.database;

  // ─── VOD Categories ─────────────────────────────────────────────────────────

  Future<List<VodCategory>> getVodCategories() async {
    final db   = await _db;
    final rows = await db.query('vod_categories', orderBy: 'sort_order ASC, name ASC');
    return rows.map((r) => VodCategory(id: r['id'] as int, name: r['name'] as String)).toList();
  }

  Future<void> insertVodCategories(List<VodCategory> cats) async {
    final db    = await _db;
    final batch = db.batch();
    for (final c in cats) {
      batch.insert('vod_categories', {'id': c.id, 'name': c.name},
          conflictAlgorithm: ConflictAlgorithm.ignore); // preserve sort_order
    }
    await batch.commit(noResult: true);
  }

  Future<void> saveVodCategoryOrder(List<VodCategory> ordered) async {
    final db    = await _db;
    final batch = db.batch();
    for (var i = 0; i < ordered.length; i++) {
      batch.update('vod_categories', {'sort_order': i},
          where: 'id = ?', whereArgs: [ordered[i].id]);
    }
    await batch.commit(noResult: true);
  }

  // ─── VOD ────────────────────────────────────────────────────────────────────

  Future<List<VodItem>> getVodByCategory(int categoryId) async {
    final db   = await _db;
    final rows = await db.query('vod',
        where: 'category_id = ?', whereArgs: [categoryId],
        orderBy: 'added DESC, id DESC');
    return rows.map(_rowToVod).toList();
  }

  Future<VodItem?> getVodById(int id) async {
    final db   = await _db;
    final rows = await db.query('vod', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return _rowToVod(rows.first);
  }

  Future<List<VodItem>> searchVod(String query) async {
    final db = await _db;
    final escaped = query
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    final rows = await db.rawQuery(
      "SELECT * FROM vod WHERE name LIKE ? ESCAPE '\\' LIMIT 200",
      ['%$escaped%'],
    );
    return rows.map(_rowToVod).toList();
  }

  Future<List<VodItem>> getAllVod({int limit = 500}) async {
    final db   = await _db;
    final rows = await db.query('vod', orderBy: 'added DESC, id DESC', limit: limit);
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
          'added':               v.added ?? 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Update only metadata fields — preserves stream_url, category_id, favourites.
  Future<void> updateVodMeta(int id, VodItem meta) async {
    final db  = await _db;
    final map = <String, Object?>{};
    if (meta.posterUrl   != null) map['poster_url']    = meta.posterUrl;
    if (meta.backdropUrl != null) map['backdrop_url']  = meta.backdropUrl;
    if (meta.plot        != null) map['plot']          = meta.plot;
    if (meta.genre       != null) map['genre']         = meta.genre;
    if (meta.releaseDate != null) map['release_date']  = meta.releaseDate;
    if (meta.rating      != null) map['rating']        = meta.rating;
    if (meta.durationSecs!= null) map['duration_secs'] = meta.durationSecs;
    if (map.isEmpty) return;
    await db.update('vod', map, where: 'id = ?', whereArgs: [id]);
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

  Future<List<int>> getVodIdsMissingMeta() async {
    final db   = await _db;
    final rows = await db.query('vod', columns: ['id'], where: 'poster_url IS NULL');
    return rows.map((r) => r['id'] as int).toList();
  }

  // ─── Series Categories ───────────────────────────────────────────────────────

  Future<List<SeriesCategory>> getSeriesCategories() async {
    final db   = await _db;
    final rows = await db.query('series_categories', orderBy: 'sort_order ASC, name ASC');
    return rows.map((r) => SeriesCategory(id: r['id'] as int, name: r['name'] as String)).toList();
  }

  Future<void> insertSeriesCategories(List<SeriesCategory> cats) async {
    final db    = await _db;
    final batch = db.batch();
    for (final c in cats) {
      batch.insert('series_categories', {'id': c.id, 'name': c.name},
          conflictAlgorithm: ConflictAlgorithm.ignore); // preserve sort_order
    }
    await batch.commit(noResult: true);
  }

  Future<void> saveSeriesCategoryOrder(List<SeriesCategory> ordered) async {
    final db    = await _db;
    final batch = db.batch();
    for (var i = 0; i < ordered.length; i++) {
      batch.update('series_categories', {'sort_order': i},
          where: 'id = ?', whereArgs: [ordered[i].id]);
    }
    await batch.commit(noResult: true);
  }

  // ─── Series ──────────────────────────────────────────────────────────────────

  Future<List<SeriesItem>> getSeriesByCategory(int categoryId) async {
    final db   = await _db;
    final rows = await db.query('series',
        where: 'category_id = ?', whereArgs: [categoryId],
        orderBy: 'added DESC, id DESC');
    return rows.map(_rowToSeries).toList();
  }

  Future<SeriesItem?> getSeriesById(int id) async {
    final db   = await _db;
    final rows = await db.query('series', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return _rowToSeries(rows.first);
  }

  Future<List<SeriesItem>> searchSeries(String query) async {
    final db = await _db;
    final escaped = query
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    final rows = await db.rawQuery(
      "SELECT * FROM series WHERE name LIKE ? ESCAPE '\\' LIMIT 200",
      ['%$escaped%'],
    );
    return rows.map(_rowToSeries).toList();
  }

  Future<List<SeriesItem>> getAllSeries({int limit = 500}) async {
    final db   = await _db;
    final rows = await db.query('series', orderBy: 'added DESC, id DESC', limit: limit);
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
          'added':        s.added ?? 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Update only metadata fields for a series record.
  Future<void> updateSeriesMeta(int id, SeriesItem meta) async {
    final db  = await _db;
    final map = <String, Object?>{};
    if (meta.posterUrl   != null) map['poster_url']   = meta.posterUrl;
    if (meta.backdropUrl != null) map['backdrop_url'] = meta.backdropUrl;
    if (meta.plot        != null) map['plot']         = meta.plot;
    if (meta.genre       != null) map['genre']        = meta.genre;
    if (meta.releaseDate != null) map['release_date'] = meta.releaseDate;
    if (meta.rating      != null) map['rating']       = meta.rating;
    if (map.isEmpty) return;
    await db.update('series', map, where: 'id = ?', whereArgs: [id]);
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

  Future<List<int>> getSeriesIdsMissingMeta() async {
    final db   = await _db;
    final rows = await db.query('series', columns: ['id'], where: 'poster_url IS NULL');
    return rows.map((r) => r['id'] as int).toList();
  }

  // ─── Episodes ────────────────────────────────────────────────────────────────

  Future<Episode?> getEpisodeById(int id) async {
    final db   = await _db;
    final rows = await db.query('episodes', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return _rowToEpisode(rows.first);
  }

  Future<List<Episode>> getEpisodesBySeries(int seriesId) async {
    final db   = await _db;
    final rows = await db.query(
      'episodes',
      where: 'series_id = ? AND id > 0',
      whereArgs: [seriesId],
      orderBy: 'season_number ASC, episode_number ASC',
    );
    return rows.map(_rowToEpisode).toList();
  }

  Future<void> insertEpisodes(int seriesId, List<Episode> episodes) async {
    final db    = await _db;
    final batch = db.batch();
    batch.delete('episodes', where: 'series_id = ?', whereArgs: [seriesId]);
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
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  // ─── Continue Watching ───────────────────────────────────────────────────────

  Future<List<ContinueWatchingItem>> getInProgressMovies({int limit = 20}) async {
    final db   = await _db;
    final rows = await db.rawQuery('''
      SELECT wh.content_id, wh.content_name, wh.position_secs, wh.duration_secs,
             wh.thumbnail_url, v.poster_url
      FROM watch_history wh
      LEFT JOIN vod v ON v.id = wh.content_id
      WHERE wh.content_type = 'movie'
        AND wh.position_secs > 30
        AND wh.duration_secs > 0
        AND wh.position_secs < (wh.duration_secs - 30)
      ORDER BY wh.updated_at DESC
      LIMIT $limit
    ''');
    return rows.map((r) => ContinueWatchingItem(
      contentId:   r['content_id'] as int,
      contentType: 'movie',
      contentName: r['content_name'] as String,
      positionSecs: r['position_secs'] as int,
      durationSecs: r['duration_secs'] as int,
      posterUrl:   _s(r, 'poster_url') ?? _s(r, 'thumbnail_url'),
    )).toList();
  }

  Future<List<ContinueWatchingItem>> getInProgressEpisodes({int limit = 20}) async {
    final db   = await _db;
    final rows = await db.rawQuery('''
      SELECT wh.content_id, wh.content_name, wh.position_secs, wh.duration_secs,
             wh.episode_id, wh.thumbnail_url,
             s.poster_url  AS series_poster,
             s.name        AS series_name,
             e.season_number, e.episode_number
      FROM watch_history wh
      LEFT JOIN series   s ON s.id = wh.content_id
      LEFT JOIN episodes e ON e.id = wh.episode_id
      WHERE wh.content_type = 'episode'
        AND wh.position_secs > 30
        AND wh.duration_secs > 0
        AND wh.position_secs < (wh.duration_secs - 30)
      ORDER BY wh.updated_at DESC
      LIMIT $limit
    ''');
    return rows.map((r) => ContinueWatchingItem(
      contentId:    r['content_id'] as int,
      contentType:  'episode',
      contentName:  r['content_name'] as String,
      positionSecs: r['position_secs'] as int,
      durationSecs: r['duration_secs'] as int,
      episodeId:    r['episode_id'] as int?,
      posterUrl:    _s(r, 'series_poster') ?? _s(r, 'thumbnail_url'),
      seriesName:   _s(r, 'series_name'),
      seasonNumber: r['season_number'] as int?,
      episodeNumber: r['episode_number'] as int?,
    )).toList();
  }

  // ─── Mappers ─────────────────────────────────────────────────────────────────

  String? _s(Map<String, dynamic> r, String key) {
    final v = r[key] as String?;
    return (v == null || v.isEmpty) ? null : v;
  }

  double? _d(Map<String, dynamic> r, String key) =>
      (r[key] as num?)?.toDouble();

  VodItem _rowToVod(Map<String, dynamic> r) => VodItem(
    id:                 r['id'] as int,
    name:               r['name'] as String,
    streamUrl:          r['stream_url'] as String,
    categoryId:         r['category_id'] as int,
    posterUrl:          _s(r, 'poster_url'),
    backdropUrl:        _s(r, 'backdrop_url'),
    plot:               _s(r, 'plot'),
    genre:              _s(r, 'genre'),
    releaseDate:        _s(r, 'release_date'),
    rating:             _d(r, 'rating'),
    durationSecs:       r['duration_secs'] as int?,
    containerExtension: r['container_extension'] as String?,
    isFavourite:        (r['is_favourite'] as int? ?? 0) == 1,
    added:              r['added'] as int?,
  );

  SeriesItem _rowToSeries(Map<String, dynamic> r) => SeriesItem(
    id:          r['id'] as int,
    name:        r['name'] as String,
    categoryId:  r['category_id'] as int,
    posterUrl:   _s(r, 'poster_url'),
    backdropUrl: _s(r, 'backdrop_url'),
    plot:        _s(r, 'plot'),
    genre:       _s(r, 'genre'),
    releaseDate: _s(r, 'release_date'),
    rating:      _d(r, 'rating'),
    isFavourite: (r['is_favourite'] as int? ?? 0) == 1,
    added:       r['added'] as int?,
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
    isWatched:          false,
  );
}
