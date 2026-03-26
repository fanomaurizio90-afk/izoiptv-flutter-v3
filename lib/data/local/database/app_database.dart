import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/constants/app_constants.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();
  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), AppConstants.dbName);
    return openDatabase(
      path,
      version:   AppConstants.dbVersion,
      onCreate:  _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Migration pattern:
    //   if (oldVersion < N) { await db.execute('ALTER TABLE foo ADD COLUMN bar TEXT'); }
    // Keep migrations additive — never drop columns in the ALTER TABLE path,
    // only in a full table-recreate migration like v1→v2 below.

    // v2 → v3: rename watch_history content_type 'vod' → 'movie' or 'episode'
    if (oldVersion < 3) {
      await db.execute('''
        UPDATE watch_history
        SET content_type = 'episode'
        WHERE content_type = 'vod' AND episode_id IS NOT NULL
      ''');
      await db.execute('''
        UPDATE watch_history
        SET content_type = 'movie'
        WHERE content_type = 'vod' AND episode_id IS NULL
      ''');
    }

    // v1 → v2: drop is_watched column from episodes (recreate table)
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE episodes_new (
          id                  INTEGER PRIMARY KEY,
          series_id           INTEGER NOT NULL,
          season_number       INTEGER NOT NULL,
          episode_number      INTEGER NOT NULL,
          title               TEXT NOT NULL,
          stream_url          TEXT NOT NULL,
          thumbnail_url       TEXT,
          plot                TEXT,
          duration_secs       INTEGER,
          container_extension TEXT,
          FOREIGN KEY (series_id) REFERENCES series(id) ON DELETE CASCADE
        )
      ''');
      await db.execute('''
        INSERT INTO episodes_new
          SELECT id, series_id, season_number, episode_number, title,
                 stream_url, thumbnail_url, plot, duration_secs, container_extension
          FROM episodes
      ''');
      await db.execute('DROP TABLE episodes');
      await db.execute('ALTER TABLE episodes_new RENAME TO episodes');
      await db.execute('CREATE INDEX idx_episodes_series ON episodes(series_id)');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE channel_categories (
        id   INTEGER PRIMARY KEY,
        name TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE channels (
        id           INTEGER PRIMARY KEY,
        name         TEXT NOT NULL,
        stream_url   TEXT NOT NULL,
        category_id  INTEGER NOT NULL,
        logo_url     TEXT,
        is_favourite INTEGER DEFAULT 0,
        sort_order   INTEGER DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX idx_channels_category ON channels(category_id)');
    await db.execute('CREATE INDEX idx_channels_name ON channels(name COLLATE NOCASE)');

    await db.execute('''
      CREATE TABLE vod_categories (
        id   INTEGER PRIMARY KEY,
        name TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE vod (
        id                  INTEGER PRIMARY KEY,
        name                TEXT NOT NULL,
        stream_url          TEXT NOT NULL,
        category_id         INTEGER NOT NULL,
        poster_url          TEXT,
        backdrop_url        TEXT,
        plot                TEXT,
        genre               TEXT,
        release_date        TEXT,
        rating              REAL,
        duration_secs       INTEGER,
        container_extension TEXT,
        is_favourite        INTEGER DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX idx_vod_category ON vod(category_id)');
    await db.execute('CREATE INDEX idx_vod_name ON vod(name COLLATE NOCASE)');

    await db.execute('''
      CREATE TABLE series_categories (
        id   INTEGER PRIMARY KEY,
        name TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE series (
        id           INTEGER PRIMARY KEY,
        name         TEXT NOT NULL,
        category_id  INTEGER NOT NULL,
        poster_url   TEXT,
        backdrop_url TEXT,
        plot         TEXT,
        genre        TEXT,
        release_date TEXT,
        rating       REAL,
        is_favourite INTEGER DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX idx_series_category ON series(category_id)');

    await db.execute('''
      CREATE TABLE episodes (
        id                  INTEGER PRIMARY KEY,
        series_id           INTEGER NOT NULL,
        season_number       INTEGER NOT NULL,
        episode_number      INTEGER NOT NULL,
        title               TEXT NOT NULL,
        stream_url          TEXT NOT NULL,
        thumbnail_url       TEXT,
        plot                TEXT,
        duration_secs       INTEGER,
        container_extension TEXT,
        FOREIGN KEY (series_id) REFERENCES series(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX idx_episodes_series ON episodes(series_id)');

    await db.execute('''
      CREATE TABLE watch_history (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        content_id    INTEGER NOT NULL,
        content_type  TEXT NOT NULL,
        content_name  TEXT NOT NULL,
        position_secs INTEGER NOT NULL DEFAULT 0,
        duration_secs INTEGER NOT NULL DEFAULT 0,
        episode_id    INTEGER,
        thumbnail_url TEXT,
        updated_at    TEXT NOT NULL,
        -- UNIQUE keeps only the latest watch position per piece of content.
        -- episode_id IS NULL rows for movies deduplicate correctly because
        -- SQLite treats two NULLs as distinct in a UNIQUE index — but we use
        -- ConflictAlgorithm.replace on insert, so the old row is replaced.
        UNIQUE(content_id, content_type, episode_id)
      )
    ''');
    await db.execute('CREATE INDEX idx_history_updated ON watch_history(updated_at DESC)');
  }
}
