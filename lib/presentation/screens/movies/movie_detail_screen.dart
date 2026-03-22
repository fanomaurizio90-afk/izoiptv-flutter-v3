import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/vod.dart';
import '../../providers/providers.dart';
import '../../widgets/common/focusable_widget.dart';
import '../../widgets/common/skeleton_widget.dart';

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
      backgroundColor: const Color(0xFF080808),
      body: vodAsync.when(
        data: (vod) {
          if (vod == null) {
            return Center(child: Text('Movie not found',
              style: GoogleFonts.dmSans(color: AppColors.textSecondary)));
          }
          return _MovieDetailBody(vod: vod);
        },
        loading: () => const SkeletonDetailBackdrop(),
        error:   (e, _) => Center(child: Text(e.toString(),
          style: GoogleFonts.dmSans(color: AppColors.error, fontSize: 12))),
      ),
    );
  }
}

class _MovieDetailBody extends StatelessWidget {
  const _MovieDetailBody({required this.vod});
  final VodItem vod;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final screenH = MediaQuery.of(context).size.height;

    return Stack(
      children: [
        // Full bleed backdrop — top 45%
        Positioned(
          top: 0, left: 0, right: 0,
          height: screenH * 0.45,
          child: vod.posterUrl != null
              ? CachedNetworkImage(
                  imageUrl:    vod.posterUrl!,
                  fit:         BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(color: AppColors.card),
                )
              : Container(color: AppColors.card),
        ),
        // Gradient fade: backdrop → #080808
        Positioned(
          top:    screenH * 0.20,
          left:   0, right: 0,
          height: screenH * 0.30,
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
        // Solid background below backdrop
        Positioned(
          top:    screenH * 0.45,
          left:   0, right: 0, bottom: 0,
          child:  Container(color: const Color(0xFF080808)),
        ),
        // Back button
        Positioned(
          top:  topPad + AppSpacing.sm,
          left: AppSpacing.tvH,
          child: FocusableWidget(
            onTap: () => context.pop(),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: const Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 18),
            ),
          ),
        ),
        // Scrollable content — starts at top 0, content has padding to clear backdrop
        Positioned.fill(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Spacer to clear backdrop
                SizedBox(height: screenH * 0.32),
                // Title + meta on top of the fade
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.tvH),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vod.name,
                        style: GoogleFonts.dmSans(
                          color:         AppColors.textPrimary,
                          fontSize:      22,
                          fontWeight:    FontWeight.w500,
                          letterSpacing: -0.3,
                          height:        1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Meta row: year · genre · duration
                      _MetaRow(vod: vod),
                      // Rating
                      if (vod.rating != null) ...[
                        const SizedBox(height: 8),
                        _StarRating(rating: vod.rating!),
                      ],
                      if (vod.plot != null) ...[
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          vod.plot!,
                          style: GoogleFonts.dmSans(
                            color:      AppColors.textSecondary,
                            fontSize:   13,
                            fontWeight: FontWeight.w300,
                            height:     1.6,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl3),
                      // Play button — full width, white bg, dark text, unmissable
                      FocusableWidget(
                        autofocus:    true,
                        borderRadius: AppSpacing.radiusCard,
                        onTap:        () => context.push('/movies/player', extra: vod),
                        child: Container(
                          width:   double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color:        AppColors.textPrimary,
                            borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.play_arrow, color: Color(0xFF080808), size: 20),
                              const SizedBox(width: 6),
                              Text(
                                'Play',
                                style: GoogleFonts.dmSans(
                                  color:      const Color(0xFF080808),
                                  fontSize:   14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl3),
                    ],
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

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.vod});
  final VodItem vod;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (vod.releaseDate != null) vod.releaseDate!,
      if (vod.genre != null)       vod.genre!,
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    return Text(
      parts.join('  ·  '),
      style: GoogleFonts.dmSans(
        color:         AppColors.textMuted,
        fontSize:      12,
        fontWeight:    FontWeight.w300,
        letterSpacing: 0.3,
        height:        1.4,
      ),
    );
  }
}

class _StarRating extends StatelessWidget {
  const _StarRating({required this.rating});
  final double rating;

  @override
  Widget build(BuildContext context) {
    final filled = (rating / 2).round().clamp(0, 5);
    return Row(
      children: [
        ...List.generate(5, (i) => Padding(
          padding: const EdgeInsets.only(right: 2),
          child: Icon(
            i < filled ? Icons.star : Icons.star_border,
            color: i < filled ? AppColors.textPrimary : AppColors.textMuted,
            size:  12,
          ),
        )),
        const SizedBox(width: 6),
        Text(
          rating.toStringAsFixed(1),
          style: GoogleFonts.dmSans(
            color:    AppColors.textMuted,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
