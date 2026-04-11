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

  final _favNode     = FocusNode();
  final _trailerNode = FocusNode();
  List<FocusNode> _seasonNodes = [];
  FocusNode? _firstEpisodeNode;

  late final AnimationController _entranceCtrl;

  @override
  void initState() {
    super.initState();
    _displaySeries = widget.series;
    ref.read(selectedSeasonProvider.notifier).state = 1;
    _entranceCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
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
      if (_seasonNodes.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_favNode.hasFocus) {
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
        _favNode.requestFocus();
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (i < total - 1) {
        _seasonNodes[i + 1].requestFocus();
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _firstEpisodeNode?.requestFocus();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _favNode.requestFocus();
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
    final selectedSeason = ref.watch(selectedSeasonProvider);
    final seasonsAsync   = ref.watch(seasonsProvider(widget.series.id));
    final hasTrailer     = _displaySeries.youtubeTrailer != null &&
                           _displaySeries.youtubeTrailer!.isNotEmpty;

    ref.listen(seasonsProvider(widget.series.id), (_, next) {
      if (next.hasValue &&
          (_displaySeries.posterUrl == null ||
           _displaySeries.rating == null ||
           _displaySeries.cast == null)) {
        _refreshMetadataFromDb();
      }
    });

    final fadeIn = CurvedAnimation(parent: _entranceCtrl, curve: AppCurves.easeOut);
    final posterSlide = Tween<Offset>(
      begin: const Offset(-0.04, 0), end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceCtrl,
      curve:  const Interval(0.0, 0.7, curve: AppCurves.easeOut),
    ));
    final rightSlide = Tween<Offset>(
      begin: const Offset(0.03, 0), end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceCtrl,
      curve:  const Interval(0.15, 0.85, curve: AppCurves.easeOut),
    ));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.tvH,
          vertical:   AppSpacing.lg,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Left column: Poster + Info ──────────────────────────────
            Expanded(
              flex: 1,
              child: FadeTransition(
              opacity: fadeIn,
              child: SlideTransition(
                position: posterSlide,
                child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Poster with fav overlay
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: _displaySeries.posterUrl != null
                                  ? CachedNetworkImage(
                                      imageUrl:       _displaySeries.posterUrl!,
                                      width:          182,
                                      height:         260,
                                      fit:            BoxFit.cover,
                                      memCacheWidth:  364,
                                      fadeInDuration: const Duration(milliseconds: 200),
                                      placeholder:    (_, __) => Container(
                                        width: 182, height: 260,
                                        decoration: BoxDecoration(
                                          color: AppColors.card,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      errorWidget: (_, __, ___) => Container(
                                        width: 182, height: 260,
                                        decoration: BoxDecoration(
                                          color: AppColors.card,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(Icons.tv_rounded,
                                          color: AppColors.textMuted, size: 40),
                                      ),
                                    )
                                  : Container(
                                      width: 182, height: 260,
                                      decoration: BoxDecoration(
                                        color: AppColors.card,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(Icons.tv_rounded,
                                        color: AppColors.textMuted, size: 40),
                                    ),
                            ),
                            Positioned(
                              top: 8, right: 8,
                              child: Focus(
                                onKeyEvent: (_, event) {
                                  if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
                                  if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                                    if (_seasonNodes.isNotEmpty) {
                                      _seasonNodes[0].requestFocus();
                                    } else {
                                      _firstEpisodeNode?.requestFocus();
                                    }
                                    return KeyEventResult.handled;
                                  }
                                  if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                                    if (hasTrailer) {
                                      _trailerNode.requestFocus();
                                    }
                                    return KeyEventResult.handled;
                                  }
                                  return KeyEventResult.ignored;
                                },
                                child: FocusableWidget(
                                  focusNode:    _favNode,
                                  autofocus:    true,
                                  borderRadius: 8,
                                  onTap: widget.onToggleFavourite,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: AppColors.background.withValues(alpha: 0.7),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppColors.glassBorder, width: 0.5),
                                    ),
                                    child: Icon(
                                      _displaySeries.isFavourite
                                          ? Icons.favorite_rounded
                                          : Icons.favorite_border_rounded,
                                      color: _displaySeries.isFavourite
                                          ? AppColors.accentPrimary
                                          : AppColors.textSecondary,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Title
                        Text(
                          _displaySeries.name,
                          style: const TextStyle(
                            color:         AppColors.textPrimary,
                            fontSize:      18,
                            fontWeight:    FontWeight.w500,
                            letterSpacing: -0.3,
                            height:        1.2,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Meta
                        _SeriesMeta(series: _displaySeries),
                        const SizedBox(height: 14),

                        // Plot
                        if (_displaySeries.plot != null) ...[
                          Text(
                            _displaySeries.plot!,
                            maxLines: 12,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color:      AppColors.textSecondary,
                              fontSize:   12,
                              fontWeight: FontWeight.w300,
                              height:     1.65,
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Director / Cast
                        if (_displaySeries.director != null) ...[
                          _InfoLabel('Director'),
                          const SizedBox(height: 2),
                          Text(_displaySeries.director!,
                            style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 11,
                              fontWeight: FontWeight.w400, height: 1.4,
                            )),
                          const SizedBox(height: 10),
                        ],
                        if (_displaySeries.cast != null) ...[
                          _InfoLabel('Cast'),
                          const SizedBox(height: 2),
                          Text(_displaySeries.cast!,
                            maxLines: 3, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 11,
                              fontWeight: FontWeight.w300, height: 1.5,
                            )),
                          const SizedBox(height: 10),
                        ],

                        // Trailer
                        if (hasTrailer) ...[
                          const SizedBox(height: 4),
                          Focus(
                            onKeyEvent: (_, event) {
                              if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
                              if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                                _favNode.requestFocus();
                                return KeyEventResult.handled;
                              }
                              if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                                _firstEpisodeNode?.requestFocus();
                                return KeyEventResult.handled;
                              }
                              return KeyEventResult.ignored;
                            },
                            child: _TrailerButton(
                              focusNode: _trailerNode,
                              onTap:     _openTrailer,
                            ),
                          ),
                        ],

                        const SizedBox(height: AppSpacing.xl3),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 28),

            // ── Right column: Seasons + Episodes ───────────────────────
            Expanded(
              child: FadeTransition(
                opacity: fadeIn,
                child: SlideTransition(
                  position: rightSlide,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      seasonsAsync.when(
                        data: (seasons) {
                          if (seasons.isEmpty) {
                            return Expanded(
                              child: Center(
                                child: Text('No episodes available',
                                  style: TextStyle(
                                    color: AppColors.textMuted, fontSize: 13)),
                              ),
                            );
                          }
                          _rebuildSeasonNodes(seasons.length > 1 ? seasons.length : 0);
                          final season = seasons.firstWhere(
                            (s) => s.number == selectedSeason,
                            orElse: () => seasons.first,
                          );
                          return Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (seasons.length > 1)
                                  _SeasonTabs(
                                    seasons:        seasons,
                                    selectedNumber: selectedSeason,
                                    nodes:          _seasonNodes,
                                    onSelect: (num) => ref
                                        .read(selectedSeasonProvider.notifier)
                                        .state = num,
                                    onKey: _handleSeasonKey,
                                  ),
                                if (seasons.length > 1)
                                  const SizedBox(height: 8),
                                Expanded(
                                  child: _EpisodeList(
                                    key: ValueKey(
                                      '${widget.series.id}_$selectedSeason'),
                                    seriesId:  widget.series.id,
                                    episodes:  season.episodes,
                                    firstSeasonNode: _seasonNodes.isNotEmpty
                                        ? _seasonNodes[0]
                                        : null,
                                    leftExitNode: hasTrailer
                                        ? _trailerNode
                                        : _favNode,
                                    onFirstNodeReady: (node) {
                                      _firstEpisodeNode = node;
                                    },
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        loading: () => const Expanded(
                          child: Padding(
                            padding: EdgeInsets.all(AppSpacing.xl2),
                            child: SkeletonChannelList(count: 5),
                          ),
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
          ],
        ),
      ),
    );
  }
}

// ── Series Meta ──────────────────────────────────────────────────────────────

class _SeriesMeta extends StatelessWidget {
  const _SeriesMeta({required this.series});
  final SeriesItem series;

  @override
  Widget build(BuildContext context) {
    final parts = <Widget>[];

    if (series.rating != null && series.rating! > 0) {
      parts.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color:        const Color(0xFFF5C518),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_rounded, color: Color(0xFF121212), size: 12),
            const SizedBox(width: 2),
            Text(
              series.rating!.toStringAsFixed(1),
              style: const TextStyle(
                color: Color(0xFF121212), fontSize: 11, fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ));
    }

    final textParts = <String>[
      if (series.releaseDate != null) series.releaseDate!,
      if (series.genre != null) series.genre!,
    ];

    if (parts.isNotEmpty && textParts.isNotEmpty) {
      parts.add(const SizedBox(width: 10));
    }

    if (textParts.isNotEmpty) {
      parts.add(Expanded(
        child: Text(
          textParts.join('  ·  '),
          style: const TextStyle(
            color:         AppColors.textMuted,
            fontSize:      11,
            fontWeight:    FontWeight.w400,
            letterSpacing: 0.2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ));
    }

    return Row(children: parts);
  }
}

// ── Info Label ───────────────────────────────────────────────────────────────

class _InfoLabel extends StatelessWidget {
  const _InfoLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color:         AppColors.textMuted,
        fontSize:      9,
        fontWeight:    FontWeight.w600,
        letterSpacing: 1.2,
      ),
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
      borderRadius: 10,
      onTap:        widget.onTap,
      child: Focus(
        canRequestFocus: false,
        onFocusChange: (f) { if (mounted) setState(() => _focused = f); },
        child: AnimatedContainer(
          duration: AppDurations.focus,
          width:    double.infinity,
          padding:  const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: _focused ? const Color(0xFFFF0000) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _focused ? const Color(0xFFFF0000) : AppColors.glassBorder,
              width: 0.5,
            ),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.play_circle_outline_rounded,
                color: _focused ? Colors.white : AppColors.textMuted,
                size: 15,
              ),
              const SizedBox(width: 5),
              Text(
                'Trailer',
                style: TextStyle(
                  color: _focused ? Colors.white : AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Season Tabs (horizontal) ────────────────────────────────────────────────

class _SeasonTabs extends StatefulWidget {
  const _SeasonTabs({
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
  State<_SeasonTabs> createState() => _SeasonTabsState();
}

class _SeasonTabsState extends State<_SeasonTabs> {
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
  void didUpdateWidget(_SeasonTabs old) {
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
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding:   const EdgeInsets.only(left: 4),
        itemCount: widget.seasons.length,
        itemBuilder: (_, i) {
          final s          = widget.seasons[i];
          final isSelected = s.number == widget.selectedNumber;
          final isFocused  = _focusedIdx == i;
          return Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Focus(
              onKeyEvent: (_, e) => widget.onKey(i, widget.seasons.length, e),
              child: FocusableWidget(
                focusNode:       widget.nodes[i],
                borderRadius:    8,
                showFocusBorder: false,
                onTap:           () => widget.onSelect(s.number),
                child: AnimatedContainer(
                  duration: AppDurations.fast,
                  curve:    AppCurves.easeOut,
                  padding:  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: isFocused
                        ? AppColors.accentSoft
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Season ${s.number}',
                        style: TextStyle(
                          color: isSelected
                              ? AppColors.accentPrimary
                              : isFocused
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                          fontSize:   13,
                          fontWeight: isSelected
                              ? FontWeight.w500
                              : FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 3),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve:    AppCurves.easeOut,
                        width:    isSelected ? 16 : 0,
                        height:   2,
                        decoration: BoxDecoration(
                          color: AppColors.accentPrimary,
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
    this.leftExitNode,
  });
  final int                      seriesId;
  final List<Episode>            episodes;
  final void Function(FocusNode) onFirstNodeReady;
  final FocusNode?               firstSeasonNode;
  final FocusNode?               leftExitNode;

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
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      widget.leftExitNode?.requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent:    _handleKey,
      skipTraversal: true,
      child: ListView.builder(
        padding:   const EdgeInsets.only(top: 4, bottom: AppSpacing.xl3),
        itemCount: widget.episodes.length,
        itemBuilder: (_, i) => _EpisodeRow(
          key:       _rowKeys[i],
          seriesId:  widget.seriesId,
          episode:   widget.episodes[i],
          episodes:  widget.episodes,
          index:     i,
          focusNode: _nodeFor(i),
          history:   _history[widget.episodes[i].id],
        ),
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

  String get _epDuration {
    final s = widget.episode.durationSecs;
    if (s == null || s <= 0) return '';
    final m = s ~/ 60;
    return '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final thumb = widget.episode.thumbnailUrl;
    return FocusableWidget(
      focusNode:       widget.focusNode,
      showFocusBorder: false,
      onTap:           () => _play(context),
      child: AnimatedContainer(
        duration: AppDurations.fast,
        curve:    AppCurves.easeOut,
        margin:  const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Thumbnail with episode number overlay ─────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                children: [
                  SizedBox(
                    width:  107,
                    height: 60,
                    child: thumb != null && thumb.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl:      thumb,
                            width:         107,
                            height:        60,
                            fit:           BoxFit.cover,
                            memCacheWidth: 214,
                            placeholder:   (_, __) => _ThumbnailPlaceholder(
                                number: widget.episode.episodeNumber),
                            errorWidget:   (_, __, ___) => _ThumbnailPlaceholder(
                                number: widget.episode.episodeNumber),
                          )
                        : _ThumbnailPlaceholder(
                            number: widget.episode.episodeNumber),
                  ),
                  // Darkening gradient for legibility
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomLeft,
                          end:   Alignment.topRight,
                          colors: [
                            AppColors.background.withValues(alpha: 0.55),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Episode number badge (bottom-left, Stremio style)
                  Positioned(
                    left: 5, bottom: 3,
                    child: Text(
                      'E${widget.episode.episodeNumber}',
                      style: const TextStyle(
                        color:         Colors.white,
                        fontSize:      10,
                        fontWeight:    FontWeight.w700,
                        letterSpacing: 0.3,
                        shadows: [
                          Shadow(color: Colors.black54, blurRadius: 4),
                        ],
                      ),
                    ),
                  ),
                  // Play icon on focus
                  if (_focused)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.3),
                        alignment: Alignment.center,
                        child: const Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 28),
                      ),
                    ),
                  // Watched check
                  if (_isWatched)
                    Positioned(
                      top: 4, right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: AppColors.background.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.check_rounded,
                          color: Colors.white, size: 12),
                      ),
                    ),
                  // In-progress bar
                  if (_isInProgress)
                    Positioned(
                      left: 0, right: 0, bottom: 0,
                      child: LinearProgressIndicator(
                        value:           _progress,
                        minHeight:       3,
                        backgroundColor: Colors.black.withValues(alpha: 0.4),
                        valueColor:      const AlwaysStoppedAnimation(
                            AppColors.accentPrimary),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // ── Episode info ─────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row: number + title + duration
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          '${widget.episode.episodeNumber}. ${widget.episode.title}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _focused
                                ? AppColors.accentPrimary
                                : _isWatched
                                    ? AppColors.textMuted
                                    : AppColors.textPrimary,
                            fontSize:      11,
                            fontWeight:    FontWeight.w600,
                            letterSpacing: -0.1,
                            height:        1.2,
                          ),
                        ),
                      ),
                      if (_epDuration.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(
                          _epDuration,
                          style: const TextStyle(
                            color:      AppColors.textMuted,
                            fontSize:   9,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  // Plot snippet
                  Text(
                    (widget.episode.plot?.trim().isNotEmpty ?? false)
                        ? widget.episode.plot!
                        : 'No description available.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color:      AppColors.textSecondary,
                      fontSize:   9,
                      fontWeight: FontWeight.w300,
                      height:     1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Thumbnail Placeholder ───────────────────────────────────────────────────

class _ThumbnailPlaceholder extends StatelessWidget {
  const _ThumbnailPlaceholder({required this.number});
  final int number;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.card,
      alignment: Alignment.center,
      child: Text(
        'E$number',
        style: const TextStyle(
          color:      AppColors.textMuted,
          fontSize:   11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
