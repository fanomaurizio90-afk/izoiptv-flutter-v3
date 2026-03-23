import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../domain/repositories/channel_repository.dart';
import '../domain/repositories/series_repository.dart';
import '../domain/repositories/vod_repository.dart';

// ─── State ────────────────────────────────────────────────────────────────────

sealed class SyncState { const SyncState(); }

/// Nothing is happening.
class SyncIdle extends SyncState { const SyncIdle(); }

/// Downloading the catalogue list from the server.
class SyncDownloading extends SyncState {
  const SyncDownloading({this.isFirstRun = false});
  final bool isFirstRun;
}

/// Fetching artwork + info for individual items.
class SyncEnriching extends SyncState {
  const SyncEnriching(this.done, this.total, this.label, {this.isFirstRun = false});
  final int    done;
  final int    total;
  final String label;        // 'Movies' | 'Series'
  final bool   isFirstRun;
  double get progress => total > 0 ? done / total : 0.0;
}

/// Just finished — shown briefly before returning to Idle.
class SyncDone extends SyncState {
  const SyncDone({this.isFirstRun = false});
  final bool isFirstRun;
}

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

  /// Full sync (awaitable) then enrichment — used by Refresh Library button.
  /// Never treated as first-run (user is already in the app).
  Future<void> syncAndEnrich() async {
    if (_running) return;
    _running = true;
    try {
      state = const SyncDownloading(isFirstRun: false);
      await _vod.syncVod();
      await _series.syncSeries();
      await _channels.syncChannels();
      await _markSynced();
    } catch (_) {
      state = const SyncIdle();
      _running = false;
      return;
    }
    _doEnrich(firstRun: false);
  }

  /// Called on home screen open — determines whether to block (first run)
  /// or enrich silently in background (24hr refresh).
  Future<void> syncIfNeeded() async {
    if (_running) return;
    try {
      final raw = await _storage.read(key: _kLastSyncKey);
      if (raw == null) {
        // First launch — block with full-screen progress.
        _runFull(firstRun: true);
        return;
      }
      final lastSync = DateTime.fromMillisecondsSinceEpoch(int.parse(raw));
      if (DateTime.now().difference(lastSync) > _kSyncInterval) {
        // 24-hour refresh — silent background, no UI blocking.
        _runFull(firstRun: false);
      } else {
        // Library is fresh — quietly fill in any gaps.
        _doEnrich(firstRun: false);
      }
    } catch (_) {}
  }

  void _runFull({required bool firstRun}) {
    if (_running) return;
    _running = true;
    Future(() async {
      try {
        state = SyncDownloading(isFirstRun: firstRun);
        await _vod.syncVod();
        await _series.syncSeries();
        await _channels.syncChannels();
        await _markSynced();
      } catch (_) {
        if (mounted) state = const SyncIdle();
        _running = false;
        return;
      }
      await _doEnrich(firstRun: firstRun);
    });
  }

  Future<void> _doEnrich({required bool firstRun}) async {
    try {
      await _vod.enrichAll(onProgress: (done, total) {
        if (!mounted) return;
        if (total > 0) {
          state = SyncEnriching(done, total, 'Movies', isFirstRun: firstRun);
        }
      });

      await _series.enrichAll(onProgress: (done, total) {
        if (!mounted) return;
        if (total > 0) {
          state = SyncEnriching(done, total, 'Series', isFirstRun: firstRun);
        }
      });

      if (mounted) {
        state = SyncDone(isFirstRun: firstRun);
        await Future.delayed(const Duration(seconds: 3));
        if (mounted) state = const SyncIdle();
      }
    } catch (_) {
      if (mounted) state = const SyncIdle();
    }
    _running = false;
  }

  Future<void> _markSynced() => _storage.write(
    key:   _kLastSyncKey,
    value: DateTime.now().millisecondsSinceEpoch.toString(),
  );
}
