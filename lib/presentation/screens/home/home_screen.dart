import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/providers.dart';
import '../../widgets/common/app_logo.dart';
import '../../widgets/common/focusable_widget.dart';

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
      barrierColor: const Color(0xCC050507),
      builder: (ctx) => Center(
        child: Container(
          width: 340,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color:        AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
            border:       Border.all(color: AppColors.glassBorder, width: 0.5),
            boxShadow: [
              BoxShadow(
                color:      const Color(0x40000000),
                blurRadius: 48,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Exit IZO IPTV?',
                style: TextStyle(
                  color:         AppColors.textPrimary,
                  fontWeight:    FontWeight.w400,
                  fontSize:      16,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Are you sure you want to close the app?',
                style: TextStyle(
                  color:    AppColors.textSecondary,
                  fontSize: 13,
                  height:   1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FocusableWidget(
                    autofocus:    true,
                    borderRadius: 8,
                    onTap: () => Navigator.of(ctx).pop(false),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Text('Cancel',
                        style: TextStyle(
                          color:    AppColors.textSecondary,
                          fontSize: 13,
                        )),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FocusableWidget(
                    borderRadius: 8,
                    onTap: () => Navigator.of(ctx).pop(true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color:        AppColors.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Exit',
                        style: TextStyle(
                          color:      AppColors.error,
                          fontSize:   13,
                          fontWeight: FontWeight.w500,
                        )),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.tvH, 0, AppSpacing.tvH, AppSpacing.xl2,
            ),
            child: Column(
              children: [
                _TopBar(settingsNode: _settingsNode),
                _ExpiryBanner(),
                const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: FocusScope(
                    node: _heroScope,
                    child: _HeroTiles(
                      onUpArrow:    () => _settingsNode.requestFocus(),
                      settingsNode: _settingsNode,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Expiry Banner
// ─────────────────────────────────────────────────────────────────────────────

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
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical:   AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color:        AppColors.errorSurface,
          borderRadius: BorderRadius.circular(8),
          border:       Border.all(
            color: AppColors.error.withValues(alpha: 0.15),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded,
                color: AppColors.error.withValues(alpha: 0.7), size: 14),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(label,
                style: TextStyle(
                  color:      AppColors.error.withValues(alpha: 0.85),
                  fontSize:   12,
                  fontWeight: FontWeight.w400,
                )),
            ),
            FocusableWidget(
              borderRadius: 4,
              onTap: () => setState(() => _dismissed = true),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.close_rounded,
                    color: AppColors.error.withValues(alpha: 0.5), size: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top Bar
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.settingsNode});
  final FocusNode settingsNode;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Row(
        children: [
          const IzoLogo(size: 24),
          const Spacer(),
          FocusableWidget(
            focusNode:    settingsNode,
            onTap:        () => context.push('/settings'),
            borderRadius: 10,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color:        AppColors.card,
                borderRadius: BorderRadius.circular(10),
                border:       Border.all(color: AppColors.glassBorder, width: 0.5),
              ),
              child: const Icon(
                Icons.tune_rounded,
                color: AppColors.textMuted,
                size:  16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero Tiles
// ─────────────────────────────────────────────────────────────────────────────

class _TileData {
  const _TileData({
    required this.label,
    required this.sublabel,
    required this.route,
    required this.baseColor,
    required this.glowColor,
    required this.icon,
  });
  final String   label;
  final String   sublabel;
  final String   route;
  final Color    baseColor;
  final Color    glowColor;
  final IconData icon;
}

class _HeroTiles extends StatefulWidget {
  const _HeroTiles({this.onUpArrow, this.onDownArrow, this.settingsNode});
  final VoidCallback? onUpArrow;
  final VoidCallback? onDownArrow;
  final FocusNode?    settingsNode;

  @override
  State<_HeroTiles> createState() => _HeroTilesState();
}

class _HeroTilesState extends State<_HeroTiles>
    with SingleTickerProviderStateMixin {

  static const _tiles = [
    _TileData(
      label:     'Live TV',
      sublabel:  'Live channels',
      route:     '/live',
      baseColor: Color(0xFF071A14),
      glowColor: Color(0xFF3DD68C),
      icon:      Icons.sensors_rounded,
    ),
    _TileData(
      label:     'Movies',
      sublabel:  'On demand',
      route:     '/movies',
      baseColor: Color(0xFF1A0E04),
      glowColor: Color(0xFFD4A76A),
      icon:      Icons.movie_creation_outlined,
    ),
    _TileData(
      label:     'Series',
      sublabel:  'TV shows',
      route:     '/series',
      baseColor: Color(0xFF070E1A),
      glowColor: Color(0xFF6B8FC9),
      icon:      Icons.auto_stories_outlined,
    ),
  ];

  final List<FocusNode> _nodes = List.generate(_tiles.length, (_) => FocusNode());
  late AnimationController _staggerCtrl;

  @override
  void initState() {
    super.initState();
    _staggerCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    for (final n in _nodes) n.dispose();
    _staggerCtrl.dispose();
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
    return Focus(
      skipTraversal: true,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
          return KeyEventResult.ignored;
        }
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _tiles.asMap().entries.map((e) {
          final i = e.key;
          final t = e.value;

          final beginFraction = (i * 0.12).clamp(0.0, 0.7);
          final endFraction   = (beginFraction + 0.55).clamp(0.0, 1.0);
          final itemAnim = CurvedAnimation(
            parent: _staggerCtrl,
            curve:  Interval(beginFraction, endFraction, curve: AppCurves.easeOut),
          );

          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left:  i == 0                 ? 0 : 5,
                right: i == _tiles.length - 1 ? 0 : 5,
              ),
              child: FadeTransition(
                opacity: itemAnim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.04),
                    end:   Offset.zero,
                  ).animate(itemAnim),
                  child: FocusableWidget(
                    focusNode:    _nodes[i],
                    autofocus:    i == 0,
                    borderRadius: AppSpacing.radiusCard,
                    onTap:        () => context.push(t.route),
                    child:        _HeroTile(tile: t),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single Hero Tile
// ─────────────────────────────────────────────────────────────────────────────

class _HeroTile extends StatelessWidget {
  const _HeroTile({required this.tile});
  final _TileData tile;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      child: Container(
        color: tile.baseColor,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Layer 1 — base gradient wash
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin:  Alignment.topLeft,
                    end:    Alignment.bottomRight,
                    stops:  const [0.0, 0.6, 1.0],
                    colors: [
                      tile.baseColor,
                      Color.lerp(tile.baseColor, AppColors.background, 0.5)!,
                      AppColors.background,
                    ],
                  ),
                ),
              ),
            ),

            // Layer 2 — primary ambient glow (top-right)
            Positioned(
              top:   -80,
              right: -60,
              child: Container(
                width:  320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      tile.glowColor.withValues(alpha: 0.10),
                      tile.glowColor.withValues(alpha: 0.03),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.4, 1.0],
                  ),
                ),
              ),
            ),

            // Layer 3 — secondary ambient glow (bottom-center, for depth)
            Positioned(
              bottom: -40,
              left:   20,
              child: Container(
                width:  200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      tile.glowColor.withValues(alpha: 0.04),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Layer 4 — large watermark icon
            Positioned(
              right:  -12,
              top:    -12,
              child: Icon(
                tile.icon,
                size:  140,
                color: tile.glowColor.withValues(alpha: 0.04),
              ),
            ),

            // Layer 5 — glass highlight (top edge refraction)
            Positioned(
              top: 0, left: 0, right: 0,
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.0),
                      Colors.white.withValues(alpha: 0.05),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),

            // Layer 6 — bottom scrim for text readability
            Positioned(
              left: 0, right: 0, bottom: 0,
              height: 180,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin:  Alignment.topCenter,
                    end:    Alignment.bottomCenter,
                    stops:  const [0.0, 0.5, 1.0],
                    colors: [
                      Colors.transparent,
                      AppColors.background.withValues(alpha: 0.6),
                      AppColors.background.withValues(alpha: 0.92),
                    ],
                  ),
                ),
              ),
            ),

            // Layer 7 — label block
            Positioned(
              left:   AppSpacing.xl2,
              right:  AppSpacing.xl2,
              bottom: AppSpacing.xl3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize:       MainAxisSize.min,
                children: [
                  Container(
                    width:  16,
                    height: 1.5,
                    decoration: BoxDecoration(
                      color:        AppColors.accentPrimary.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    tile.sublabel.toUpperCase(),
                    style: TextStyle(
                      color:         AppColors.accentPrimary.withValues(alpha: 0.6),
                      fontSize:      9,
                      fontWeight:    FontWeight.w600,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tile.label,
                    style: const TextStyle(
                      color:         AppColors.textPrimary,
                      fontSize:      36,
                      fontWeight:    FontWeight.w200,
                      letterSpacing: -1.5,
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
