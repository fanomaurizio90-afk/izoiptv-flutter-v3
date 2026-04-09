class VodCategory {
  const VodCategory({required this.id, required this.name});
  final int    id;
  final String name;
}

class VodItem {
  const VodItem({
    required this.id,
    required this.name,
    required this.streamUrl,
    required this.categoryId,
    this.posterUrl,
    this.backdropUrl,
    this.plot,
    this.genre,
    this.releaseDate,
    this.rating,
    this.durationSecs,
    this.containerExtension,
    this.isFavourite = false,
    this.added,
    this.cast,
    this.director,
    this.tmdbId,
    this.youtubeTrailer,
  });
  final int     id;
  final String  name;
  final String  streamUrl;
  final int     categoryId;
  final String? posterUrl;
  final String? backdropUrl;
  final String? plot;
  final String? genre;
  final String? releaseDate;
  final double? rating;
  final int?    durationSecs;
  final String? containerExtension;
  final bool    isFavourite;
  final int?    added; // Unix timestamp from API
  final String? cast;
  final String? director;
  final String? tmdbId;
  final String? youtubeTrailer;

  VodItem copyWith({bool? isFavourite}) => VodItem(
    id:                 id,
    name:               name,
    streamUrl:          streamUrl,
    categoryId:         categoryId,
    posterUrl:          posterUrl,
    backdropUrl:        backdropUrl,
    plot:               plot,
    genre:              genre,
    releaseDate:        releaseDate,
    rating:             rating,
    durationSecs:       durationSecs,
    containerExtension: containerExtension,
    isFavourite:        isFavourite ?? this.isFavourite,
    added:              added,
    cast:               cast,
    director:           director,
    tmdbId:             tmdbId,
    youtubeTrailer:     youtubeTrailer,
  );
}
