import 'dart:math' as math;
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
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl2, AppSpacing.xl2, AppSpacing.xl2, AppSpacing.xl3,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MainTiles(),
                  const SizedBox(height: AppSpacing.xl3),
                  _ContinueWatchingRow(),
                  const SizedBox(height: AppSpacing.xl3),
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

// ── Top Bar ────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end:   Alignment.bottomCenter,
          colors: [Color(0xFF07070F), AppColors.background],
        ),
        border: Border(
          bottom: BorderSide(color: AppColors.borderSubtle, width: 0.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl2),
      child: Row(
        children: [
          const IzoLogo(size: 32),
          const SizedBox(width: AppSpacing.md),
          Column(
            mainAxisAlignment:  MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'IZO IPTV',
                style: TextStyle(
                  color:         AppColors.accentPrimary,
                  fontSize:      14,
                  fontWeight:    FontWeight.w700,
                  letterSpacing: 3.5,
                ),
              ),
              Text(
                'PREMIUM STREAMING',
                style: TextStyle(
                  color:         AppColors.textMuted,
                  fontSize:      7,
                  fontWeight:    FontWeight.w400,
                  letterSpacing: 2.5,
                ),
              ),
            ],
          ),
          const Spacer(),
          FocusableWidget(
            onTap:        () => context.push('/settings'),
            borderRadius: AppSpacing.radiusCard,
            child: Container(
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

// ── Section Header ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, this.action, this.onAction});
  final String        label;
  final String?       action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 2,
          height: 13,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(1),
            gradient: const LinearGradient(
              begin:  Alignment.topCenter,
              end:    Alignment.bottomCenter,
              colors: [AppColors.accentPrimary, AppColors.accentPurple],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label,
          style: const TextStyle(
            color:         AppColors.textMuted,
            fontSize:      10,
            fontWeight:    FontWeight.w500,
            letterSpacing: 2.0,
          ),
        ),
        if (action != null) ...[
          const Spacer(),
          GestureDetector(
            onTap: onAction,
            child: Text(
              action!,
              style: const TextStyle(
                color:         AppColors.textSecondary,
                fontSize:      10,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Main Tiles ─────────────────────────────────────────────────────────────────

class _TileData {
  const _TileData({
    required this.icon,
    required this.label,
    required this.route,
    required this.accent,
    required this.subtitle,
  });
  final IconData icon;
  final String   label;
  final String   route;
  final Color    accent;
  final String   subtitle;
}

class _MainTiles extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tiles = const [
      _TileData(
        icon:     Icons.live_tv_outlined,
        label:    'Live TV',
        route:    '/live',
        accent:   AppColors.accentPrimary,
        subtitle: 'LIVE CHANNELS',
      ),
      _TileData(
        icon:     Icons.movie_creation_outlined,
        label:    'Movies',
        route:    '/movies',
        accent:   AppColors.accentPurple,
        subtitle: 'VOD LIBRARY',
      ),
      _TileData(
        icon:     Icons.video_library_outlined,
        label:    'Series',
        route:    '/series',
        accent:   Color(0xFF7DD3FC),
        subtitle: 'TV SHOWS',
      ),
    ];

    return Row(
      children: tiles.asMap().entries.map((e) {
        final t = e.value;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left:  e.key == 0               ? 0 : AppSpacing.sm,
              right: e.key == tiles.length - 1 ? 0 : AppSpacing.sm,
            ),
            child: FocusableWidget(
              autofocus:    e.key == 0,
              borderRadius: AppSpacing.radiusCard,
              onTap:        () => context.push(t.route),
              child: _NavTile(tile: t),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.tile});
  final _TileData tile;

  @override
  Widget build(BuildContext context) {
    final accentBg     = tile.accent.withOpacity(0.07);
    final accentBorder = tile.accent.withOpacity(0.18);
    final accentCorner = tile.accent.withOpacity(0.45);
    final accentIcon   = tile.accent.withOpacity(0.12);
    final accentIconBorder = tile.accent.withOpacity(0.25);
    final accentSub    = tile.accent.withOpacity(0.55);

    return Container(
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border:       Border.all(color: accentBorder, width: 0.5),
        gradient: LinearGradient(
          begin:  Alignment.topLeft,
          end:    Alignment.bottomRight,
          colors: [accentBg, AppColors.card, AppColors.card],
          stops:  const [0.0, 0.45, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Top accent line (gradient fade in/out)
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppSpacing.radiusCard),
                ),
                gradient: LinearGradient(
                  colors: [
                    tile.accent.withOpacity(0),
                    tile.accent,
                    tile.accent.withOpacity(0),
                  ],
                ),
              ),
            ),
          ),
          // Corner brackets
          Positioned(top: 10, left: 10,
            child: _CornerBracket(color: accentCorner)),
          Positioned(top: 10, right: 10,
            child: Transform.rotate(angle: math.pi / 2,
              child: _CornerBracket(color: accentCorner))),
          Positioned(bottom: 10, left: 10,
            child: Transform.rotate(angle: -math.pi / 2,
              child: _CornerBracket(color: accentCorner))),
          Positioned(bottom: 10, right: 10,
            child: Transform.rotate(angle: math.pi,
              child: _CornerBracket(color: accentCorner))),
          // Content
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width:  58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape:  BoxShape.circle,
                    color:  accentIcon,
                    border: Border.all(color: accentIconBorder, width: 0.5),
                  ),
                  child: Icon(tile.icon, color: tile.accent, size: 26),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  tile.label.toUpperCase(),
                  style: const TextStyle(
                    color:         AppColors.textPrimary,
                    fontSize:      13,
                    fontWeight:    FontWeight.w600,
                    letterSpacing: 2.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  tile.subtitle,
                  style: TextStyle(
                    color:         accentSub,
                    fontSize:      8,
                    fontWeight:    FontWeight.w400,
                    letterSpacing: 1.8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// L-shaped corner bracket drawn with CustomPainter
class _CornerBracket extends StatelessWidget {
  const _CornerBracket({required this.color, this.size = 14});
  final Color  color;
  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size(size, size), painter: _CornerPainter(color: color));
}

class _CornerPainter extends CustomPainter {
  const _CornerPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color       = color
      ..strokeWidth = 1.5
      ..style       = PaintingStyle.stroke
      ..strokeCap   = StrokeCap.square;
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height)
        ..lineTo(0, 0)
        ..lineTo(size.width, 0),
      paint,
    );
  }

  @override
  bool shouldRepaint(_CornerPainter old) => old.color != color;
}

// ── Continue Watching ──────────────────────────────────────────────────────────

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
            const _SectionHeader(label: 'CONTINUE WATCHING'),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 90,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount:       items.length,
                itemBuilder:     (_, i) {
                  final item     = items[i];
                  final pos      = (item['position_secs']  as int? ?? 0).toDouble();
                  final dur      = (item['duration_secs']  as int? ?? 1).toDouble();
                  final progress = dur > 0 ? (pos / dur).clamp(0.0, 1.0) : 0.0;
                  final pct      = '${(progress * 100).toInt()}%';

                  return Container(
                    width:  176,
                    margin: const EdgeInsets.only(right: AppSpacing.md),
                    decoration: BoxDecoration(
                      color:        AppColors.card,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                      border:       Border.all(color: AppColors.border, width: 0.5),
                    ),
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md, AppSpacing.md, AppSpacing.md, 28,
                          ),
                          child: Text(
                            item['content_name'] as String? ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color:      AppColors.textPrimary,
                              fontSize:   12,
                              fontWeight: FontWeight.w400,
                              height:     1.4,
                            ),
                          ),
                        ),
                        // Progress section
                        Positioned(
                          left: 0, right: 0, bottom: 0,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(right: AppSpacing.md),
                                child: Text(
                                  pct,
                                  style: const TextStyle(
                                    color:    AppColors.textMuted,
                                    fontSize: 8,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  bottom: Radius.circular(AppSpacing.radiusCard),
                                ),
                                child: LinearProgressIndicator(
                                  value:           progress,
                                  backgroundColor: AppColors.accentSoft,
                                  valueColor:      const AlwaysStoppedAnimation(AppColors.accentPrimary),
                                  minHeight:       2,
                                ),
                              ),
                            ],
                          ),
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

// ── Favourites Row ─────────────────────────────────────────────────────────────

class _FavouritesRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _SectionHeader(
      label:    'FAVOURITES',
      action:   'See all',
      onAction: () => context.push('/favourites'),
    );
  }
}
