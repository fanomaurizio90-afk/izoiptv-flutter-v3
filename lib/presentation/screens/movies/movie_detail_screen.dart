import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/vod.dart';
import '../../providers/providers.dart';
import '../../widgets/common/focusable_widget.dart';
import '../../widgets/common/skeleton_widget.dart';

// ── Provider ─────────────────────────────────────────────────────────────────

final _vodDetailProvider = FutureProvider.family<VodItem?, int>((ref, id) async {
  return ref.read(vodRepositoryProvider).getVodById(id);
});

// ── Screen ───────────────────────────────────────────────────────────────────

class MovieDetailScreen extends ConsumerStatefulWidget {
  const MovieDetailScreen({super.key, required this.vodId});
  final int vodId;

  @override
  ConsumerState<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends ConsumerState<MovieDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _enrichIfNeeded());
  }

  Future<void> _enrichIfNeeded() async {
    if (!mounted) return;
    final repo = ref.read(vodRepositoryProvider);
    final vod  = await repo.getVodById(widget.vodId);
    if (!mounted || vod == null) return;
    // Enrich if we're missing any metadata (not just poster/plot)
    if (vod.posterUrl != null && vod.plot != null && vod.cast != null) return;
    try {
      await repo.fetchVodInfo(widget.vodId);
      if (mounted) ref.invalidate(_vodDetailProvider(widget.vodId));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final vodAsync = ref.watch(_vodDetailProvider(widget.vodId));
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: vodAsync.when(
          data: (vod) {
            if (vod == null) {
              return Center(child: Text('Movie not found',
                style: TextStyle(color: AppColors.textSecondary)));
            }
            return _MovieDetailBody(
              vod: vod,
              onToggleFavourite: () async {
                final repo = ref.read(vodRepositoryProvider);
                await repo.toggleFavourite(vod.id, !vod.isFavourite);
                ref.invalidate(_vodDetailProvider(widget.vodId));
              },
            );
          },
          loading: () => const SkeletonDetailBackdrop(),
          error:   (e, _) => Center(child: Text(e.toString(),
            style: TextStyle(color: AppColors.error, fontSize: 12))),
        ),
      ),
    );
  }
}

// ── Body ─────────────────────────────────────────────────────────────────────

class _MovieDetailBody extends StatefulWidget {
  const _MovieDetailBody({required this.vod, required this.onToggleFavourite});
  final VodItem vod;
  final VoidCallback onToggleFavourite;

  @override
  State<_MovieDetailBody> createState() => _MovieDetailBodyState();
}

class _MovieDetailBodyState extends State<_MovieDetailBody>
    with SingleTickerProviderStateMixin {
  final _backNode    = FocusNode();
  final _favNode     = FocusNode();
  final _playNode    = FocusNode();
  final _trailerNode = FocusNode();
  late final AnimationController _entranceCtrl;
  late final Animation<double>   _fadeIn;
  late final Animation<Offset>   _slideUp;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700),
    );
    _fadeIn  = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.05), end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic));
    _entranceCtrl.forward();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _backNode.dispose();
    _favNode.dispose();
    _playNode.dispose();
    _trailerNode.dispose();
    super.dispose();
  }

  String get _duration {
    final s = widget.vod.durationSecs;
    if (s == null || s <= 0) return '';
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  Future<void> _openTrailer() async {
    final url = widget.vod.youtubeTrailer;
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url.startsWith('http') ? url : 'https://www.youtube.com/watch?v=$url');
    if (uri != null) {
      try { await launchUrl(uri, mode: LaunchMode.externalApplication); } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final screenW = MediaQuery.of(context).size.width;
    final topPad  = MediaQuery.of(context).padding.top;
    final vod     = widget.vod;
    // Use backdrop if available, fall back to poster
    final heroImage = vod.backdropUrl ?? vod.posterUrl;
    final hasTrailer = vod.youtubeTrailer != null && vod.youtubeTrailer!.isNotEmpty;

    return Stack(
      children: [
        // ── Full-bleed backdrop ────────────────────────────────────────────
        Positioned(
          top: 0, left: 0, right: 0,
          height: screenH * 0.60,
          child: heroImage != null
              ? CachedNetworkImage(
                  imageUrl:       heroImage,
                  fit:            BoxFit.cover,
                  width:          screenW,
                  memCacheWidth:  800,
                  fadeInDuration: const Duration(milliseconds: 200),
                  placeholder:    (_, __) => Container(color: AppColors.card),
                  errorWidget:    (_, __, ___) => Container(color: AppColors.card),
                )
              : Container(color: AppColors.card),
        ),

        // ── Multi-stop gradient dissolve ───────────────────────────────────
        Positioned(
          top: 0, left: 0, right: 0,
          height: screenH * 0.60,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin:  Alignment.topCenter,
                end:    Alignment.bottomCenter,
                stops:  [0.0, 0.25, 0.60, 1.0],
                colors: [
                  Color(0x20070709),
                  Color(0x08070709),
                  Color(0xB0070709),
                  Color(0xFF070709),
                ],
              ),
            ),
          ),
        ),

        // ── Side vignette ──────────────────────────────────────────────────
        Positioned(
          top: 0, left: 0, bottom: 0,
          width: screenW * 0.35,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin:  Alignment.centerLeft,
                end:    Alignment.centerRight,
                colors: [Color(0x90070709), Colors.transparent],
              ),
            ),
          ),
        ),

        // ── Solid fill below backdrop ──────────────────────────────────────
        Positioned(
          top: screenH * 0.60, left: 0, right: 0, bottom: 0,
          child: Container(color: AppColors.background),
        ),

        // ── Top bar: Back + Favourite ──────────────────────────────────────
        Positioned(
          top:  topPad + AppSpacing.md,
          left: AppSpacing.tvH,
          right: AppSpacing.tvH,
          child: Row(
            children: [
              FocusableWidget(
                focusNode:    _backNode,
                borderRadius: AppSpacing.radiusPill,
                onTap: () => context.pop(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color:        const Color(0x30000000),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                    border:       Border.all(color: const Color(0x15FFFFFF), width: 0.5),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textSecondary, size: 11),
                      SizedBox(width: 6),
                      Text('Movies', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w400)),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              // ── Favourite button ──
              Focus(
                onKeyEvent: (_, event) {
                  if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
                  if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                    _backNode.requestFocus();
                    return KeyEventResult.handled;
                  }
                  if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                    _playNode.requestFocus();
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: FocusableWidget(
                  focusNode:    _favNode,
                  borderRadius: AppSpacing.radiusPill,
                  onTap: widget.onToggleFavourite,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color:        const Color(0x30000000),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                      border:       Border.all(color: const Color(0x15FFFFFF), width: 0.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          vod.isFavourite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: vod.isFavourite ? AppColors.accentPrimary : AppColors.textSecondary,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          vod.isFavourite ? 'Favourited' : 'Favourite',
                          style: TextStyle(
                            color: vod.isFavourite ? AppColors.accentPrimary : AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Content ───────────────────────────────────────────────────────
        Positioned.fill(
          child: FadeTransition(
            opacity: _fadeIn,
            child: SlideTransition(
              position: _slideUp,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: screenH * 0.36),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: AppSpacing.tvH),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Title ──────────────────────────────────────────
                          Text(
                            vod.name,
                            style: const TextStyle(
                              color:         AppColors.textPrimary,
                              fontSize:      36,
                              fontWeight:    FontWeight.w300,
                              letterSpacing: -0.8,
                              height:        1.1,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),

                          // ── Meta chips + IMDB badge ────────────────────────
                          _MetaRow(vod: vod, duration: _duration),
                          const SizedBox(height: AppSpacing.md),

                          // ── Plot ───────────────────────────────────────────
                          if (vod.plot != null) ...[
                            Text(
                              vod.plot!,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color:      AppColors.textSecondary,
                                fontSize:   13,
                                fontWeight: FontWeight.w300,
                                height:     1.7,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                          ] else
                            const SizedBox(height: AppSpacing.md),

                          // ── Cast & Director ─────────────────────────────────
                          if (vod.director != null) ...[
                            _InfoLine(label: 'Director', value: vod.director!),
                            const SizedBox(height: 6),
                          ],
                          if (vod.cast != null) ...[
                            _InfoLine(label: 'Cast', value: vod.cast!),
                            const SizedBox(height: AppSpacing.xl),
                          ] else
                            const SizedBox(height: AppSpacing.md),

                          // ── Action buttons ─────────────────────────────────
                          _ActionButtons(
                            playNode:    _playNode,
                            trailerNode: _trailerNode,
                            backNode:    _backNode,
                            favNode:     _favNode,
                            hasTrailer:  hasTrailer,
                            onPlay: () => context.push('/movies/player', extra: {
                              'vod':      vod,
                              'backPath': '/movies/${vod.id}',
                            }),
                            onTrailer: _openTrailer,
                          ),
                          const SizedBox(height: AppSpacing.xl3),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Meta Row ─────────────────────────────────────────────────────────────────

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.vod, required this.duration});
  final VodItem vod;
  final String  duration;

  @override
  Widget build(BuildContext context) {
    final chips = <String>[
      if (vod.releaseDate != null) vod.releaseDate!,
      if (vod.genre != null)       vod.genre!,
      if (duration.isNotEmpty)     duration,
    ];

    return Row(
      children: [
        // ── IMDB-style rating badge ──
        if (vod.rating != null && vod.rating! > 0) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color:        const Color(0xFFF5C518), // IMDB yellow
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded, color: Color(0xFF000000), size: 13),
                const SizedBox(width: 3),
                Text(
                  vod.rating!.toStringAsFixed(1),
                  style: const TextStyle(
                    color:      Color(0xFF000000),
                    fontSize:   12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
        ],
        // ── Meta chips ──
        Expanded(
          child: Wrap(
            spacing:    6,
            runSpacing: 5,
            children: chips.map((label) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                border:       Border.all(color: const Color(0x20FFFFFF), width: 0.5),
                borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color:         AppColors.textMuted,
                  fontSize:      11,
                  fontWeight:    FontWeight.w400,
                  letterSpacing: 0.3,
                ),
              ),
            )).toList(),
          ),
        ),
      ],
    );
  }
}

// ── Action Buttons (Play + Trailer) ─────────────────────────────────────────

class _ActionButtons extends StatefulWidget {
  const _ActionButtons({
    required this.playNode,
    required this.trailerNode,
    required this.backNode,
    required this.favNode,
    required this.hasTrailer,
    required this.onPlay,
    required this.onTrailer,
  });
  final FocusNode    playNode;
  final FocusNode    trailerNode;
  final FocusNode    backNode;
  final FocusNode    favNode;
  final bool         hasTrailer;
  final VoidCallback onPlay;
  final VoidCallback onTrailer;

  @override
  State<_ActionButtons> createState() => _ActionButtonsState();
}

class _ActionButtonsState extends State<_ActionButtons> {
  bool _playFocused    = false;
  bool _trailerFocused = false;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ── Play button ──
        Expanded(
          flex: 3,
          child: Focus(
            onKeyEvent: (_, event) {
              if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
              if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                widget.backNode.requestFocus();
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowRight && widget.hasTrailer) {
                widget.trailerNode.requestFocus();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: FocusableWidget(
              focusNode:    widget.playNode,
              autofocus:    true,
              borderRadius: AppSpacing.radiusPill,
              onTap:        widget.onPlay,
              child: Focus(
                canRequestFocus: false,
                onFocusChange: (f) { if (mounted) setState(() => _playFocused = f); },
                child: AnimatedContainer(
                  duration: AppDurations.focus,
                  padding:  const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: _playFocused
                        ? AppColors.accentPrimary
                        : const Color(0x14FFFFFF),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.play_arrow_rounded,
                        color: _playFocused ? AppColors.background : AppColors.textPrimary,
                        size:  22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Play',
                        style: TextStyle(
                          color:         _playFocused ? AppColors.background : AppColors.textPrimary,
                          fontSize:      14,
                          fontWeight:    FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // ── Trailer button ──
        if (widget.hasTrailer) ...[
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Focus(
              onKeyEvent: (_, event) {
                if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
                if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                  widget.favNode.requestFocus();
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                  widget.playNode.requestFocus();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: FocusableWidget(
                focusNode:    widget.trailerNode,
                borderRadius: AppSpacing.radiusPill,
                onTap:        widget.onTrailer,
                child: Focus(
                  canRequestFocus: false,
                  onFocusChange: (f) { if (mounted) setState(() => _trailerFocused = f); },
                  child: AnimatedContainer(
                    duration: AppDurations.focus,
                    padding:  const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: _trailerFocused
                          ? const Color(0xFFFF0000) // YouTube red
                          : const Color(0x14FFFFFF),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                      border: Border.all(
                        color: _trailerFocused ? const Color(0xFFFF0000) : const Color(0x10FFFFFF),
                        width: 0.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.play_circle_outline_rounded,
                          color: _trailerFocused ? Colors.white : AppColors.textSecondary,
                          size:  20,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Trailer',
                          style: TextStyle(
                            color:         _trailerFocused ? Colors.white : AppColors.textSecondary,
                            fontSize:      13,
                            fontWeight:    FontWeight.w500,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Info Line ────────────────────────────────────────────────────────────────

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 65,
          child: Text(
            label,
            style: const TextStyle(
              color:      AppColors.textMuted,
              fontSize:   11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color:      AppColors.textSecondary,
              fontSize:   11,
              fontWeight: FontWeight.w300,
              height:     1.5,
            ),
          ),
        ),
      ],
    );
  }
}
