import 'package:flutter/services.dart';

/// Info about a single audio or subtitle track from ExoPlayer.
class ExoTrackInfo {
  final int groupIndex;
  final int trackIndex;
  final String? language;
  final String? label;
  final bool selected;
  final int? channels;

  ExoTrackInfo({
    required this.groupIndex,
    required this.trackIndex,
    this.language,
    this.label,
    this.selected = false,
    this.channels,
  });

  String get displayName {
    final parts = <String>[];
    if (label != null && label!.isNotEmpty) parts.add(label!);
    if (language != null && language!.isNotEmpty) parts.add(language!);
    if (channels != null && channels! > 0) parts.add('${channels}ch');
    return parts.isNotEmpty ? parts.join(' — ') : 'Track ${trackIndex + 1}';
  }
}

/// Communicates with the native Android side to query and select
/// audio / subtitle tracks on the ExoPlayer instance managed by
/// the `video_player` plugin.
class ExoTrackService {
  static const _channel = MethodChannel('com.izoiptv/exo_tracks');

  static Future<List<ExoTrackInfo>> getAudioTracks(int textureId) async {
    try {
      final result = await _channel.invokeListMethod<Map>('getAudioTracks', {
        'textureId': textureId,
      });
      if (result == null) return [];
      return result
          .map((m) => ExoTrackInfo(
                groupIndex: m['groupIndex'] as int,
                trackIndex: m['trackIndex'] as int,
                language: m['language'] as String?,
                label: m['label'] as String?,
                selected: m['selected'] as bool? ?? false,
                channels: m['channels'] as int?,
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<ExoTrackInfo>> getSubtitleTracks(int textureId) async {
    try {
      final result =
          await _channel.invokeListMethod<Map>('getSubtitleTracks', {
        'textureId': textureId,
      });
      if (result == null) return [];
      return result
          .map((m) => ExoTrackInfo(
                groupIndex: m['groupIndex'] as int,
                trackIndex: m['trackIndex'] as int,
                language: m['language'] as String?,
                label: m['label'] as String?,
                selected: m['selected'] as bool? ?? false,
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<bool> selectAudioTrack(
      int textureId, int groupIndex, int trackIndex) async {
    try {
      final result =
          await _channel.invokeMethod<bool>('selectAudioTrack', {
        'textureId': textureId,
        'groupIndex': groupIndex,
        'trackIndex': trackIndex,
      });
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> selectSubtitleTrack(
      int textureId, int groupIndex, int trackIndex) async {
    try {
      final result =
          await _channel.invokeMethod<bool>('selectSubtitleTrack', {
        'textureId': textureId,
        'groupIndex': groupIndex,
        'trackIndex': trackIndex,
      });
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> disableSubtitles(int textureId) async {
    try {
      final result =
          await _channel.invokeMethod<bool>('disableSubtitles', {
        'textureId': textureId,
      });
      return result ?? false;
    } catch (_) {
      return false;
    }
  }
}
