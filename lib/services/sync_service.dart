import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../domain/repositories/channel_repository.dart';
import '../domain/repositories/series_repository.dart';
import '../domain/repositories/vod_repository.dart';

// ─── State ────────────────────────────────────────────────────────────────────

sealed class SyncState { const SyncState(); }

class SyncIdle       extends SyncState { const SyncIdle(); }
class SyncDownloading extends SyncState { const SyncDownloading(); }
class SyncEnriching  extends SyncState {
  const SyncEnriching(this.done, this.total, this.label);
  final int    done;
  final int    total;
  final String label;
  double get progress => total > 0 ? done / total : 0.0;
}
class SyncDone extends SyncState { const SyncDone(); }

// ─── Notifier ─────────────────────────────────────────────────────────────────

class SyncNotifier extends StateNotifier<SyncState> {
  SyncNotifier(this._vod, this._series, this._channels, this._storage)
      : super(const SyncIdle());

  final VodRepository        _vod;
  final SeriesRepository     _series;
  final ChannelRepository    _channels;
  final FlutterSecureStorage _storage;

  static const _kLastSyncKey  = 'last_full_sync';
  static const _kSyncInterval = Duration(hours: 24);

  bool _running = false;

  /// Full sync (awaitable for the catalogue phase) then background enrichment.
  /// Used by the Refresh Library button in Settings.
  Future<void> syncAndEnrich() async {
    if (_running) return;
    _running = true;
    try {
      state = const SyncDownloading();
      await _vod.syncVod();
      await _series.syncSeries();
      await _channels.syncChannels();
      await _markSynced();
    } catch (_) {
      if (mounted) state = const SyncIdle();
      _running = false;
      return;
    }
    _doEnrich();
  }

  /// Called on home screen open — everything runs in background, never blocks.
  Future<void> syncIfNeeded() async {
    if (_running) return;
    try {
      final raw = await _storage.read(key: _kLastSyncKey);
      if (raw == null) {
        _runFullInBackground();
        return;
      }
      final lastSync = DateTime.fromMillisecondsSinceEpoch(int.parse(raw));
      if (DateTime.now().difference(lastSync) > _kSyncInterval) {
        _runFullInBackground();
      }
      // Within 24 hrs — do nothing.
    } catch (_) {}
  }

  void _runFullInBackground() {
    if (_running) return;
    _running = true;
    Future(() async {
      try {
        state = const SyncDownloading();
        await _vod.syncVod();
        await _series.syncSeries();
        await _channels.syncChannels();
        await _markSynced();
      } catch (_) {
        if (mounted) state = const SyncIdle();
        _running = false;
        return;
      }
      await _doEnrich();
    });
  }

  Future<void> _doEnrich() async {
    try {
      await _vod.enrichAll(onProgress: (done, total) {
        if (!mounted) return;
        if (total > 0) state = SyncEnriching(done, total, 'Movies');
      });
      await _series.enrichAll(onProgress: (done, total) {
        if (!mounted) return;
        if (total > 0) state = SyncEnriching(done, total, 'Series');
      });
      if (mounted) {
        state = const SyncDone();
        await Future.delayed(const Duration(seconds: 3));
        if (mounted) state = const SyncIdle();
      }
    } catch (_) {
      if (mounted) state = const SyncIdle();
    }
    _running = false;
  }

  /// Returns the time of the last completed sync, or null if never synced.
  Future<DateTime?> lastSyncedAt() async {
    final raw = await _storage.read(key: _kLastSyncKey);
    if (raw == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(int.parse(raw));
  }

  Future<void> _markSynced() => _storage.write(
    key:   _kLastSyncKey,
    value: DateTime.now().millisecondsSinceEpoch.toString(),
  );
}
