import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/channel.dart';
import '../../../domain/entities/vod.dart';
import '../../../domain/entities/series.dart';
import '../../providers/channel_provider.dart';
import '../../providers/providers.dart';
import '../../widgets/common/focusable_widget.dart';
import '../../widgets/common/loading_widget.dart';

final _favChannelsProvider = FutureProvider<List<Channel>>((ref) =>
    ref.watch(favouritesRepositoryProvider).getFavouriteChannels());
final _favVodProvider      = FutureProvider<List<VodItem>>((ref) =>
    ref.watch(favouritesRepositoryProvider).getFavouriteVod());
final _favSeriesProvider   = FutureProvider<List<SeriesItem>>((ref) =>
    ref.watch(favouritesRepositoryProvider).getFavouriteSeries());

class FavouritesScreen extends ConsumerStatefulWidget {
  const FavouritesScreen({super.key});

  @override
  ConsumerState<FavouritesScreen> createState() => _FavouritesScreenState();
}

class _FavouritesScreenState extends ConsumerState<FavouritesScreen> {
  int _tab = 0; // 0=Channels 1=Movies 2=Series

  final _tabNode0  = FocusNode();
  final _tabNode1  = FocusNode();
  final _tabNode2  = FocusNode();

  @override
  void dispose() {
    _tabNode0.dispose();
    _tabNode1.dispose();
    _tabNode2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.tvH, AppSpacing.xl, AppSpacing.tvH, AppSpacing.sm,
              ),
              child: const Text(
                'Favourites',
                style: TextStyle(
                  color:         AppColors.textPrimary,
                  fontSize:      15,
                  fontWeight:    FontWeight.w500,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            // ── Tab bar ─────────────────────────────────────────────────
            SizedBox(
              height: 46,
              child: Row(
                children: [
                  const SizedBox(width: AppSpacing.tvH),
                  _Tab(
                    label:     'Channels',
                    selected:  _tab == 0,
                    focusNode: _tabNode0,
                    autofocus: true,
                    onTap: () => setState(() => _tab = 0),
                    onLeft:  () {},
                    onRight: () => _tabNode1.requestFocus(),
                  ),
                  _Tab(
                    label:     'Movies',
                    selected:  _tab == 1,
                    focusNode: _tabNode1,
                    onTap: () => setState(() => _tab = 1),
                    onLeft:  () => _tabNode0.requestFocus(),
                    onRight: () => _tabNode2.requestFocus(),
                  ),
                  _Tab(
                    label:     'Series',
                    selected:  _tab == 2,
                    focusNode: _tabNode2,
                    onTap: () => setState(() => _tab = 2),
                    onLeft:  () => _tabNode1.requestFocus(),
                    onRight: null,
                  ),
                ],
              ),
            ),
            Container(height: 0.5, color: AppColors.borderSubtle),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_tab) {
      case 0:
        return ref.watch(_favChannelsProvider).when(
          data:    (items) => _ChannelList(channels: items),
          loading: () => const LoadingWidget(),
          error:   (e, _) => Center(child: Text(e.toString(), style: const TextStyle(color: AppColors.error, fontSize: 12))),
        );
      case 1:
        return ref.watch(_favVodProvider).when(
          data:    (items) => _VodList(
            items: items,
            onTap: (i) => context.push('/movies/${items[i].id}'),
          ),
          loading: () => const LoadingWidget(),
          error:   (e, _) => Center(child: Text(e.toString(), style: const TextStyle(color: AppColors.error, fontSize: 12))),
        );
      case 2:
        return ref.watch(_favSeriesProvider).when(
          data:    (items) => _SeriesList(
            items: items,
            onTap: (i) => context.push('/series/${items[i].id}'),
          ),
          loading: () => const LoadingWidget(),
          error:   (e, _) => Center(child: Text(e.toString(), style: const TextStyle(color: AppColors.error, fontSize: 12))),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// ── Tab ────────────────────────────────────────────────────────────────────────

class _Tab extends StatefulWidget {
  const _Tab({
    required this.label,
    required this.selected,
    required this.focusNode,
    required this.onTap,
    required this.onLeft,
    required this.onRight,
    this.autofocus = false,
  });
  final String        label;
  final bool          selected;
  final FocusNode     focusNode;
  final VoidCallback  onTap;
  final VoidCallback  onLeft;
  final VoidCallback? onRight;
  final bool          autofocus;

  @override
  State<_Tab> createState() => _TabState();
}

class _TabState extends State<_Tab> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(_Tab old) {
    super.didUpdateWidget(old);
    if (old.focusNode != widget.focusNode) {
      old.focusNode.removeListener(_onFocus);
      widget.focusNode.addListener(_onFocus);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() {
    if (mounted) setState(() => _focused = widget.focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          widget.onLeft();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowRight && widget.onRight != null) {
          widget.onRight!();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: FocusableWidget(
        focusNode:       widget.focusNode,
        autofocus:       widget.autofocus,
        onTap:           widget.onTap,
        showFocusBorder: false,
        child: Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize:      MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.label,
                      style: TextStyle(
                        color: widget.selected
                            ? AppColors.textPrimary
                            : _focused
                                ? AppColors.textSecondary
                                : AppColors.textMuted,
                        fontSize:   12,
                        fontWeight: widget.selected ? FontWeight.w500 : FontWeight.w300,
                        letterSpacing: 0.1,
                      ),
                    ),
                    if (widget.selected) ...[
                      const SizedBox(width: 5),
                      Container(
                        width: 4, height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.accentPrimary.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared list key handler mixin ────────────────────────────────────────────

mixin _FavListMixin<T extends StatefulWidget> on State<T> {
  Map<int, FocusNode> get nodes;
  ScrollController    get scrollCtrl;
  int                 get itemCount;

  FocusNode nodeFor(int i) => nodes.putIfAbsent(i, () => FocusNode());

  int get focusedIndex {
    for (final entry in nodes.entries) {
      if (entry.value.hasFocus) return entry.key;
    }
    return -1;
  }

  void moveTo(int idx) {
    if (idx < 0 || idx >= itemCount) return;
    nodeFor(idx).requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureVisible(idx));
  }

  void _ensureVisible(int idx) {
    if (!scrollCtrl.hasClients) return;
    const h      = 72.0;
    final top    = idx * h;
    final bottom = top + h;
    final vp     = scrollCtrl.position.viewportDimension;
    final off    = scrollCtrl.offset;
    double? target;
    if (top < off) target = top;
    else if (bottom > off + vp) target = bottom - vp;
    if (target != null) {
      scrollCtrl.animateTo(
        target.clamp(0.0, scrollCtrl.position.maxScrollExtent),
        duration: const Duration(milliseconds: 150),
        curve:    Curves.easeOut,
      );
    }
  }

  KeyEventResult handleKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final idx = focusedIndex;
    if (idx < 0) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown && idx + 1 < itemCount) {
      moveTo(idx + 1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp && idx > 0) {
      moveTo(idx - 1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void disposeNodes() {
    for (final n in nodes.values) n.dispose();
    scrollCtrl.dispose();
  }
}

// ── Channel List ──────────────────────────────────────────────────────────────

class _ChannelList extends ConsumerStatefulWidget {
  const _ChannelList({required this.channels});
  final List<Channel> channels;

  @override
  ConsumerState<_ChannelList> createState() => _ChannelListState();
}

class _ChannelListState extends ConsumerState<_ChannelList>
    with _FavListMixin {
  @override
  final Map<int, FocusNode> nodes      = {};
  @override
  final ScrollController    scrollCtrl = ScrollController();
  @override
  int get itemCount => widget.channels.length;

  @override
  void didUpdateWidget(_ChannelList old) {
    super.didUpdateWidget(old);
    if (widget.channels != old.channels) {
      for (final n in nodes.values) n.dispose();
      nodes.clear();
    }
  }

  @override
  void dispose() {
    disposeNodes();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.channels.isEmpty) {
      return const Center(
        child: Text('No favourite channels',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
      );
    }
    return Focus(
      onKeyEvent:    handleKey,
      skipTraversal: true,
      child: ListView.builder(
        controller: scrollCtrl,
        itemCount:  widget.channels.length,
        itemExtent: 72,
        itemBuilder: (_, i) {
          final ch = widget.channels[i];
          return FocusableWidget(
            focusNode: nodeFor(i),
            autofocus: i == 0,
            onTap: () {
              ref.read(selectedChannelProvider.notifier).state     = ch;
              ref.read(currentChannelListProvider.notifier).state  = widget.channels;
              ref.read(currentChannelIndexProvider.notifier).state = i;
              context.push('/live/player');
            },
            child: Container(
              height:  72,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.tvH),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.borderSubtle, width: 0.5)),
              ),
              child: Row(
                children: [
                  // ── Channel logo ──
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color:        AppColors.card,
                        borderRadius: BorderRadius.circular(8),
                        border:       Border.all(color: AppColors.glassBorder, width: 0.5),
                      ),
                      child: ch.logoUrl != null
                          ? CachedNetworkImage(
                              imageUrl:    ch.logoUrl!,
                              fit:         BoxFit.contain,
                              memCacheWidth: 96,
                              errorWidget: (_, __, ___) => _LetterAvatar(ch.name),
                            )
                          : _LetterAvatar(ch.name),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      ch.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color:      AppColors.textPrimary,
                        fontSize:   13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  const Icon(Icons.play_arrow_rounded, color: AppColors.textMuted, size: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── VOD (Movies) List ────────────────────────────────────────────────────────

class _VodList extends StatefulWidget {
  const _VodList({required this.items, required this.onTap});
  final List<VodItem>      items;
  final void Function(int) onTap;

  @override
  State<_VodList> createState() => _VodListState();
}

class _VodListState extends State<_VodList> with _FavListMixin {
  @override
  final Map<int, FocusNode> nodes      = {};
  @override
  final ScrollController    scrollCtrl = ScrollController();
  @override
  int get itemCount => widget.items.length;

  @override
  void didUpdateWidget(_VodList old) {
    super.didUpdateWidget(old);
    if (widget.items != old.items) {
      for (final n in nodes.values) n.dispose();
      nodes.clear();
    }
  }

  @override
  void dispose() {
    disposeNodes();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const Center(
        child: Text('No favourites',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
      );
    }
    return Focus(
      onKeyEvent:    handleKey,
      skipTraversal: true,
      child: ListView.builder(
        controller: scrollCtrl,
        itemCount:  widget.items.length,
        itemExtent: 72,
        itemBuilder: (_, i) {
          final vod = widget.items[i];
          return FocusableWidget(
            focusNode: nodeFor(i),
            autofocus: i == 0,
            onTap:     () => widget.onTap(i),
            child: Container(
              height:  72,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.tvH),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.borderSubtle, width: 0.5)),
              ),
              child: Row(
                children: [
                  // ── Poster ──
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 40, height: 56,
                      child: vod.posterUrl != null
                          ? CachedNetworkImage(
                              imageUrl:    vod.posterUrl!,
                              fit:         BoxFit.cover,
                              memCacheWidth: 80,
                              placeholder: (_, __) => Container(color: AppColors.card),
                              errorWidget: (_, __, ___) => Container(
                                color: AppColors.card,
                                alignment: Alignment.center,
                                child: const Icon(Icons.movie_outlined, color: AppColors.textMuted, size: 16),
                              ),
                            )
                          : Container(
                              color: AppColors.card,
                              alignment: Alignment.center,
                              child: const Icon(Icons.movie_outlined, color: AppColors.textMuted, size: 16),
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment:  MainAxisAlignment.center,
                      children: [
                        Text(
                          vod.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color:      AppColors.textPrimary,
                            fontSize:   13,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        if (vod.genre != null || vod.rating != null) ...[
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              if (vod.rating != null && vod.rating! > 0) ...[
                                const Icon(Icons.star_rounded, color: Color(0xFFF5C518), size: 12),
                                const SizedBox(width: 3),
                                Text(
                                  vod.rating!.toStringAsFixed(1),
                                  style: const TextStyle(
                                    color:    AppColors.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                                if (vod.genre != null) const SizedBox(width: 8),
                              ],
                              if (vod.genre != null)
                                Expanded(
                                  child: Text(
                                    vod.genre!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color:    AppColors.textMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 14),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Series List ──────────────────────────────────────────────────────────────

class _SeriesList extends StatefulWidget {
  const _SeriesList({required this.items, required this.onTap});
  final List<SeriesItem>    items;
  final void Function(int)  onTap;

  @override
  State<_SeriesList> createState() => _SeriesListState();
}

class _SeriesListState extends State<_SeriesList> with _FavListMixin {
  @override
  final Map<int, FocusNode> nodes      = {};
  @override
  final ScrollController    scrollCtrl = ScrollController();
  @override
  int get itemCount => widget.items.length;

  @override
  void didUpdateWidget(_SeriesList old) {
    super.didUpdateWidget(old);
    if (widget.items != old.items) {
      for (final n in nodes.values) n.dispose();
      nodes.clear();
    }
  }

  @override
  void dispose() {
    disposeNodes();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const Center(
        child: Text('No favourites',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
      );
    }
    return Focus(
      onKeyEvent:    handleKey,
      skipTraversal: true,
      child: ListView.builder(
        controller: scrollCtrl,
        itemCount:  widget.items.length,
        itemExtent: 72,
        itemBuilder: (_, i) {
          final series = widget.items[i];
          return FocusableWidget(
            focusNode: nodeFor(i),
            autofocus: i == 0,
            onTap:     () => widget.onTap(i),
            child: Container(
              height:  72,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.tvH),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.borderSubtle, width: 0.5)),
              ),
              child: Row(
                children: [
                  // ── Poster ──
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 40, height: 56,
                      child: series.posterUrl != null
                          ? CachedNetworkImage(
                              imageUrl:    series.posterUrl!,
                              fit:         BoxFit.cover,
                              memCacheWidth: 80,
                              placeholder: (_, __) => Container(color: AppColors.card),
                              errorWidget: (_, __, ___) => Container(
                                color: AppColors.card,
                                alignment: Alignment.center,
                                child: const Icon(Icons.tv_outlined, color: AppColors.textMuted, size: 16),
                              ),
                            )
                          : Container(
                              color: AppColors.card,
                              alignment: Alignment.center,
                              child: const Icon(Icons.tv_outlined, color: AppColors.textMuted, size: 16),
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment:  MainAxisAlignment.center,
                      children: [
                        Text(
                          series.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color:      AppColors.textPrimary,
                            fontSize:   13,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        if (series.genre != null || series.rating != null) ...[
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              if (series.rating != null && series.rating! > 0) ...[
                                const Icon(Icons.star_rounded, color: Color(0xFFF5C518), size: 12),
                                const SizedBox(width: 3),
                                Text(
                                  series.rating!.toStringAsFixed(1),
                                  style: const TextStyle(
                                    color:    AppColors.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                                if (series.genre != null) const SizedBox(width: 8),
                              ],
                              if (series.genre != null)
                                Expanded(
                                  child: Text(
                                    series.genre!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color:    AppColors.textMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 14),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Letter Avatar ────────────────────────────────────────────────────────────

class _LetterAvatar extends StatelessWidget {
  const _LetterAvatar(this.name);
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      color:     AppColors.card,
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
          color:      AppColors.textMuted,
          fontSize:   18,
          fontWeight: FontWeight.w300,
        ),
      ),
    );
  }
}
