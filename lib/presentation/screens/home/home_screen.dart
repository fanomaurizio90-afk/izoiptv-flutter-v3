import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/history_provider.dart';
import '../../providers/providers.dart';
import '../../widgets/common/app_logo.dart';
import '../../widgets/common/focusable_widget.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(syncServiceProvider).syncIfNeeded();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TopBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.tvH, AppSpacing.lg, AppSpacing.tvH, AppSpacing.xl3,
                ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HeroTiles(),
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
      ),
    );
  }
}

// ── Top Bar ────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.tvH),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.borderSubtle, width: 0.5)),
      ),
      child: Row(
        children: [
          const IzoLogo(size: 28),
          const Spacer(),
          FocusableWidget(
            onTap: () => context.push('/settings'),
            borderRadius: AppSpacing.radiusCard,
            child: const Padding(
              padding: EdgeInsets.all(AppSpacing.sm),
              child: Icon(Icons.settings_outlined, color: AppColors.textMuted, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section Label ──────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {this.trailing, this.onTrailingTap});
  final String        text;
  final String?       trailing;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          text,
          style: GoogleFonts.dmSans(
            color:         AppColors.textMuted,
            fontSize:      10,
            fontWeight:    FontWeight.w500,
            letterSpacing: 1.5,
          ),
        ),
        if (trailing != null) ...[
          const Spacer(),
          GestureDetector(
            onTap: onTrailingTap,
            child: Text(
              trailing!,
              style: GoogleFonts.dmSans(color: AppColors.textMuted, fontSize: 11),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Hero Tiles ─────────────────────────────────────────────────────────────────

class _TileData {
  const _TileData({
    required this.label,
    required this.route,
    required this.gradient,
    required this.textureColor,
    required this.tag,
  });
  final String          label;
  final String          route;
  final List<Color>     gradient;
  final Color           textureColor;
  final String          tag;
}

class _HeroTiles extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Compute available height for tiles
    final screenH   = MediaQuery.of(context).size.height;
    final tileHeight = (screenH - 56 - 32).clamp(200.0, 500.0) * 0.60;

    final tiles = const [
      _TileData(
        label:       'Live TV',
        route:       '/live',
        gradient:    [Color(0xFF0A1628), Color(0xFF080808)],
        textureColor: Color(0x0800F0FF),
        tag:         'LIVE',
      ),
      _TileData(
        label:       'Movies',
        route:       '/movies',
        gradient:    [Color(0xFF140A1E), Color(0xFF080808)],
        textureColor: Color(0x08A855F7),
        tag:         'VOD',
      ),
      _TileData(
        label:       'Series',
        route:       '/series',
        gradient:    [Color(0xFF0A1420), Color(0xFF080808)],
        textureColor: Color(0x087DD3FC),
        tag:         'TV',
      ),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: tiles.asMap().entries.map((e) {
        final t = e.value;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left:  e.key == 0               ? 0 : 6,
              right: e.key == tiles.length - 1 ? 0 : 6,
            ),
            child: FocusableWidget(
              autofocus:    e.key == 0,
              borderRadius: AppSpacing.radiusCard,
              onTap:        () => context.push(t.route),
              child: _HeroTile(tile: t, height: tileHeight),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _HeroTile extends StatelessWidget {
  const _HeroTile({required this.tile, required this.height});
  final _TileData tile;
  final double    height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin:  Alignment.topRight,
            end:    Alignment.bottomLeft,
            colors: tile.gradient,
          ),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Stack(
          children: [
            // Subtle diagonal line texture
            Positioned.fill(
              child: CustomPaint(
                painter: _DiagonalLinePainter(color: tile.textureColor),
              ),
            ),
            // Tag — top right
            Positioned(
              top: AppSpacing.md,
              right: AppSpacing.md,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color:        AppColors.borderSubtle,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  tile.tag,
                  style: GoogleFonts.dmSans(
                    color:         AppColors.textMuted,
                    fontSize:      8,
                    fontWeight:    FontWeight.w500,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
            // Label — bottom left
            Positioned(
              left:   AppSpacing.lg,
              right:  AppSpacing.lg,
              bottom: AppSpacing.lg,
              child: Text(
                tile.label,
                style: GoogleFonts.dmSans(
                  color:      AppColors.textPrimary,
                  fontSize:   22,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.3,
                  height: 1.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiagonalLinePainter extends CustomPainter {
  const _DiagonalLinePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color       = color
      ..strokeWidth = 1;
    const spacing = 24.0;
    for (double x = -size.height; x < size.width + size.height; x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DiagonalLinePainter old) => old.color != old.color;
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
            const _SectionLabel('CONTINUE WATCHING'),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 96,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount:       items.length,
                itemBuilder:     (_, i) {
                  final item     = items[i];
                  final pos      = (item['position_secs']  as int? ?? 0).toDouble();
                  final dur      = (item['duration_secs']  as int? ?? 1).toDouble();
                  final progress = dur > 0 ? (pos / dur).clamp(0.0, 1.0) : 0.0;
                  return Container(
                    width:  180,
                    margin: const EdgeInsets.only(right: AppSpacing.md),
                    decoration: BoxDecoration(
                      color:        AppColors.card,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                      border:       Border.all(color: AppColors.border, width: 0.5),
                    ),
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                          child: Text(
                            item['content_name'] as String? ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(
                              color:      AppColors.textPrimary,
                              fontSize:   12,
                              fontWeight: FontWeight.w400,
                              height:     1.4,
                            ),
                          ),
                        ),
                        // Progress bar at very bottom
                        Positioned(
                          left: 0, right: 0, bottom: 0,
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(AppSpacing.radiusCard),
                            ),
                            child: LinearProgressIndicator(
                              value:           progress,
                              backgroundColor: AppColors.borderSubtle,
                              valueColor:      const AlwaysStoppedAnimation(AppColors.textPrimary),
                              minHeight:       2,
                            ),
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
    return _SectionLabel(
      'FAVOURITES',
      trailing:      'See all',
      onTrailingTap: () => context.push('/favourites'),
    );
  }
}
