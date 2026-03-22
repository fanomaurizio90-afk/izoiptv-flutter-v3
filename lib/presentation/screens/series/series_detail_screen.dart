import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
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
  @override
  void initState() {
    super.initState();
    // CRITICAL: reset every time
    ref.read(selectedSeasonProvider.notifier).state = 1;
  }

  @override
  Widget build(BuildContext context) {
    final topPad         = MediaQuery.of(context).padding.top;
    final screenH        = MediaQuery.of(context).size.height;
    final selectedSeason = ref.watch(selectedSeasonProvider);
    final seasonsAsync   = ref.watch(seasonsProvider(widget.series.id));

    return Stack(
      children: [
        // Full bleed backdrop
        Positioned(
          top: 0, left: 0, right: 0,
          height: screenH * 0.42,
          child: widget.series.posterUrl != null
              ? CachedNetworkImage(
                  imageUrl:    widget.series.posterUrl!,
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
          left: AppSpacing.sm,
          child: FocusableWidget(
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
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.series.name,
                        style: GoogleFonts.dmSans(
                          color:         AppColors.textPrimary,
                          fontSize:      22,
                          fontWeight:    FontWeight.w500,
                          letterSpacing: -0.3,
                          height:        1.2,
                        ),
                      ),
                      if (widget.series.genre != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          widget.series.genre!,
                          style: GoogleFonts.dmSans(
                            color:    AppColors.textMuted,
                            fontSize: 12,
                            height:   1.4,
                          ),
                        ),
                      ],
                      if (widget.series.plot != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          widget.series.plot!,
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
                    final season = seasons.firstWhere(
                      (s) => s.number == selectedSeason,
                      orElse: () => seasons.first,
                    );
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Season tabs — plain text, no pills
                        SizedBox(
                          height: 40,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding:         const EdgeInsets.symmetric(horizontal: AppSpacing.xl2),
                            itemCount:       seasons.length,
                            itemBuilder:     (_, i) {
                              final s          = seasons[i];
                              final isSelected = s.number == selectedSeason;
                              return FocusableWidget(
                                autofocus: i == 0,
                                onTap:     () => ref.read(selectedSeasonProvider.notifier).state = s.number,
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
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        // Episodes
                        ...season.episodes.asMap().entries.map((e) => _EpisodeRow(
                          episode:   e.value,
                          episodes:  season.episodes,
                          index:     e.key,
                          autofocus: e.key == 0,
                        )),
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

class _EpisodeRow extends StatelessWidget {
  const _EpisodeRow({
    required this.episode,
    required this.episodes,
    required this.index,
    this.autofocus = false,
  });
  final Episode       episode;
  final List<Episode> episodes;
  final int           index;
  final bool          autofocus;

  @override
  Widget build(BuildContext context) {
    return FocusableWidget(
      autofocus: autofocus,
      onTap: () => context.push('/series/player', extra: {
        'episode':  episode,
        'episodes': episodes,
        'index':    index,
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl2,
          vertical:   AppSpacing.md,
        ),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.borderSubtle, width: 0.5),
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
                child: episode.thumbnailUrl != null
                    ? CachedNetworkImage(
                        imageUrl:    episode.thumbnailUrl!,
                        fit:         BoxFit.cover,
                        errorWidget: (_, __, ___) => _ThumbnailPlaceholder(number: episode.episodeNumber),
                      )
                    : _ThumbnailPlaceholder(number: episode.episodeNumber),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${episode.episodeNumber}. ${episode.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      color:      AppColors.textPrimary,
                      fontSize:   13,
                      fontWeight: FontWeight.w400,
                      height:     1.4,
                    ),
                  ),
                  if (episode.plot != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      episode.plot!,
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
          color:    AppColors.textMuted,
          fontSize: 18,
          fontWeight: FontWeight.w300,
        ),
      ),
    );
  }
}
