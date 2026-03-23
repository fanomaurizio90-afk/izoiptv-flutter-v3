import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/series.dart';
import '../../providers/providers.dart';
import '../../widgets/common/focusable_widget.dart';
import '../../widgets/common/skeleton_widget.dart';

// CRITICAL: autoDispose — must not persist stale episode data between series
final _seriesDetailProvider = FutureProvider.family<SeriesItem?, int>((ref, id) async {
  return ref.watch(seriesRepositoryProvider).getSeriesById(id);
});

final seasonsProvider = FutureProvider.autoDispose.family<List<Season>, int>((ref, seriesId) async {
  return ref.watch(seriesRepositoryProvider).getSeasons(seriesId);
});

// Global season selector — MUST reset to 1 on every series open
final selectedSeasonProvider = StateProvider<int>((ref) => 1);

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
    // CRITICAL: reset season selection every time a series opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(selectedSeasonProvider.notifier).state = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.series != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF080808),
        body: _SeriesDetailBody(series: widget.series!),
      );
    }
    final seriesAsync = ref.watch(_seriesDetailProvider(widget.seriesId));
    return Scaffold(
      backgroundColor: const Color(0xFF080808),
      body: seriesAsync.when(
        data: (series) {
          if (series == null) {
            return Center(child: Text('Series not found',
              style: GoogleFonts.dmSans(color: AppColors.textSecondary)));
          }
          return _SeriesDetailBody(series: series);
        },
        loading: () => const SkeletonDetailBackdrop(),
        error:   (e, _) => Center(child: Text(e.toString(),
          style: GoogleFonts.dmSans(color: AppColors.error, fontSize: 12))),
      ),
    );
  }
}

class _SeriesDetailBody extends ConsumerStatefulWidget {
  const _SeriesDetailBody({required this.series});
  final SeriesItem series;

  @override
  ConsumerState<_SeriesDetailBody> createState() => _SeriesDetailBodyState();
}

class _SeriesDetailBodyState extends ConsumerState<_SeriesDetailBody> {
  late SeriesItem _displaySeries;

  // Focus nodes
  final _backNode = FocusNode();
  List<FocusNode> _seasonNodes = [];
  // Link: season tabs → first episode (set by _EpisodeList callback)
  FocusNode? _firstEpisodeNode;

  @override
  void initState() {
    super.initState();
    _displaySeries = widget.series;
    ref.read(selectedSeasonProvider.notifier).state = 1;
  }

  @override
  void dispose() {
    _backNode.dispose();
    for (final n in _seasonNodes) n.dispose();
    super.dispose();
  }

  void _rebuildSeasonNodes(int count) {
    if (_seasonNodes.length != count) {
      for (final n in _seasonNodes) n.dispose();
      _seasonNodes = List.generate(count, (_) => FocusNode());
    }
  }

  KeyEventResult _handleSeasonKey(int i, int total, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (i > 0) {
        _seasonNodes[i - 1].requestFocus();
      } else {
        _backNode.requestFocus();
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (i < total - 1) {
        _seasonNodes[i + 1].requestFocus();
      } else {
        _firstEpisodeNode?.requestFocus();
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _firstEpisodeNode?.requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Called after seasons finish loading — DB may have richer metadata
  Future<void> _refreshMetadataFromDb() async {
    final fresh = await ref.read(seriesRepositoryProvider).getSeriesById(widget.series.id);
    if (fresh != null && mounted) setState(() => _displaySeries = fresh);
  }

  @override
  Widget build(BuildContext context) {
    final topPad         = MediaQuery.of(context).padding.top;
    final screenH        = MediaQuery.of(context).size.height;
    final selectedSeason = ref.watch(selectedSeasonProvider);
    final seasonsAsync   = ref.watch(seasonsProvider(widget.series.id));

    ref.listen(seasonsProvider(widget.series.id), (_, next) {
      if (next.hasValue && _displaySeries.posterUrl == null) {
        _refreshMetadataFromDb();
      }
    });

    return Stack(
      children: [
        // Full bleed backdrop
        Positioned(
          top: 0, left: 0, right: 0,
          height: screenH * 0.42,
          child: _displaySeries.posterUrl != null
              ? CachedNetworkImage(
                  imageUrl:    _displaySeries.posterUrl!,
                  fit:         BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(color: AppColors.card),
                )
              : Container(color: AppColors.card),
        ),
        // Gradient fade
        Positioned(
          top:    screenH * 0.18,
          left:   0, right: 0,
          height: screenH * 0.28,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin:  Alignment.topCenter,
                end:    Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xFF080808)],
              ),
            ),
          ),
        ),
        Positioned(
          top:    screenH * 0.42,
          left:   0, right: 0, bottom: 0,
          child:  Container(color: const Color(0xFF080808)),
        ),
        // Back button
        Positioned(
          top:  topPad + AppSpacing.sm,
          left: AppSpacing.tvH,
          child: FocusableWidget(
            focusNode: _backNode,
            autofocus: true,
            onTap: () => context.pop(),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: const Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 18),
            ),
          ),
        ),
        // Scrollable content
        Positioned.fill(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: screenH * 0.30),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.tvH),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _displaySeries.name,
                        style: GoogleFonts.dmSans(
                          color:         AppColors.textPrimary,
                          fontSize:      22,
                          fontWeight:    FontWeight.w500,
                          letterSpacing: -0.3,
                          height:        1.2,
                        ),
                      ),
                      if (_displaySeries.genre != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          _displaySeries.genre!,
                          style: GoogleFonts.dmSans(
                            color:    AppColors.textMuted,
                            fontSize: 12,
                            height:   1.4,
                          ),
                        ),
                      ],
                      if (_displaySeries.plot != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          _displaySeries.plot!,
                          style: GoogleFonts.dmSans(
                            color:      AppColors.textSecondary,
                            fontSize:   13,
                            fontWeight: FontWeight.w300,
                            height:     1.6,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl2),
                    ],
                  ),
                ),
                // Season tabs + episodes
                seasonsAsync.when(
                  data: (seasons) {
                    if (seasons.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl2),
                        child: Text('No episodes',
                          style: GoogleFonts.dmSans(color: AppColors.textMuted, fontSize: 13)),
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
                        // Season tabs
                        SizedBox(
                          height: 40,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding:         const EdgeInsets.symmetric(horizontal: AppSpacing.tvH),
                            itemCount:       seasons.length,
                            itemBuilder:     (_, i) {
                              final s          = seasons[i];
                              final isSelected = s.number == selectedSeason;
                              return Focus(
                                onKeyEvent: (_, e) => _handleSeasonKey(i, seasons.length, e),
                                child: FocusableWidget(
                                  focusNode: _seasonNodes[i],
                                  onTap: () => ref.read(selectedSeasonProvider.notifier).state = s.number,
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: AppSpacing.xl2),
                                    child: Center(
                                      child: Text(
                                        'Season ${s.number}',
                                        style: GoogleFonts.dmSans(
                                          color:      isSelected ? AppColors.textPrimary : AppColors.textMuted,
                                          fontSize:   13,
                                          fontWeight: isSelected ? FontWeight.w500 : FontWeight.w300,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        // Episode list with explicit up/down navigation
                        _EpisodeList(
                          key:            ValueKey('${widget.series.id}_$selectedSeason'),
                          episodes:       season.episodes,
                          firstSeasonNode: _seasonNodes.isNotEmpty ? _seasonNodes[0] : null,
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
                      style: GoogleFonts.dmSans(color: AppColors.error, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Episode List ───────────────────────────────────────────────────────────────

class _EpisodeList extends StatefulWidget {
  const _EpisodeList({
    super.key,
    required this.episodes,
    required this.onFirstNodeReady,
    this.firstSeasonNode,
  });
  final List<Episode>            episodes;
  final void Function(FocusNode) onFirstNodeReady;
  final FocusNode?               firstSeasonNode;

  @override
  State<_EpisodeList> createState() => _EpisodeListState();
}

class _EpisodeListState extends State<_EpisodeList> {
  List<FocusNode> _nodes = [];

  @override
  void initState() {
    super.initState();
    _nodes = List.generate(widget.episodes.length, (_) => FocusNode());
    _notifyFirst();
  }

  @override
  void dispose() {
    for (final n in _nodes) n.dispose();
    super.dispose();
  }

  void _notifyFirst() {
    if (_nodes.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onFirstNodeReady(_nodes[0]);
      });
    }
  }

  int get _focusedIndex {
    for (int i = 0; i < _nodes.length; i++) {
      if (_nodes[i].hasFocus) return i;
    }
    return -1;
  }

  KeyEventResult _handleKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final idx = _focusedIndex;
    if (idx < 0) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown && idx + 1 < _nodes.length) {
      _nodes[idx + 1].requestFocus();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (idx > 0) {
        _nodes[idx - 1].requestFocus();
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
      child: Column(
        children: widget.episodes.asMap().entries.map((e) => _EpisodeRow(
          episode:   e.value,
          episodes:  widget.episodes,
          index:     e.key,
          focusNode: _nodes[e.key],
        )).toList(),
      ),
    );
  }
}

// ── Episode Row ────────────────────────────────────────────────────────────────

class _EpisodeRow extends StatefulWidget {
  const _EpisodeRow({
    required this.episode,
    required this.episodes,
    required this.index,
    required this.focusNode,
  });
  final Episode       episode;
  final List<Episode> episodes;
  final int           index;
  final FocusNode     focusNode;

  @override
  State<_EpisodeRow> createState() => _EpisodeRowState();
}

class _EpisodeRowState extends State<_EpisodeRow> {
  bool _focused = false;

  void _play(BuildContext context) => context.push('/series/player', extra: {
    'episode':  widget.episode,
    'episodes': widget.episodes,
    'index':    widget.index,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (f) { if (mounted) setState(() => _focused = f); },
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.enter)) {
          _play(context);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: () => _play(context),
        child: AnimatedContainer(
          duration: AppDurations.medium,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.tvH,
            vertical:   AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: _focused ? const Color(0x12FFFFFF) : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: _focused ? AppColors.textPrimary : Colors.transparent,
                width: 2.5,
              ),
              bottom: const BorderSide(color: AppColors.borderSubtle, width: 0.5),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width:  96,
                  height: 54,
                  child: widget.episode.thumbnailUrl != null
                      ? CachedNetworkImage(
                          imageUrl:    widget.episode.thumbnailUrl!,
                          fit:         BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              _ThumbnailPlaceholder(number: widget.episode.episodeNumber),
                        )
                      : _ThumbnailPlaceholder(number: widget.episode.episodeNumber),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.episode.episodeNumber}. ${widget.episode.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        color:      AppColors.textPrimary,
                        fontSize:   13,
                        fontWeight: FontWeight.w400,
                        height:     1.4,
                      ),
                    ),
                    if (widget.episode.plot != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        widget.episode.plot!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          color:      AppColors.textMuted,
                          fontSize:   11,
                          fontWeight: FontWeight.w300,
                          height:     1.4,
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

class _ThumbnailPlaceholder extends StatelessWidget {
  const _ThumbnailPlaceholder({required this.number});
  final int number;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.card,
      alignment: Alignment.center,
      child: Text(
        '$number',
        style: GoogleFonts.dmSans(
          color:      AppColors.textMuted,
          fontSize:   18,
          fontWeight: FontWeight.w300,
        ),
      ),
    );
  }
}
