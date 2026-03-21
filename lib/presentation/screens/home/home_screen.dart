import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/history_provider.dart';
import '../../widgets/common/app_logo.dart';
import '../../widgets/common/focusable_widget.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _TopBar(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical:   AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main nav tiles
                  _MainTiles(),
                  const SizedBox(height: AppSpacing.xl3),
                  // Continue Watching
                  _ContinueWatchingRow(),
                  const SizedBox(height: AppSpacing.xl3),
                  // Favourites quick row
                  _FavouritesRow(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.borderSubtle, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          const IzoLogo(size: 30),
          const SizedBox(width: AppSpacing.md),
          const Text(
            'IZO IPTV',
            style: TextStyle(
              color:         AppColors.accentPrimary,
              fontSize:      13,
              fontWeight:    FontWeight.w600,
              letterSpacing: 2.0,
            ),
          ),
          const Spacer(),
          FocusableWidget(
            onTap: () => context.push('/settings'),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: const Icon(
                Icons.settings_outlined,
                color: AppColors.textSecondary,
                size:  AppSpacing.iconMd,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MainTiles extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tiles = [
      _TileData(icon: Icons.live_tv_outlined,   label: 'Live TV',  route: '/live'),
      _TileData(icon: Icons.movie_outlined,      label: 'Movies',   route: '/movies'),
      _TileData(icon: Icons.video_library_outlined, label: 'Series', route: '/series'),
    ];

    return Row(
      children: tiles.asMap().entries.map((e) {
        final t = e.value;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: FocusableWidget(
              autofocus:    e.key == 0,
              borderRadius: AppSpacing.radiusCard,
              onTap: () => context.push(t.route),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl3),
                decoration: BoxDecoration(
                  color:        AppColors.card,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                  border:       Border.all(color: AppColors.border, width: 0.5),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(t.icon, color: AppColors.accentPrimary, size: AppSpacing.iconLg),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      t.label,
                      style: const TextStyle(
                        color:         AppColors.textPrimary,
                        fontSize:      12,
                        fontWeight:    FontWeight.w400,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _TileData {
  const _TileData({required this.icon, required this.label, required this.route});
  final IconData icon;
  final String   label;
  final String   route;
}

class _ContinueWatchingRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(recentHistoryProvider);

    return history.when(
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'CONTINUE WATCHING',
              style: TextStyle(
                color:          AppColors.textMuted,
                fontSize:       11,
                fontWeight:     FontWeight.w400,
                letterSpacing:  1.2,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount:       items.length,
                itemBuilder:     (_, i) {
                  final item = items[i];
                  final pos  = (item['position_secs'] as int? ?? 0).toDouble();
                  final dur  = (item['duration_secs'] as int? ?? 1).toDouble();
                  final progress = dur > 0 ? (pos / dur).clamp(0.0, 1.0) : 0.0;

                  return Container(
                    width:  140,
                    margin: const EdgeInsets.only(right: AppSpacing.sm),
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color:        AppColors.card,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                      border:       Border.all(color: AppColors.border, width: 0.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment:  MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          item['content_name'] as String? ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color:      AppColors.textPrimary,
                            fontSize:   11,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        LinearProgressIndicator(
                          value:            progress,
                          backgroundColor:  AppColors.accentSoft,
                          valueColor:       const AlwaysStoppedAnimation(AppColors.textPrimary),
                          minHeight:        1,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error:   (_, __) => const SizedBox.shrink(),
    );
  }
}

class _FavouritesRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'FAVOURITES',
              style: TextStyle(
                color:         AppColors.textMuted,
                fontSize:      11,
                fontWeight:    FontWeight.w400,
                letterSpacing: 1.2,
              ),
            ),
            GestureDetector(
              onTap: () => context.push('/favourites'),
              child: const Text(
                'See all',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
