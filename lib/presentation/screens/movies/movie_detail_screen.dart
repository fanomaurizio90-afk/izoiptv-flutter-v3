import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/vod.dart';
import '../../providers/providers.dart';
import '../../widgets/common/focusable_widget.dart';
import '../../widgets/common/loading_widget.dart';

final _vodDetailProvider = FutureProvider.family<VodItem?, int>((ref, id) async {
  return ref.watch(vodRepositoryProvider).getVodById(id);
});

class MovieDetailScreen extends ConsumerWidget {
  const MovieDetailScreen({super.key, required this.vodId});
  final int vodId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vodAsync = ref.watch(_vodDetailProvider(vodId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: vodAsync.when(
        data: (vod) {
          if (vod == null) {
            return const Center(child: Text('Movie not found', style: TextStyle(color: AppColors.textSecondary)));
          }
          return _MovieDetailBody(vod: vod);
        },
        loading: () => const LoadingWidget(),
        error:   (e, _) => Center(child: Text(e.toString(), style: const TextStyle(color: AppColors.error, fontSize: 12))),
      ),
    );
  }
}

class _MovieDetailBody extends StatelessWidget {
  const _MovieDetailBody({required this.vod});
  final VodItem vod;

  @override
  Widget build(BuildContext context) {
    // CRITICAL: Never wrap Positioned in SafeArea inside Stack
    // Use MediaQuery.of(context).padding.top instead
    final topPad = MediaQuery.of(context).padding.top;

    return Stack(
      children: [
        // Background poster
        if (vod.posterUrl != null)
          Positioned.fill(
            child: CachedNetworkImage(
              imageUrl:    vod.posterUrl!,
              fit:         BoxFit.cover,
              errorWidget: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        // Dark overlay
        Positioned.fill(
          child: Container(color: const Color(0xCC080808)),
        ),
        // Back button — MUST use MediaQuery, NOT SafeArea-wrapped Positioned
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
        // Content
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
                  vod.name,
                  style: const TextStyle(
                    color:      AppColors.textPrimary,
                    fontSize:   16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                // Meta row
                Wrap(
                  spacing: AppSpacing.md,
                  children: [
                    if (vod.releaseDate != null)
                      Text(vod.releaseDate!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    if (vod.genre != null)
                      Text(vod.genre!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    if (vod.rating != null)
                      Text('★ ${vod.rating!.toStringAsFixed(1)}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
                if (vod.plot != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    vod.plot!,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.6),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl3),
                // Play button
                FocusableWidget(
                  borderRadius: AppSpacing.radiusCard,
                  onTap: () => context.push('/movies/player', extra: vod),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                      border:       Border.all(color: AppColors.accentSoft, width: 0.5),
                    ),
                    alignment: Alignment.center,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_arrow_outlined, color: AppColors.textPrimary, size: 18),
                        SizedBox(width: AppSpacing.xs),
                        Text('Play', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w400)),
                      ],
                    ),
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
