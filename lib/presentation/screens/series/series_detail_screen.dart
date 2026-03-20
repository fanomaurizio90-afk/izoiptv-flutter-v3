import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/series.dart';
import '../../providers/providers.dart';
import '../../widgets/common/focusable_widget.dart';
import '../../widgets/common/loading_widget.dart';

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
  const SeriesDetailScreen({super.key, required this.seriesId});
  final int seriesId;

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
    final seriesAsync = ref.watch(_seriesDetailProvider(widget.seriesId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: seriesAsync.when(
        data: (series) {
          if (series == null) {
            return const Center(child: Text('Series not found', style: TextStyle(color: AppColors.textSecondary)));
          }
          return _SeriesDetailBody(series: series);
        },
        loading: () => const LoadingWidget(),
        error:   (e, _) => Center(child: Text(e.toString(), style: const TextStyle(color: AppColors.error, fontSize: 12))),
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
    final topPad       = MediaQuery.of(context).padding.top;
    final selectedSeason = ref.watch(selectedSeasonProvider);
    final seasonsAsync   = ref.watch(seasonsProvider(widget.series.id));

    return Stack(
      children: [
        // Background
        if (widget.series.posterUrl != null)
          Positioned.fill(
            child: CachedNetworkImage(
              imageUrl:    widget.series.posterUrl!,
              fit:         BoxFit.cover,
              errorWidget: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        Positioned.fill(child: Container(color: const Color(0xCC080808))),

        // CRITICAL: use MediaQuery not SafeArea for Positioned
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

        Positioned(
          top:    topPad + 48,
          left:   0,
          right:  0,
          bottom: 0,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.series.name,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (widget.series.genre != null)
                  Text(widget.series.genre!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                if (widget.series.plot != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(widget.series.plot!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.6)),
                ],
                const SizedBox(height: AppSpacing.xl2),

                // Seasons
                seasonsAsync.when(
                  data: (seasons) {
                    if (seasons.isEmpty) {
                      return const Text('No episodes', style: TextStyle(color: AppColors.textMuted, fontSize: 13));
                    }
                    final season = seasons.firstWhere(
                      (s) => s.number == selectedSeason,
                      orElse: () => seasons.first,
                    );
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Season tabs
                        SizedBox(
                          height: 32,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount:       seasons.length,
                            itemBuilder:     (_, i) {
                              final s          = seasons[i];
                              final isSelected = s.number == selectedSeason;
                              return GestureDetector(
                                onTap: () => ref.read(selectedSeasonProvider.notifier).state = s.number,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: AppSpacing.lg),
                                  child: Text(
                                    'Season ${s.number}',
                                    style: TextStyle(
                                      color:      isSelected ? AppColors.textPrimary : AppColors.textMuted,
                                      fontSize:   13,
                                      fontWeight: isSelected ? FontWeight.w400 : FontWeight.w300,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        // Episodes
                        ...season.episodes.map((ep) => _EpisodeRow(episode: ep)),
                      ],
                    );
                  },
                  loading: () => const LoadingWidget(),
                  error:   (e, _) => Text(e.toString(), style: const TextStyle(color: AppColors.error, fontSize: 12)),
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
  const _EpisodeRow({required this.episode});
  final Episode episode;

  @override
  Widget build(BuildContext context) {
    return FocusableWidget(
      onTap: () => context.push('/series/player', extra: episode),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
        ),
        child: Row(
          children: [
            // Thumbnail
            if (episode.thumbnailUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: CachedNetworkImage(
                  imageUrl:   episode.thumbnailUrl!,
                  width:      80,
                  height:     45,
                  fit:        BoxFit.cover,
                  errorWidget: (_, __, ___) => const SizedBox(width: 80, height: 45),
                ),
              )
            else
              Container(
                width: 80, height: 45,
                color: AppColors.card,
                alignment: Alignment.center,
                child: const Icon(Icons.play_circle_outline, color: AppColors.textMuted, size: 18),
              ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${episode.episodeNumber}. ${episode.title}',
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w400),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (episode.plot != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      episode.plot!,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.play_arrow_outlined, color: AppColors.textMuted, size: 18),
          ],
        ),
      ),
    );
  }
}
