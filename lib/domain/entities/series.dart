class SeriesCategory {
  const SeriesCategory({required this.id, required this.name});
  final int    id;
  final String name;
}

class SeriesItem {
  const SeriesItem({
    required this.id,
    required this.name,
    required this.categoryId,
    this.posterUrl,
    this.backdropUrl,
    this.plot,
    this.genre,
    this.releaseDate,
    this.rating,
    this.isFavourite = false,
  });
  final int     id;
  final String  name;
  final int     categoryId;
  final String? posterUrl;
  final String? backdropUrl;
  final String? plot;
  final String? genre;
  final String? releaseDate;
  final double? rating;
  final bool    isFavourite;

  SeriesItem copyWith({bool? isFavourite}) => SeriesItem(
    id:          id,
    name:        name,
    categoryId:  categoryId,
    posterUrl:   posterUrl,
    backdropUrl: backdropUrl,
    plot:        plot,
    genre:       genre,
    releaseDate: releaseDate,
    rating:      rating,
    isFavourite: isFavourite ?? this.isFavourite,
  );
}

class Season {
  const Season({required this.number, required this.episodes});
  final int           number;
  final List<Episode> episodes;
}

class Episode {
  const Episode({
    required this.id,
    required this.seriesId,
    required this.seasonNumber,
    required this.episodeNumber,
    required this.title,
    required this.streamUrl,
    this.thumbnailUrl,
    this.plot,
    this.durationSecs,
    this.containerExtension,
    this.isWatched = false,
  });
  final int     id;
  final int     seriesId;
  final int     seasonNumber;
  final int     episodeNumber;
  final String  title;
  final String  streamUrl;
  final String? thumbnailUrl;
  final String? plot;
  final int?    durationSecs;
  final String? containerExtension;
  final bool    isWatched;
}
