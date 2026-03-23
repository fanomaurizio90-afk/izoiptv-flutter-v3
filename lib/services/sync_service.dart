import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../domain/repositories/channel_repository.dart';
import '../domain/repositories/series_repository.dart';
import '../domain/repositories/vod_repository.dart';

class SyncService {
  SyncService(this._vod, this._series, this._channels, this._storage);

  final VodRepository        _vod;
  final SeriesRepository     _series;
  final ChannelRepository    _channels;
  final FlutterSecureStorage _storage;

  static const _kLastSyncKey = 'last_full_sync';
  static const _kSyncInterval = Duration(hours: 24);

  bool _enriching = false;

  /// Full sync (blocks) then enrichment in background.
  /// Call from "Refresh Library" button — shows spinner during sync phase.
  Future<void> syncAndEnrich() async {
    await _vod.syncVod();
    await _series.syncSeries();
    await _channels.syncChannels();
    await _storage.write(
      key:   _kLastSyncKey,
      value: DateTime.now().millisecondsSinceEpoch.toString(),
    );
    _runEnrichInBackground();
  }

  /// Check if 24 hours have passed since last sync.
  /// If so, sync + enrich entirely in the background.
  Future<void> syncIfNeeded() async {
    try {
      final raw = await _storage.read(key: _kLastSyncKey);
      if (raw == null) {
        // First launch after login — sync in background so the app opens fast.
        _runSyncAndEnrichInBackground();
        return;
      }
      final lastSync = DateTime.fromMillisecondsSinceEpoch(int.parse(raw));
      if (DateTime.now().difference(lastSync) > _kSyncInterval) {
        _runSyncAndEnrichInBackground();
      } else {
        // Sync is fresh — just enrich anything still missing metadata.
        _runEnrichInBackground();
      }
    } catch (_) {}
  }

  void _runSyncAndEnrichInBackground() {
    Future(() async {
      try {
        await _vod.syncVod();
        await _series.syncSeries();
        await _channels.syncChannels();
        await _storage.write(
          key:   _kLastSyncKey,
          value: DateTime.now().millisecondsSinceEpoch.toString(),
        );
        await _vod.enrichAll();
        await _series.enrichAll();
      } catch (_) {}
    });
  }

  void _runEnrichInBackground() {
    if (_enriching) return;
    _enriching = true;
    Future(() async {
      try {
        await _vod.enrichAll();
        await _series.enrichAll();
      } catch (_) {}
      _enriching = false;
    });
  }
}
