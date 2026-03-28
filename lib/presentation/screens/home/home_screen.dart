import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/vod.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/history_provider.dart';
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
  final _heroScope     = FocusScopeNode();
  final _continueScope = FocusScopeNode();
  final _settingsNode  = FocusNode();

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
    _continueScope.dispose();
    _settingsNode.dispose();
    super.dispose();
  }

  Future<void> _confirmExit(BuildContext context) async {
    final exit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Exit IZO IPTV?',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
        ),
        actions: [
          FocusableWidget(
            autofocus:    true,
            borderRadius: AppSpacing.radiusCard,
            onTap: () => Navigator.of(ctx).pop(false),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
          ),
          const SizedBox(width: 8),
          FocusableWidget(
            borderRadius: AppSpacing.radiusCard,
            onTap: () => Navigator.of(ctx).pop(true),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('Exit', style: TextStyle(color: const Color(0xFFE57373))),
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
                padding: const EdgeInsets.fromLTRB(
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
                          onDownArrow:  () => _continueScope.requestFocus(),
                          settingsNode: _settingsNode,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl3),
                      FocusScope(
                        node: _continueScope,
                        child: _ContinueWatchingRow(
                          onUpArrow: () => _heroScope.requestFocus(),
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
          border:       Border.all(color: AppColors.error, width: 0.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 16),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: AppColors.error, fontSize: 12),
              ),
            ),
            FocusableWidget(
              onTap: () => setState(() => _dismissed = true),
              child: const Icon(Icons.close, color: AppColors.error, size: 16),
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
            focusNode:    settingsNode,
            onTap:        () => context.push('/settings'),
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
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          text,
          style: TextStyle(
            color:         AppColors.textMuted,
            fontSize:      10,
            fontWeight:    FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
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
  final String      label;
  final String      route;
  final List<Color> gradient;
  final Color       textureColor;
  final String      tag;
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
    _TileData(label: 'Live TV', route: '/live',   gradient: [Color(0xFF0A1628), Color(0xFF080808)], textureColor: Color(0x0800F0FF), tag: 'LIVE'),
    _TileData(label: 'Movies',  route: '/movies',  gradient: [Color(0xFF140A1E), Color(0xFF080808)], textureColor: Color(0x08A855F7), tag: 'VOD'),
    _TileData(label: 'Series',  route: '/series',  gradient: [Color(0xFF0A1420), Color(0xFF080808)], textureColor: Color(0x087DD3FC), tag: 'TV'),
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
        .clamp(200.0, 500.0) * 0.60;

    return Focus(
      skipTraversal: true,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
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
          // Right from last tile → settings gear
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
                left:  e.key == 0                ? 0 : 6,
                right: e.key == _tiles.length - 1 ? 0 : 6,
              ),
              child: FocusableWidget(
                focusNode:    _nodes[e.key],
                autofocus:    e.key == 0,
                borderRadius: AppSpacing.radiusCard,
                onTap:        () => context.push(t.route),
                child: _HeroTile(tile: t, height: tileHeight),
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
            Positioned.fill(
              child: CustomPaint(
                painter: _DiagonalLinePainter(color: tile.textureColor),
              ),
            ),
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
                  style: TextStyle(
                    color:         AppColors.textMuted,
                    fontSize:      8,
                    fontWeight:    FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            Positioned(
              left:   AppSpacing.lg,
              right:  AppSpacing.lg,
              bottom: AppSpacing.lg,
              child: Text(
                tile.label,
                style: TextStyle(
                  color:         AppColors.textPrimary,
                  fontSize:      22,
                  fontWeight:    FontWeight.w500,
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
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_DiagonalLinePainter old) => old.color != color;
}

// ── Continue Watching ──────────────────────────────────────────────────────────

class _ContinueWatchingRow extends ConsumerStatefulWidget {
  const _ContinueWatchingRow({this.onUpArrow, this.onDownArrow});
  final VoidCallback? onUpArrow;
  final VoidCallback? onDownArrow;

  @override
  ConsumerState<_ContinueWatchingRow> createState() => _ContinueWatchingRowState();
}

class _ContinueWatchingRowState extends ConsumerState<_ContinueWatchingRow> {
  List<FocusNode>        _nodes      = [];
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void dispose() {
    for (final n in _nodes) n.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _ensureNodes(int count) {
    if (_nodes.length != count) {
      for (final n in _nodes) n.dispose();
      _nodes = List.generate(count, (_) => FocusNode());
    }
  }

  void _move(int to) {
    if (to < 0 || to >= _nodes.length) return;
    _nodes[to].requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureVisible(to));
  }

  void _ensureVisible(int idx) {
    if (!_scrollCtrl.hasClients) return;
    const itemWidth  = 180.0 + AppSpacing.md; // item width + margin
    final itemLeft   = idx * itemWidth;
    final itemRight  = itemLeft + 180.0;
    final viewport   = _scrollCtrl.position.viewportDimension;
    final offset     = _scrollCtrl.offset;
    double? target;
    if (itemLeft < offset) {
      target = itemLeft;
    } else if (itemRight > offset + viewport) {
      target = itemRight - viewport;
    }
    if (target != null) {
      _scrollCtrl.animateTo(
        target.clamp(0.0, _scrollCtrl.position.maxScrollExtent),
        duration: const Duration(milliseconds: 150),
        curve:    Curves.easeOut,
      );
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
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      widget.onUpArrow?.call();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      widget.onDownArrow?.call();
      return KeyEventResult.handled;
    }
    final idx = _focusedIndex;
    if (idx < 0) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _move(idx + 1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft && idx > 0) {
      _move(idx - 1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _resumeItem(Map<String, dynamic> item) async {
    final contentId   = item['content_id']   as int?;
    final contentType = item['content_type'] as String?;
    if (contentId == null || contentType == null) return;

    if (contentType == 'movie') {
      final vod = await ref.read(vodRepositoryProvider).getVodById(contentId);
      if (vod != null && mounted) {
        context.push('/movies/player', extra: {
          'vod':      vod,
          'backPath': '/movies/${vod.id}',
        });
      }
    } else if (contentType == 'episode') {
      final episodeId = item['episode_id'] as int?;
      if (episodeId == null) return;
      final episode = await ref.read(seriesRepositoryProvider).getEpisodeById(episodeId);
      if (episode != null && mounted) {
        context.push('/series/player', extra: {
          'vod': VodItem(
            id:           episode.id,
            name:         episode.title,
            streamUrl:    episode.streamUrl,
            categoryId:   0,
            posterUrl:    episode.thumbnailUrl,
            durationSecs: episode.durationSecs,
          ),
          'backPath':     '/series/${episode.seriesId}',
          'episodes':     [episode],
          'episodeIndex': 0,
        });
      }
    } else if (contentType == 'live') {
      // Live TV resume — navigate back to live player with saved channel if available
      context.push('/live');
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(recentHistoryProvider);
    return history.when(
      data: (items) {
        if (items.isEmpty) {
          return Focus(
            onKeyEvent: (_, event) {
              if (event is! KeyDownEvent) return KeyEventResult.ignored;
              if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                widget.onUpArrow?.call();
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                widget.onDownArrow?.call();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: const SizedBox.shrink(),
          );
        }
        _ensureNodes(items.length);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionLabel('CONTINUE WATCHING'),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 96,
              child: Focus(
                onKeyEvent:    _handleKey,
                skipTraversal: true,
                child: ListView.builder(
                  controller:      _scrollCtrl,
                  scrollDirection: Axis.horizontal,
                  itemCount:       items.length,
                  itemBuilder:     (_, i) {
                    final item     = items[i];
                    final pos      = (item['position_secs'] as int? ?? 0).toDouble();
                    final dur      = (item['duration_secs'] as int? ?? 1).toDouble();
                    final progress = dur > 0 ? (pos / dur).clamp(0.0, 1.0) : 0.0;
                    return FocusableWidget(
                      focusNode:    _nodes[i],
                      autofocus:    i == 0,
                      borderRadius: AppSpacing.radiusCard,
                      onTap:        () => _resumeItem(item),
                      child: Container(
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
                                style: TextStyle(
                                  color:      AppColors.textPrimary,
                                  fontSize:   12,
                                  fontWeight: FontWeight.w400,
                                  height:     1.4,
                                ),
                              ),
                            ),
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
                      ),
                    );
                  },
                ),
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

