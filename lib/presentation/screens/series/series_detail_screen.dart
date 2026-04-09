import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/series.dart';
import '../../../domain/entities/vod.dart';
import '../../providers/providers.dart';
import '../../widgets/common/focusable_widget.dart';
import '../../widgets/common/skeleton_widget.dart';
import '../../widgets/common/staggered_list.dart';

// ── Providers ────────────────────────────────────────────────────────────────

final _seriesDetailProvider =
    FutureProvider.family<SeriesItem?, int>((ref, id) async {
  return ref.watch(seriesRepositoryProvider).getSeriesById(id);
});

final seasonsProvider =
    FutureProvider.autoDispose.family<List<Season>, int>((ref, seriesId) async {
  return ref.watch(seriesRepositoryProvider).getSeasons(seriesId);
});

final selectedSeasonProvider = StateProvider<int>((ref) => 1);

// ── Screen ───────────────────────────────────────────────────────────────────

class SeriesDetailScreen extends ConsumerStatefulWidget {
  const SeriesDetailScreen({super.key, required this.seriesId, this.series});
  final int         seriesId;
  final SeriesItem? series;

  @override
  ConsumerState<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends ConsumerState<SeriesDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(selectedSeasonProvider.notifier).state = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    onToggleFav(SeriesItem s) async {
      final repo = ref.read(seriesRepositoryProvider);
      await repo.toggleFavourite(s.id, !s.isFavourite);
      ref.invalidate(_seriesDetailProvider(widget.seriesId));
    }

    if (widget.series != null) {
      return PopScope(
        canPop: true,
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: _SeriesDetailBody(
            series: widget.series!,
            onToggleFavourite: () => onToggleFav(widget.series!),
          ),
        ),
      );
    }
    final seriesAsync = ref.watch(_seriesDetailProvider(widget.seriesId));
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: seriesAsync.when(
          data: (series) {
            if (series == null) {
              return Center(child: Text('Series not found',
                style: TextStyle(color: AppColors.textSecondary)));
            }
            return _SeriesDetailBody(
              series: series,
              onToggleFavourite: () => onToggleFav(series),
            );
          },
          loading: () => const SkeletonDetailBackdrop(),
          error:   (e, _) => Center(child: Text(e.toString(),
            style: TextStyle(color: AppColors.error, fontSize: 12))),
        ),
      ),
    );
  }
}

// ── Body ─────────────────────────────────────────────────────────────────────

class _SeriesDetailBody extends ConsumerStatefulWidget {
  const _SeriesDetailBody({required this.series, required this.onToggleFavourite});
  final SeriesItem series;
  final VoidCallback onToggleFavourite;

  @override
  ConsumerState<_SeriesDetailBody> createState() => _SeriesDetailBodyState();
}

class _SeriesDetailBodyState extends ConsumerState<_SeriesDetailBody>
    with SingleTickerProviderStateMixin {
  late SeriesItem _displaySeries;

  final _backNode    = FocusNode();
  final _favNode     = FocusNode();
  final _trailerNode = FocusNode();
  List<FocusNode> _seasonNodes = [];
  FocusNode? _firstEpisodeNode;

  late final AnimationController _entranceCtrl;
  late final Animation<double>   _fadeIn;
  late final Animation<Offset>   _slideUp;

  @override
  void initState() {
    super.initState();
    _displaySeries = widget.series;
    ref.read(selectedSeasonProvider.notifier).state = 1;

    _entranceCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600),
    );
    _fadeIn  = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.06), end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic));
    _entranceCtrl.forward();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _backNode.dispose();
    _favNode.dispose();
    _trailerNode.dispose();
    for (final n in _seasonNodes) n.dispose();
    super.dispose();
  }

  Future<void> _openTrailer() async {
    final url = _displaySeries.youtubeTrailer;
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url.startsWith('http') ? url : 'https://www.youtube.com/watch?v=$url');
    if (uri != null) {
      try { await launchUrl(uri, mode: LaunchMode.externalApplication); } catch (_) {}
    }
  }

  void _rebuildSeasonNodes(int count) {
    if (_seasonNodes.length != count) {
      for (final n in _seasonNodes) n.dispose();
      _seasonNodes = List.generate(count, (_) => FocusNode());
      // Auto-focus first season tab once seasons are loaded
      if (_seasonNodes.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_backNode.hasFocus) {
            _seasonNodes[0].requestFocus();
          }
        });
      }
    }
  }

  KeyEventResult _handleSeasonKey(int i, int total, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (i > 0) {
        _seasonNodes[i - 1].requestFocus();
      } else {
        _backNode.requestFocus();
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (i < total - 1) _seasonNodes[i + 1].requestFocus();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _firstEpisodeNode?.requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _refreshMetadataFromDb() async {
    final fresh =
        await ref.read(seriesRepositoryProvider).getSeriesById(widget.series.id);
    if (fresh != null && mounted) setState(() => _displaySeries = fresh);
  }

  @override
  Widget build(BuildContext context) {
    final screenH        = MediaQuery.of(context).size.height;
    final screenW        = MediaQuery.of(context).size.width;
    final topPad         = MediaQuery.of(context).padding.top;
    final selectedSeason = ref.watch(selectedSeasonProvider);
    final seasonsAsync   = ref.watch(seasonsProvider(widget.series.id));

    ref.listen(seasonsProvider(widget.series.id), (_, next) {
      if (next.hasValue && _displaySeries.posterUrl == null) {
        _refreshMetadataFromDb();
      }
    });

    return Stack(
      children: [
        // ── Backdrop ────────────────────────────────────────────────────
        Positioned(
          top: 0, left: 0, right: 0,
          height: screenH * 0.55,
          child: (_displaySeries.backdropUrl ?? _displaySeries.posterUrl) != null
              ? CachedNetworkImage(
                  imageUrl:       (_displaySeries.backdropUrl ?? _displaySeries.posterUrl)!,
                  fit:            BoxFit.cover,
                  width:          screenW,
                  memCacheWidth:  800,
                  fadeInDuration: const Duration(milliseconds: 200),
                  placeholder:    (_, __) => Container(color: AppColors.card),
                  errorWidget:    (_, __, ___) => Container(color: AppColors.card),
                )
              : Container(color: AppColors.card),
        ),

        // ── Multi-stop gradient ─────────────────────────────────────────
        Positioned(
          top: 0, left: 0, right: 0,
          height: screenH * 0.55,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin:  Alignment.topCenter,
                end:    Alignment.bottomCenter,
                stops:  [0.0, 0.25, 0.6, 1.0],
                colors: [
                  Color(0x30070709),
                  Color(0x10070709),
                  Color(0xAA070709),
                  Color(0xFF070709),
                ],
              ),
            ),
          ),
        ),

        // ── Solid below ─────────────────────────────────────────────────
        Positioned(
          top: screenH * 0.55, left: 0, right: 0, bottom: 0,
          child: Container(color: AppColors.background),
        ),

        // ── Top bar: Back + Favourite ──────────────────────────────────
        Positioned(
          top:  topPad + AppSpacing.sm,
          left: AppSpacing.tvH,
          right: AppSpacing.tvH,
          child: Row(
            children: [
              FocusableWidget(
                focusNode:    _backNode,
                autofocus:    true,
                borderRadius: AppSpacing.radiusPill,
                onTap: () => context.pop(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color:        const Color(0x55000000),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chevron_left, color: AppColors.textSecondary, size: 16),
                      SizedBox(width: 2),
                      Text('Back', style: TextStyle(
                        color:      AppColors.textSecondary,
                        fontSize:   11,
                        fontWeight: FontWeight.w400,
                      )),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              // ── Favourite button ──
              Focus(
                onKeyEvent: (_, event) {
                  if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
                  if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                    _backNode.requestFocus();
                    return KeyEventResult.handled;
                  }
                  if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                    if (_seasonNodes.isNotEmpty) _seasonNodes[0].requestFocus();
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: FocusableWidget(
                  focusNode:    _favNode,
                  borderRadius: AppSpacing.radiusPill,
                  onTap: widget.onToggleFavourite,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color:        const Color(0x55000000),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _displaySeries.isFavourite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: _displaySeries.isFavourite ? AppColors.accentPrimary : AppColors.textSecondary,
                          size: 14,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _displaySeries.isFavourite ? 'Favourited' : 'Favourite',
                          style: TextStyle(
                            color: _displaySeries.isFavourite ? AppColors.accentPrimary : AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Scrollable content ──────────────────────────────────────────
        Positioned.fill(
          child: FadeTransition(
            opacity: _fadeIn,
            child: SlideTransition(
              position: _slideUp,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: screenH * 0.35),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.tvH,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Title ─────────────────────────────────────
                          Text(
                            _displaySeries.name,
                            style: const TextStyle(
                              color:         AppColors.textPrimary,
                              fontSize:      34,
                              fontWeight:    FontWeight.w500,
                              letterSpacing: -0.5,
                              height:        1.15,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // ── Meta + rating badge ────────────────────────
                          _SeriesMeta(series: _displaySeries),

                          // ── Trailer button ──────────────────────────────
                          if (_displaySeries.youtubeTrailer != null &&
                              _displaySeries.youtubeTrailer!.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _TrailerButton(
                              focusNode: _trailerNode,
                              onTap:     _openTrailer,
                            ),
                          ],

                          if (_displaySeries.plot != null) ...[
                            const SizedBox(height: 14),
                            Text(
                              _displaySeries.plot!,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color:      AppColors.textSecondary,
                                fontSize:   13,
                                fontWeight: FontWeight.w300,
                                height:     1.65,
                              ),
                            ),
                          ],
                          if (_displaySeries.director != null || _displaySeries.cast != null) ...[
                            const SizedBox(height: 12),
                            if (_displaySeries.director != null)
                              _SeriesInfoLine(label: 'Director', value: _displaySeries.director!),
                            if (_displaySeries.director != null && _displaySeries.cast != null)
                              const SizedBox(height: 4),
                            if (_displaySeries.cast != null)
                              _SeriesInfoLine(label: 'Cast', value: _displaySeries.cast!),
                          ],
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),

                    // ── Season tabs + episodes ──────────────────────────
                    seasonsAsync.when(
                      data: (seasons) {
                        if (seasons.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(AppSpacing.xl2),
                            child: Text('No episodes available',
                              style: TextStyle(
                                color: AppColors.textMuted, fontSize: 13)),
                          );
                        }
                        _rebuildSeasonNodes(seasons.length);
                        final season = seasons.firstWhere(
                          (s) => s.number == selectedSeason,
                          orElse: () => seasons.first,
                        );
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Season pills ────────────────────────────
                            _SeasonSelector(
                              seasons:        seasons,
                              selectedNumber: selectedSeason,
                              nodes:          _seasonNodes,
                              onSelect: (num) => ref
                                  .read(selectedSeasonProvider.notifier)
                                  .state = num,
                              onKey: _handleSeasonKey,
                            ),
                            const SizedBox(height: 6),

                            // ── Divider ─────────────────────────────────
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.tvH,
                              ),
                              child: Container(
                                height: 0.5,
                                color: const Color(0x1AFFFFFF),
                              ),
                            ),
                            const SizedBox(height: 4),

                            // ── Episodes ────────────────────────────────
                            _EpisodeList(
                              key: ValueKey(
                                '${widget.series.id}_$selectedSeason'),
                              seriesId:  widget.series.id,
                              episodes:  season.episodes,
                              firstSeasonNode: _seasonNodes.isNotEmpty
                                  ? _seasonNodes[0]
                                  : null,
                              onFirstNodeReady: (node) {
                                _firstEpisodeNode = node;
                              },
                            ),
                            const SizedBox(height: AppSpacing.xl3),
                          ],
                        );
                      },
                      loading: () => const Padding(
                        padding: EdgeInsets.all(AppSpacing.xl2),
                        child: SkeletonChannelList(count: 5),
                      ),
                      error: (e, _) => Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl2),
                        child: Text(e.toString(),
                          style: TextStyle(
                            color: AppColors.error, fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Series Meta ──────────────────────────────────────────────────────────────

class _SeriesMeta extends StatelessWidget {
  const _SeriesMeta({required this.series});
  final SeriesItem series;

  @override
  Widget build(BuildContext context) {
    final chips = <String>[
      if (series.releaseDate != null) series.releaseDate!,
      if (series.genre != null)       series.genre!,
    ];

    return Row(
      children: [
        // ── IMDB-style rating badge ──
        if (series.rating != null && series.rating! > 0) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color:        const Color(0xFFF5C518),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded, color: Color(0xFF000000), size: 13),
                const SizedBox(width: 3),
                Text(
                  series.rating!.toStringAsFixed(1),
                  style: const TextStyle(
                    color:      Color(0xFF000000),
                    fontSize:   12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (chips.isNotEmpty) const SizedBox(width: 10),
        ],
        // ── Meta chips ──
        if (chips.isNotEmpty)
          Expanded(
            child: Wrap(
              spacing:    8,
              runSpacing: 6,
              children: chips.map((label) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  border:       Border.all(color: const Color(0x33FFFFFF), width: 0.5),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    color:         AppColors.textSecondary,
                    fontSize:      11,
                    fontWeight:    FontWeight.w400,
                    letterSpacing: 0.4,
                  ),
                ),
              )).toList(),
            ),
          ),
      ],
    );
  }
}

// ── Trailer Button ──────────────────────────────────────────────────────────

class _TrailerButton extends StatefulWidget {
  const _TrailerButton({required this.focusNode, required this.onTap});
  final FocusNode    focusNode;
  final VoidCallback onTap;

  @override
  State<_TrailerButton> createState() => _TrailerButtonState();
}

class _TrailerButtonState extends State<_TrailerButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return FocusableWidget(
      focusNode:    widget.focusNode,
      borderRadius: AppSpacing.radiusPill,
      onTap:        widget.onTap,
      child: Focus(
        canRequestFocus: false,
        onFocusChange: (f) { if (mounted) setState(() => _focused = f); },
        child: AnimatedContainer(
          duration: AppDurations.focus,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _focused ? const Color(0xFFFF0000) : const Color(0x14FFFFFF),
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.play_circle_outline_rounded,
                color: _focused ? Colors.white : AppColors.textSecondary,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                'Watch Trailer',
                style: TextStyle(
                  color:    _focused ? Colors.white : AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Series Info Line ────────────────────────────────────────────────────────

class _SeriesInfoLine extends StatelessWidget {
  const _SeriesInfoLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 65,
          child: Text(label, style: const TextStyle(
            color: AppColors.textMuted, fontSize: 11,
            fontWeight: FontWeight.w500, letterSpacing: 0.5,
          )),
        ),
        Expanded(
          child: Text(value, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 11,
              fontWeight: FontWeight.w300, height: 1.5,
            )),
        ),
      ],
    );
  }
}

// ── Season Selector ──────────────────────────────────────────────────────────

class _SeasonSelector extends StatefulWidget {
  const _SeasonSelector({
    required this.seasons,
    required this.selectedNumber,
    required this.nodes,
    required this.onSelect,
    required this.onKey,
  });
  final List<Season>    seasons;
  final int             selectedNumber;
  final List<FocusNode> nodes;
  final void Function(int)                            onSelect;
  final KeyEventResult Function(int, int, KeyEvent)   onKey;

  @override
  State<_SeasonSelector> createState() => _SeasonSelectorState();
}

class _SeasonSelectorState extends State<_SeasonSelector> {
  int _focusedIdx = -1;

  void _onFocusChange() {
    if (!mounted) return;
    setState(() {
      _focusedIdx = widget.nodes.indexWhere((n) => n.hasFocus);
    });
  }

  @override
  void initState() {
    super.initState();
    for (final n in widget.nodes) n.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(_SeasonSelector old) {
    super.didUpdateWidget(old);
    if (old.nodes != widget.nodes) {
      for (final n in old.nodes) n.removeListener(_onFocusChange);
      for (final n in widget.nodes) n.addListener(_onFocusChange);
    }
  }

  @override
  void dispose() {
    for (final n in widget.nodes) n.removeListener(_onFocusChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding:         const EdgeInsets.symmetric(horizontal: AppSpacing.tvH),
        itemCount:       widget.seasons.length,
        itemBuilder: (_, i) {
          final s          = widget.seasons[i];
          final isSelected = s.number == widget.selectedNumber;
          final isFocused  = _focusedIdx == i;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Focus(
              onKeyEvent: (_, e) => widget.onKey(i, widget.seasons.length, e),
              child: FocusableWidget(
                focusNode:       widget.nodes[i],
                borderRadius:    AppSpacing.radiusPill,
                showFocusBorder: false,
                onTap:           () => widget.onSelect(s.number),
                child: AnimatedContainer(
                  duration: AppDurations.fast,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: isFocused
                        ? const Color(0x12FFFFFF)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Season ${s.number}',
                            style: TextStyle(
                              color: isSelected || isFocused
                                  ? AppColors.textPrimary
                                  : AppColors.textMuted,
                              fontSize:   13,
                              fontWeight: isSelected
                                  ? FontWeight.w500
                                  : FontWeight.w400,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${s.episodes.length}',
                            style: TextStyle(
                              color: isSelected
                                  ? AppColors.textSecondary
                                  : AppColors.textMuted,
                              fontSize:   11,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      AnimatedContainer(
                        duration: AppDurations.medium,
                        curve:   Curves.easeOut,
                        height:  2,
                        width:   isSelected ? 24 : 0,
                        decoration: BoxDecoration(
                          color:        AppColors.textPrimary,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Episode List ─────────────────────────────────────────────────────────────

class _EpisodeList extends ConsumerStatefulWidget {
  const _EpisodeList({
    super.key,
    required this.seriesId,
    required this.episodes,
    required this.onFirstNodeReady,
    this.firstSeasonNode,
  });
  final int                      seriesId;
  final List<Episode>            episodes;
  final void Function(FocusNode) onFirstNodeReady;
  final FocusNode?               firstSeasonNode;

  @override
  ConsumerState<_EpisodeList> createState() => _EpisodeListState();
}

class _EpisodeListState extends ConsumerState<_EpisodeList> {
  final Map<int, FocusNode> _nodes   = {};
  List<GlobalKey>           _rowKeys = [];
  Map<int, Map<String, dynamic>> _history = {};

  FocusNode _nodeFor(int i) => _nodes.putIfAbsent(i, () => FocusNode());

  @override
  void initState() {
    super.initState();
    _rowKeys = List.generate(widget.episodes.length, (_) => GlobalKey());
    _notifyFirst();
    _loadHistory();
  }

  @override
  void dispose() {
    for (final n in _nodes.values) n.dispose();
    super.dispose();
  }

  void _notifyFirst() {
    if (widget.episodes.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onFirstNodeReady(_nodeFor(0));
      });
    }
  }

  Future<void> _loadHistory() async {
    final repo   = ref.read(historyRepositoryProvider);
    final result = <int, Map<String, dynamic>>{};
    for (final ep in widget.episodes) {
      final record =
          await repo.getPosition(ep.seriesId, 'episode', episodeId: ep.id);
      if (record != null) result[ep.id] = record;
    }
    if (mounted) setState(() => _history = result);
  }

  int get _focusedIndex {
    for (final entry in _nodes.entries) {
      if (entry.value.hasFocus) return entry.key;
    }
    return -1;
  }

  void _scrollTo(int idx, {required bool goingDown}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _rowKeys[idx].currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration:        const Duration(milliseconds: 150),
          curve:           Curves.easeOut,
          alignmentPolicy: goingDown
              ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
              : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
        );
      }
    });
  }

  KeyEventResult _handleKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final idx = _focusedIndex;
    if (idx < 0) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
        idx + 1 < widget.episodes.length) {
      _nodeFor(idx + 1).requestFocus();
      _scrollTo(idx + 1, goingDown: true);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (idx > 0) {
        _nodeFor(idx - 1).requestFocus();
        _scrollTo(idx - 1, goingDown: false);
      } else {
        widget.firstSeasonNode?.requestFocus();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent:    _handleKey,
      skipTraversal: true,
      child: StaggeredList(
        children: widget.episodes.asMap().entries.map((e) => _EpisodeRow(
          key:       _rowKeys[e.key],
          seriesId:  widget.seriesId,
          episode:   e.value,
          episodes:  widget.episodes,
          index:     e.key,
          focusNode: _nodeFor(e.key),
          history:   _history[e.value.id],
        )).toList(),
      ),
    );
  }
}

// ── Episode Row ──────────────────────────────────────────────────────────────

class _EpisodeRow extends StatefulWidget {
  const _EpisodeRow({
    super.key,
    required this.seriesId,
    required this.episode,
    required this.episodes,
    required this.index,
    required this.focusNode,
    this.history,
  });
  final int                   seriesId;
  final Episode               episode;
  final List<Episode>         episodes;
  final int                   index;
  final FocusNode             focusNode;
  final Map<String, dynamic>? history;

  @override
  State<_EpisodeRow> createState() => _EpisodeRowState();
}

class _EpisodeRowState extends State<_EpisodeRow> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(_EpisodeRow old) {
    super.didUpdateWidget(old);
    if (old.focusNode != widget.focusNode) {
      old.focusNode.removeListener(_onFocusChange);
      widget.focusNode.addListener(_onFocusChange);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) setState(() => _focused = widget.focusNode.hasFocus);
  }

  void _play(BuildContext context) => context.push('/series/player', extra: {
    'vod': VodItem(
      id:           widget.episode.id,
      name:         widget.episode.title,
      streamUrl:    widget.episode.streamUrl,
      categoryId:   0,
      posterUrl:    widget.episode.thumbnailUrl,
      durationSecs: widget.episode.durationSecs,
    ),
    'backPath':     '/series/${widget.seriesId}',
    'episodes':     widget.episodes,
    'episodeIndex': widget.index,
  });

  double get _progress {
    final h = widget.history;
    if (h == null) return 0.0;
    final pos = (h['position_secs'] as int? ?? 0).toDouble();
    final dur = (h['duration_secs'] as int? ?? 1).toDouble();
    return dur > 0 ? (pos / dur).clamp(0.0, 1.0) : 0.0;
  }

  bool get _isWatched    => _progress >= 0.9;
  bool get _isInProgress => widget.history != null && !_isWatched;

  @override
  Widget build(BuildContext context) {
    return FocusableWidget(
      focusNode: widget.focusNode,
      onTap:     () => _play(context),
      child: AnimatedContainer(
          duration: AppDurations.fast,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.tvH,
            vertical:   16,
          ),
          decoration: BoxDecoration(
            color: _focused ? AppColors.accentSoft : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: _focused ? AppColors.accentPrimary : Colors.transparent,
                width: 3.0,
              ),
              bottom: const BorderSide(
                color: AppColors.borderSubtle, width: 0.5),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Episode number badge ──────────────────────────────────
              AnimatedContainer(
                duration: AppDurations.fast,
                width:  32,
                height: 32,
                decoration: BoxDecoration(
                  color: _focused
                      ? const Color(0x14C8A058)
                      : AppColors.card,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _focused
                        ? AppColors.borderGold
                        : AppColors.border,
                    width: 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${widget.episode.episodeNumber}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _isWatched
                        ? AppColors.textMuted
                        : _focused
                            ? AppColors.accentPrimary
                            : AppColors.textSecondary,
                    fontSize:   12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // ── Thumbnail ─────────────────────────────────────────────
              AnimatedContainer(
                duration: AppDurations.fast,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: _focused
                        ? const Color(0x50C8A058)
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5.5),
                  child: SizedBox(
                    width:  120,
                    height: 68,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        widget.episode.thumbnailUrl != null
                            ? CachedNetworkImage(
                                imageUrl:       widget.episode.thumbnailUrl!,
                                fit:            BoxFit.cover,
                                memCacheWidth:  240,
                                fadeInDuration: const Duration(milliseconds: 150),
                                placeholder:    (_, __) => const SizedBox.shrink(),
                                errorWidget:    (_, __, ___) =>
                                    _ThumbnailPlaceholder(
                                      number: widget.episode.episodeNumber),
                              )
                            : _ThumbnailPlaceholder(
                                number: widget.episode.episodeNumber),

                        // Watched overlay
                        if (_isWatched) ...[
                          Container(color: const Color(0x77000000)),
                          const Center(
                            child: Icon(Icons.check_circle_rounded,
                              color: Colors.white, size: 22),
                          ),
                        ],

                        // Play icon on focus (unwatched/in-progress)
                        if (_focused && !_isWatched)
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Color(0xCC000000),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.play_arrow_rounded,
                                color: Colors.white, size: 18),
                            ),
                          ),

                        // Progress bar
                        if (_isInProgress)
                          Positioned(
                            left: 0, right: 0, bottom: 0,
                            child: Container(
                              height: 3,
                              clipBehavior: Clip.hardEdge,
                              decoration: const BoxDecoration(
                                borderRadius: BorderRadius.only(
                                  bottomLeft:  Radius.circular(6),
                                  bottomRight: Radius.circular(6),
                                ),
                              ),
                              child: LinearProgressIndicator(
                                value:           _progress,
                                minHeight:       3,
                                backgroundColor: const Color(0x1AC8A058),
                                valueColor: const AlwaysStoppedAnimation(
                                  AppColors.accentPrimary),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // ── Info ──────────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment:  MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.episode.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _isWatched
                            ? AppColors.textMuted
                            : AppColors.textPrimary,
                        fontSize:   15,
                        fontWeight: _focused ? FontWeight.w500 : FontWeight.w400,
                        height:     1.3,
                      ),
                    ),
                    if (widget.episode.plot != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        widget.episode.plot!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color:      AppColors.textMuted,
                          fontSize:   11,
                          fontWeight: FontWeight.w300,
                          height:     1.5,
                        ),
                      ),
                    ],
                    if (_isInProgress) ...[
                      const SizedBox(height: 5),
                      Text(
                        '${(_progress * 100).round()}% watched',
                        style: const TextStyle(
                          color:    AppColors.accentPrimary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // ── Duration ──────────────────────────────────────────────
              if (widget.episode.durationSecs != null &&
                  widget.episode.durationSecs! > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(
                    _formatDuration(widget.episode.durationSecs!),
                    style: TextStyle(
                      color:    _focused ? AppColors.textSecondary : AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
  }

  String _formatDuration(int secs) {
    final m = secs ~/ 60;
    if (m >= 60) return '${m ~/ 60}h ${m % 60}m';
    return '${m}m';
  }
}

// ── Thumbnail Placeholder ────────────────────────────────────────────────────

class _ThumbnailPlaceholder extends StatelessWidget {
  const _ThumbnailPlaceholder({required this.number});
  final int number;

  @override
  Widget build(BuildContext context) {
    return Container(
      color:     AppColors.card,
      alignment: Alignment.center,
      child: Text(
        '$number',
        style: const TextStyle(
          color:      AppColors.textMuted,
          fontSize:   18,
          fontWeight: FontWeight.w300,
        ),
      ),
    );
  }
}
