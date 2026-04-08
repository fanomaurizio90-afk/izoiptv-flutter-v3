class ContinueWatchingItem {
  const ContinueWatchingItem({
    required this.contentId,
    required this.contentType,
    required this.contentName,
    required this.positionSecs,
    required this.durationSecs,
    this.episodeId,
    this.posterUrl,
    this.seriesName,
    this.seasonNumber,
    this.episodeNumber,
  });

  final int     contentId;
  final String  contentType;   // 'movie' or 'episode'
  final String  contentName;
  final int     positionSecs;
  final int     durationSecs;
  final int?    episodeId;
  final String? posterUrl;
  final String? seriesName;    // for episodes: parent series name
  final int?    seasonNumber;
  final int?    episodeNumber;

  double get progress =>
      durationSecs > 0 ? (positionSecs / durationSecs).clamp(0.0, 1.0) : 0.0;

  String get episodeLabel {
    if (seasonNumber == null || episodeNumber == null) return contentName;
    final s = seasonNumber.toString().padLeft(2, '0');
    final e = episodeNumber.toString().padLeft(2, '0');
    return 'S${s}E$e';
  }
}
