class ChannelCategory {
  const ChannelCategory({required this.id, required this.name});
  final int    id;
  final String name;
}

class Channel {
  const Channel({
    required this.id,
    required this.name,
    required this.streamUrl,
    required this.categoryId,
    this.logoUrl,
    this.isFavourite = false,
    this.sortOrder   = 0,
    this.epgChannelId,
    this.tvArchive     = false,
    this.tvArchiveDuration = 0,
  });
  final int     id;
  final String  name;
  final String  streamUrl;
  final int     categoryId;
  final String? logoUrl;
  final bool    isFavourite;
  final int     sortOrder;
  final String? epgChannelId;
  final bool    tvArchive;
  final int     tvArchiveDuration;

  Channel copyWith({bool? isFavourite}) => Channel(
    id:                 id,
    name:               name,
    streamUrl:          streamUrl,
    categoryId:         categoryId,
    logoUrl:            logoUrl,
    isFavourite:        isFavourite ?? this.isFavourite,
    sortOrder:          sortOrder,
    epgChannelId:       epgChannelId,
    tvArchive:          tvArchive,
    tvArchiveDuration:  tvArchiveDuration,
  );
}
