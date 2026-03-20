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
  });
  final int    id;
  final String name;
  final String streamUrl;
  final int    categoryId;
  final String? logoUrl;
  final bool   isFavourite;
  final int    sortOrder;

  Channel copyWith({bool? isFavourite}) => Channel(
    id:          id,
    name:        name,
    streamUrl:   streamUrl,
    categoryId:  categoryId,
    logoUrl:     logoUrl,
    isFavourite: isFavourite ?? this.isFavourite,
    sortOrder:   sortOrder,
  );
}
