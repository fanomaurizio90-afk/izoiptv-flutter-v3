import 'package:dio/dio.dart';
import '../../../domain/entities/channel.dart';
import '../../../domain/entities/vod.dart';
import '../../../domain/entities/series.dart';

class XtreamApi {
  String? _serverUrl;
  String? _username;
  String? _password;
  late final Dio _dio;

  XtreamApi() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 120),
      headers: {'User-Agent': 'Mozilla/5.0'},
    ));
  }

  void configure({
    required String serverUrl,
    required String username,
    required String password,
  }) {
    _serverUrl = serverUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (!_serverUrl!.startsWith('http://') && !_serverUrl!.startsWith('https://')) {
      _serverUrl = 'http://$_serverUrl';
    }
    _username = username.trim();
    _password = password.trim();

    // Print test URLs for verification
    // ignore: avoid_print
    print('IZO XtreamApi configured:');
    // ignore: avoid_print
    print('  Auth URL: $_base');
    // ignore: avoid_print
    print('  Live stream example: ${getLiveStreamUrl(12345)}');
    // ignore: avoid_print
    print('  VOD stream example: ${getVodStreamUrl(12345, "mp4")}');
    // ignore: avoid_print
    print('  Episode stream example: ${getEpisodeStreamUrl(12345, "mkv")}');
  }

  bool get isConfigured =>
      _serverUrl != null && _username != null && _password != null;

  String get _base =>
      '$_serverUrl/player_api.php?username=$_username&password=$_password';

  // ─── Authentication ──────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> authenticate() async {
    // ignore: avoid_print
    print('IZO AUTH URL: $_base');
    final response = await _dio.get<Map<String, dynamic>>(_base);
    return response.data!;
  }

  // ─── Live TV ─────────────────────────────────────────────────────────────────

  Future<List<ChannelCategory>> getLiveCategories() async {
    final response = await _dio.get<List<dynamic>>('$_base&action=get_live_categories');
    return (response.data ?? []).map((e) {
      final m = e as Map<String, dynamic>;
      return ChannelCategory(
        id:   int.parse(m['category_id'].toString()),
        name: m['category_name'] as String,
      );
    }).toList();
  }

  Future<List<Channel>> getLiveStreams() async {
    final response = await _dio.get<List<dynamic>>('$_base&action=get_live_streams');
    return (response.data ?? []).map((e) {
      final m   = e as Map<String, dynamic>;
      final id  = int.parse(m['stream_id'].toString());
      final ext = m['container_extension'] as String? ?? 'ts';
      return Channel(
        id:         id,
        name:       m['name'] as String? ?? '',
        streamUrl:  '$_serverUrl/live/$_username/$_password/$id.$ext',
        categoryId: int.tryParse(m['category_id']?.toString() ?? '0') ?? 0,
        logoUrl:    _nullIfEmpty(m['stream_icon'] as String?),
        sortOrder:  int.tryParse(m['num']?.toString() ?? '0') ?? 0,
      );
    }).toList();
  }

  // ─── VOD ─────────────────────────────────────────────────────────────────────

  Future<List<VodCategory>> getVodCategories() async {
    final response = await _dio.get<List<dynamic>>('$_base&action=get_vod_categories');
    return (response.data ?? []).map((e) {
      final m = e as Map<String, dynamic>;
      return VodCategory(
        id:   int.parse(m['category_id'].toString()),
        name: m['category_name'] as String,
      );
    }).toList();
  }

  Future<List<VodItem>> getVodStreams() async {
    final response = await _dio.get<List<dynamic>>('$_base&action=get_vod_streams');
    return (response.data ?? []).map((e) {
      final m    = e as Map<String, dynamic>;
      final id   = int.parse(m['stream_id'].toString());
      final ext  = m['container_extension'] as String? ?? 'mp4';
      final info = _infoMap(m['info']);
      return VodItem(
        id:                 id,
        name:               m['name'] as String? ?? '',
        streamUrl:          '$_serverUrl/movie/$_username/$_password/$id.$ext',
        categoryId:         int.tryParse(m['category_id']?.toString() ?? '0') ?? 0,
        posterUrl:          _nullIfEmpty(m['stream_icon'] as String?),
        backdropUrl:        _firstString(info['backdrop_path']),
        plot:               _nullIfEmpty(info['plot'] as String?),
        genre:              _nullIfEmpty(info['genre'] as String?),
        releaseDate:        _nullIfEmpty(info['releasedate'] as String?),
        rating:             double.tryParse(info['rating']?.toString() ?? ''),
        durationSecs:       _parseDurationSecs(info['duration'] as String?),
        containerExtension: ext,
      );
    }).toList();
  }

  /// Fetch full metadata for a single VOD item.
  /// Many providers don't include info in get_vod_streams — this fills the gap.
  Future<VodItem?> getVodInfo(int vodId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_base&action=get_vod_info&vod_id=$vodId',
        options: Options(receiveTimeout: const Duration(seconds: 15)),
      );
      final data      = response.data ?? {};
      final info      = _infoMap(data['info']);
      final movieData = _infoMap(data['movie_data']);
      if (info.isEmpty) return null;

      final id  = int.tryParse(movieData['stream_id']?.toString() ?? vodId.toString()) ?? vodId;
      final ext = movieData['container_extension'] as String? ?? 'mp4';
      return VodItem(
        id:                 id,
        name:               _nullIfEmpty(info['name'] as String?) ?? '',
        streamUrl:          '$_serverUrl/movie/$_username/$_password/$id.$ext',
        categoryId:         int.tryParse(movieData['category_id']?.toString() ?? '0') ?? 0,
        posterUrl:          _nullIfEmpty(info['movie_image'] as String?)
                            ?? _nullIfEmpty(info['cover_big'] as String?),
        backdropUrl:        _firstString(info['backdrop_path']),
        plot:               _nullIfEmpty(info['plot'] as String?),
        genre:              _nullIfEmpty(info['genre'] as String?),
        releaseDate:        _nullIfEmpty(info['releasedate'] as String?),
        rating:             double.tryParse(info['rating']?.toString() ?? ''),
        durationSecs:       _parseDurationSecs(info['duration'] as String?),
        containerExtension: ext,
      );
    } catch (_) {
      return null;
    }
  }

  // ─── Series ───────────────────────────────────────────────────────────────────

  Future<List<SeriesCategory>> getSeriesCategories() async {
    final response = await _dio.get<List<dynamic>>('$_base&action=get_series_categories');
    return (response.data ?? []).map((e) {
      final m = e as Map<String, dynamic>;
      return SeriesCategory(
        id:   int.parse(m['category_id'].toString()),
        name: m['category_name'] as String,
      );
    }).toList();
  }

  Future<List<SeriesItem>> getSeries() async {
    final response = await _dio.get<List<dynamic>>('$_base&action=get_series');
    return (response.data ?? []).map((e) {
      final m    = e as Map<String, dynamic>;
      final info = _infoMap(m['info']);
      return SeriesItem(
        id:          int.parse(m['series_id'].toString()),
        name:        m['name'] as String? ?? '',
        categoryId:  int.tryParse(m['category_id']?.toString() ?? '0') ?? 0,
        posterUrl:   _nullIfEmpty(m['cover']?.toString()),
        backdropUrl: _firstString(info['backdrop_path']),
        plot:        _nullIfEmpty(info['plot']?.toString()),
        genre:       _nullIfEmpty(info['genre']?.toString()),
        releaseDate: _nullIfEmpty(info['releaseDate']?.toString()),
        rating:      double.tryParse(info['rating']?.toString() ?? ''),
      );
    }).toList();
  }

  /// Returns (series metadata, episodes).
  /// The info object on get_series_info contains richer cover/plot/genre data
  /// than the bulk get_series response — use it to enrich the DB record.
  Future<(SeriesItem?, List<Episode>)> getSeriesInfo(int seriesId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '$_base&action=get_series_info&series_id=$seriesId',
    );
    final data = response.data ?? {};

    // Extract series-level metadata from 'info'
    // Wrapped in try/catch — a bad field type must never break episode loading.
    SeriesItem? meta;
    try {
      final seriesInfo = _infoMap(data['info']);
      if (seriesInfo.isNotEmpty) {
        meta = SeriesItem(
          id:          seriesId,
          name:        seriesInfo['name']?.toString() ?? '',
          categoryId:  int.tryParse(seriesInfo['category_id']?.toString() ?? '0') ?? 0,
          posterUrl:   _nullIfEmpty(seriesInfo['cover']?.toString()),
          backdropUrl: _firstString(seriesInfo['backdrop_path']),
          plot:        _nullIfEmpty(seriesInfo['plot']?.toString()),
          genre:       _nullIfEmpty(seriesInfo['genre']?.toString()),
          releaseDate: _nullIfEmpty(seriesInfo['releaseDate']?.toString()),
          rating:      double.tryParse(seriesInfo['rating']?.toString() ?? ''),
        );
      }
    } catch (_) {
      meta = null;
    }

    // Extract episodes
    final rawEpisodes = data['episodes'];
    final episodes = rawEpisodes is Map<String, dynamic> ? rawEpisodes : null;
    if (episodes == null) return (meta, <Episode>[]);

    final result = <Episode>[];
    for (final seasonKey in episodes.keys) {
      final seasonNum = int.tryParse(seasonKey) ?? 0;
      final epList    = episodes[seasonKey] as List;
      for (final ep in epList) {
        final e      = ep as Map<String, dynamic>;
        final id     = int.parse(e['id'].toString());
        final ext    = e['container_extension'] as String? ?? 'mp4';
        final epInfo = _infoMap(e['info']);
        result.add(Episode(
          id:                 id,
          seriesId:           seriesId,
          seasonNumber:       seasonNum,
          episodeNumber:      int.tryParse(e['episode_num']?.toString() ?? '0') ?? 0,
          title:              e['title'] as String? ?? 'Episode $id',
          streamUrl:          '$_serverUrl/series/$_username/$_password/$id.$ext',
          thumbnailUrl:       _nullIfEmpty(epInfo['movie_image'] as String?),
          plot:               _nullIfEmpty(epInfo['plot'] as String?),
          durationSecs:       _parseDurationSecs(epInfo['duration'] as String?),
          containerExtension: ext,
        ));
      }
    }
    return (meta, result);
  }

  // ─── Stream URL builders ──────────────────────────────────────────────────────

  String getLiveStreamUrl(int streamId) =>
      '$_serverUrl/live/$_username/$_password/$streamId.ts';

  String getVodStreamUrl(int streamId, String extension) =>
      '$_serverUrl/movie/$_username/$_password/$streamId.$extension';

  String getEpisodeStreamUrl(int episodeId, String extension) =>
      '$_serverUrl/series/$_username/$_password/$episodeId.$extension';

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  /// Returns null for null or empty strings — prevents CachedNetworkImage from
  /// trying to load an empty URL and silently failing.
  String? _nullIfEmpty(String? s) => (s == null || s.isEmpty) ? null : s;

  /// Safely extract the 'info' sub-object. Some providers return false/[]/""
  /// instead of a Map — treat anything that isn't a Map as empty.
  Map<String, dynamic> _infoMap(dynamic raw) =>
      raw is Map<String, dynamic> ? raw : const {};

  /// backdrop_path is a JSON array in the Xtream API, not a string.
  /// Returns the first non-empty URL from either a List or a plain String.
  String? _firstString(dynamic raw) {
    if (raw is String) return raw.isEmpty ? null : raw;
    if (raw is List) {
      for (final v in raw) {
        if (v is String && v.isNotEmpty) return v;
      }
    }
    return null;
  }

  int? _parseDurationSecs(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    // Format: "HH:MM:SS" or "MM:SS"
    final parts = raw.split(':');
    if (parts.length == 3) {
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      final s = int.tryParse(parts[2]) ?? 0;
      return h * 3600 + m * 60 + s;
    }
    if (parts.length == 2) {
      final m = int.tryParse(parts[0]) ?? 0;
      final s = int.tryParse(parts[1]) ?? 0;
      return m * 60 + s;
    }
    return int.tryParse(raw);
  }
}
