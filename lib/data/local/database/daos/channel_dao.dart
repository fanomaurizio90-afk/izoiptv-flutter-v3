import 'package:sqflite/sqflite.dart';
import '../../../../domain/entities/channel.dart';
import '../app_database.dart';

class ChannelDao {
  ChannelDao._();
  static final ChannelDao instance = ChannelDao._();

  Future<Database> get _db async => AppDatabase.instance.database;

  // Categories
  Future<List<ChannelCategory>> getCategories() async {
    final db   = await _db;
    final rows = await db.query('channel_categories', orderBy: 'name ASC');
    return rows.map(_rowToCategory).toList();
  }

  Future<void> insertCategories(List<ChannelCategory> cats) async {
    final db = await _db;
    final batch = db.batch();
    for (final c in cats) {
      batch.insert(
        'channel_categories',
        {'id': c.id, 'name': c.name},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  // Channels
  Future<List<Channel>> getByCategory(int categoryId) async {
    final db   = await _db;
    final rows = await db.query(
      'channels',
      where: 'category_id = ?',
      whereArgs: [categoryId],
      orderBy: 'sort_order ASC, name ASC',
    );
    return rows.map(_rowToChannel).toList();
  }

  Future<List<Channel>> search(String query) async {
    final db = await _db;
    final escaped = query
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    final rows = await db.rawQuery(
      "SELECT * FROM channels WHERE name LIKE ? ESCAPE '\\' LIMIT 200",
      ['%$escaped%'],
    );
    return rows.map(_rowToChannel).toList();
  }

  Future<List<Channel>> getFavourites() async {
    final db   = await _db;
    final rows = await db.query('channels', where: 'is_favourite = 1', orderBy: 'name ASC');
    return rows.map(_rowToChannel).toList();
  }

  Future<void> insertChannels(List<Channel> channels) async {
    final db    = await _db;
    final batch = db.batch();
    for (final ch in channels) {
      batch.insert(
        'channels',
        {
          'id':           ch.id,
          'name':         ch.name,
          'stream_url':   ch.streamUrl,
          'category_id':  ch.categoryId,
          'logo_url':     ch.logoUrl,
          'is_favourite': ch.isFavourite ? 1 : 0,
          'sort_order':   ch.sortOrder,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> setFavourite(int id, bool isFav) async {
    final db = await _db;
    await db.update(
      'channels',
      {'is_favourite': isFav ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> count() async {
    final db  = await _db;
    final res = await db.rawQuery('SELECT COUNT(*) FROM channels');
    return Sqflite.firstIntValue(res) ?? 0;
  }

  ChannelCategory _rowToCategory(Map<String, dynamic> r) =>
      ChannelCategory(id: r['id'] as int, name: r['name'] as String);

  Channel _rowToChannel(Map<String, dynamic> r) {
    final logo = r['logo_url'] as String?;
    return Channel(
      id:          r['id'] as int,
      name:        r['name'] as String,
      streamUrl:   r['stream_url'] as String,
      categoryId:  r['category_id'] as int,
      logoUrl:     (logo == null || logo.isEmpty) ? null : logo,
      isFavourite: (r['is_favourite'] as int) == 1,
      sortOrder:   r['sort_order'] as int? ?? 0,
    );
  }
}
