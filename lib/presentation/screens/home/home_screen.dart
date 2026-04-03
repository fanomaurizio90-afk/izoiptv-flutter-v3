import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/providers.dart';
import '../../widgets/common/app_logo.dart';
import '../../widgets/common/focusable_widget.dart';
import '../../widgets/common/staggered_list.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _heroScope    = FocusScopeNode();
  final _settingsNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(syncProvider.notifier).syncIfNeeded();
    });
  }

  @override
  void dispose() {
    _heroScope.dispose();
    _settingsNode.dispose();
    super.dispose();
  }

  Future<void> _confirmExit(BuildContext context) async {
    final exit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          side: const BorderSide(color: AppColors.border, width: 0.5),
        ),
        title: const Text(
          'Exit IZO IPTV?',
          style: TextStyle(
            color:         AppColors.textPrimary,
            fontWeight:    FontWeight.w400,
            fontSize:      15,
            letterSpacing: -0.3,
          ),
        ),
        content: const Text(
          'Are you sure you want to close the app?',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.55),
        ),
        actionsAlignment: MainAxisAlignment.end,
        actions: [
          FocusableWidget(
            autofocus:    true,
            borderRadius: AppSpacing.radiusCard,
            onTap: () => Navigator.of(ctx).pop(false),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ),
          ),
          const SizedBox(width: 4),
          FocusableWidget(
            borderRadius: AppSpacing.radiusCard,
            onTap: () => Navigator.of(ctx).pop(true),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text('Exit',
                style: TextStyle(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.w500)),
            ),
          ),
        ],
      ),
    );
    if (exit == true) SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit(context);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _TopBar(settingsNode: _settingsNode),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.tvH, AppSpacing.lg, AppSpacing.tvH, AppSpacing.xl3,
                  ),
                  children: [
                    StaggeredList(
                      children: [
                        _ExpiryBanner(),
                        FocusScope(
                          node: _heroScope,
                          child: _HeroTiles(
                            onUpArrow:    () => _settingsNode.requestFocus(),
                            settingsNode: _settingsNode,
                          ),
                        ),
                      ],
                    ),
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

// ── Expiry Banner ──────────────────────────────────────────────────────────────

class _ExpiryBanner extends ConsumerStatefulWidget {
  @override
  ConsumerState<_ExpiryBanner> createState() => _ExpiryBannerState();
}

class _ExpiryBannerState extends ConsumerState<_ExpiryBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    final auth = ref.watch(authProvider);
    if (auth is! AuthAuthenticated) return const SizedBox.shrink();

    final days = AuthNotifier.daysUntilExpiry(auth.user.expiryDate);
    if (days == null || days > 7) return const SizedBox.shrink();

    final label = days <= 0
        ? 'Your subscription expires today'
        : 'Your subscription expires in $days day${days == 1 ? '' : 's'}';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical:   AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color:        AppColors.errorSurface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          border:       Border.all(color: AppColors.error.withOpacity(0.25), width: 0.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 14),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color:      AppColors.error,
                  fontSize:   12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            FocusableWidget(
              borderRadius: 4,
              onTap: () => setState(() => _dismissed = true),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close_rounded, color: AppColors.error, size: 14),
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
  const _TopBar({required this.settingsNode});
  final FocusNode settingsNode;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppConstants.homeTopBarHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.tvH),
        child: Row(
          children: [
            const IzoLogo(size: 26),
            const Spacer(),
            FocusableWidget(
              focusNode:    settingsNode,
              onTap:        () => context.push('/settings'),
              borderRadius: 8,
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color:        AppColors.card,
                  borderRadius: BorderRadius.circular(8),
                  border:       Border.all(color: AppColors.border, width: 0.5),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  color: AppColors.textMuted,
                  size:  17,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Hero Tiles ─────────────────────────────────────────────────────────────────

class _TileData {
  const _TileData({
    required this.label,
    required this.sublabel,
    required this.route,
    required this.gradientColors,
    required this.glowColor,
  });
  final String      label;
  final String      sublabel;
  final String      route;
  final List<Color> gradientColors;
  final Color       glowColor;
}

class _HeroTiles extends StatefulWidget {
  const _HeroTiles({this.onUpArrow, this.onDownArrow, this.settingsNode});
  final VoidCallback? onUpArrow;
  final VoidCallback? onDownArrow;
  final FocusNode?    settingsNode;

  @override
  State<_HeroTiles> createState() => _HeroTilesState();
}

class _HeroTilesState extends State<_HeroTiles> {
  static const _tiles = [
    _TileData(
      label:    'Live TV',
      sublabel: 'Live channels',
      route:    '/live',
      gradientColors: [Color(0xFF0B2118), Color(0xFF070709)],
      glowColor:      Color(0x223DD68C),
    ),
    _TileData(
      label:    'Movies',
      sublabel: 'On demand',
      route:    '/movies',
      gradientColors: [Color(0xFF201108), Color(0xFF070709)],
      glowColor:      Color(0x22C8A058),
    ),
    _TileData(
      label:    'Series',
      sublabel: 'TV shows',
      route:    '/series',
      gradientColors: [Color(0xFF0A1322), Color(0xFF070709)],
      glowColor:      Color(0x226FA3DC),
    ),
  ];

  final List<FocusNode> _nodes = List.generate(_tiles.length, (_) => FocusNode());

  @override
  void dispose() {
    for (final n in _nodes) n.dispose();
    super.dispose();
  }

  int get _focusedIndex {
    for (int i = 0; i < _nodes.length; i++) {
      if (_nodes[i].hasFocus) return i;
    }
    return -1;
  }

  @override
  Widget build(BuildContext context) {
    final screenH    = MediaQuery.of(context).size.height;
    final tileHeight = (screenH - AppConstants.homeTopBarHeight - AppConstants.homeSafeAreaPadding)
        .clamp(200.0, 560.0) * 0.62;

    return Focus(
      skipTraversal: true,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          widget.onUpArrow?.call();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          widget.onDownArrow?.call();
          return KeyEventResult.handled;
        }
        final idx = _focusedIndex;
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          if (idx >= 0 && idx < _tiles.length - 1) {
            _nodes[idx + 1].requestFocus();
            return KeyEventResult.handled;
          }
          if (idx == _tiles.length - 1) {
            widget.settingsNode?.requestFocus();
            return KeyEventResult.handled;
          }
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          if (idx > 0) {
            _nodes[idx - 1].requestFocus();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _tiles.asMap().entries.map((e) {
          final t = e.value;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left:  e.key == 0                 ? 0 : 5,
                right: e.key == _tiles.length - 1 ? 0 : 5,
              ),
              child: FocusableWidget(
                focusNode:    _nodes[e.key],
                autofocus:    e.key == 0,
                borderRadius: AppSpacing.radiusCard,
                onTap:        () => context.push(t.route),
                child:        _HeroTile(tile: t, height: tileHeight),
              ),
            ),
          );
        }).toList(),
      ),
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
        color:  tile.gradientColors[0],
        child: Stack(
          children: [
            // ── Base gradient — deep to void ──────────────────────────────
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin:  Alignment.topLeft,
                    end:    Alignment.bottomRight,
                    stops:  const [0.0, 1.0],
                    colors: tile.gradientColors,
                  ),
                ),
              ),
            ),

            // ── Radial glow from top corner ────────────────────────────────
            Positioned(
              top:   -height * 0.2,
              right: -height * 0.2,
              child: Container(
                width:  height * 1.0,
                height: height * 1.0,
                decoration: BoxDecoration(
                  shape:  BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [tile.glowColor, Colors.transparent],
                    stops:  const [0.0, 1.0],
                  ),
                ),
              ),
            ),

            // ── Subtle dot grid ────────────────────────────────────────────
            Positioned.fill(
              child: CustomPaint(
                painter: _DotGridPainter(color: const Color(0x06FFFFFF)),
              ),
            ),

            // ── Bottom scrim ───────────────────────────────────────────────
            Positioned(
              left: 0, right: 0, bottom: 0,
              height: height * 0.65,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin:  Alignment.topCenter,
                    end:    Alignment.bottomCenter,
                    stops:  const [0.0, 0.7, 1.0],
                    colors: [
                      Colors.transparent,
                      tile.gradientColors[0].withOpacity(0.85),
                      tile.gradientColors[0].withOpacity(0.98),
                    ],
                  ),
                ),
              ),
            ),

            // ── Label block (bottom) ──────────────────────────────────────
            Positioned(
              left:   AppSpacing.xl,
              right:  AppSpacing.xl,
              bottom: AppSpacing.xl2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize:       MainAxisSize.min,
                children: [
                  // Gold accent bar
                  Container(
                    width:  20,
                    height: 2,
                    decoration: BoxDecoration(
                      color:        AppColors.accentPrimary,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  const SizedBox(height: 7),
                  // Sublabel
                  Text(
                    tile.sublabel.toUpperCase(),
                    style: const TextStyle(
                      color:         AppColors.accentPrimary,
                      fontSize:      9,
                      fontWeight:    FontWeight.w600,
                      letterSpacing: 1.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Main title
                  Text(
                    tile.label,
                    style: const TextStyle(
                      color:         AppColors.textPrimary,
                      fontSize:      32,
                      fontWeight:    FontWeight.w200,
                      letterSpacing: -1.0,
                      height:        1.0,
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

// ── Dot grid painter ───────────────────────────────────────────────────────────

class _DotGridPainter extends CustomPainter {
  const _DotGridPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    const spacing = 24.0;
    const radius  = 0.8;
    for (double x = spacing; x < size.width; x += spacing) {
      for (double y = spacing; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter old) => old.color != color;
}
