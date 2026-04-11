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
  final _favNode     = FocusNode();
  final _playNode    = FocusNode();
  final _trailerNode = FocusNode();
  late final AnimationController _entranceCtrl;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
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
    final vod        = widget.vod;
    final hasTrailer = vod.youtubeTrailer != null && vod.youtubeTrailer!.isNotEmpty;

    final fadeIn = CurvedAnimation(parent: _entranceCtrl, curve: AppCurves.easeOut);
    final posterSlide = Tween<Offset>(
      begin: const Offset(-0.04, 0), end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceCtrl,
      curve:  const Interval(0.0, 0.7, curve: AppCurves.easeOut),
    ));
    final detailSlide = Tween<Offset>(
      begin: const Offset(0.03, 0), end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceCtrl,
      curve:  const Interval(0.15, 0.85, curve: AppCurves.easeOut),
    ));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.tvH,
          vertical:   AppSpacing.lg,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Left column: Poster + Actions ──────────────────────────
            FadeTransition(
              opacity: fadeIn,
              child: SlideTransition(
                position: posterSlide,
                child: SizedBox(
                  width: 220,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Poster with fav overlay
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: vod.posterUrl != null
                                ? CachedNetworkImage(
                                    imageUrl:       vod.posterUrl!,
                                    width:          220,
                                    height:         320,
                                    fit:            BoxFit.cover,
                                    memCacheWidth:  440,
                                    fadeInDuration: const Duration(milliseconds: 200),
                                    placeholder:    (_, __) => Container(
                                      width: 220, height: 320,
                                      decoration: BoxDecoration(
                                        color:        AppColors.card,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    errorWidget: (_, __, ___) => Container(
                                      width: 220, height: 320,
                                      decoration: BoxDecoration(
                                        color:        AppColors.card,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(Icons.movie_outlined,
                                        color: AppColors.textMuted, size: 40),
                                    ),
                                  )
                                : Container(
                                    width: 220, height: 320,
                                    decoration: BoxDecoration(
                                      color:        AppColors.card,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.movie_outlined,
                                      color: AppColors.textMuted, size: 40),
                                  ),
                          ),
                          // Fav button top-right of poster
                          Positioned(
                            top: 8, right: 8,
                            child: Focus(
                              onKeyEvent: (_, event) {
                                if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
                                if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                                  _playNode.requestFocus();
                                  return KeyEventResult.handled;
                                }
                                if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                                  _playNode.requestFocus();
                                  return KeyEventResult.handled;
                                }
                                return KeyEventResult.ignored;
                              },
                              child: FocusableWidget(
                                focusNode:    _favNode,
                                borderRadius: 8,
                                onTap: widget.onToggleFavourite,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color:        AppColors.background.withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.glassBorder, width: 0.5),
                                  ),
                                  child: Icon(
                                    vod.isFavourite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                    color: vod.isFavourite ? AppColors.accentPrimary : AppColors.textSecondary,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Play button
                      Focus(
                        onKeyEvent: (_, event) {
                          if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
                          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                            _favNode.requestFocus();
                            return KeyEventResult.handled;
                          }
                          if (event.logicalKey == LogicalKeyboardKey.arrowDown && hasTrailer) {
                            _trailerNode.requestFocus();
                            return KeyEventResult.handled;
                          }
                          return KeyEventResult.ignored;
                        },
                        child: _PlayButton(
                          focusNode: _playNode,
                          onTap: () => context.push('/movies/player', extra: {
                            'vod':      vod,
                            'backPath': '/movies/${vod.id}',
                          }),
                        ),
                      ),

                      if (hasTrailer) ...[
                        const SizedBox(height: 10),
                        Focus(
                          onKeyEvent: (_, event) {
                            if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
                            if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                              _playNode.requestFocus();
                              return KeyEventResult.handled;
                            }
                            return KeyEventResult.ignored;
                          },
                          child: _TrailerButton(
                            focusNode: _trailerNode,
                            onTap:     _openTrailer,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 36),

            // ── Right column: Details ──────────────────────────────────
            Expanded(
              child: FadeTransition(
                opacity: fadeIn,
                child: SlideTransition(
                  position: detailSlide,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),

                        // Title
                        Text(
                          vod.name,
                          style: const TextStyle(
                            color:         AppColors.textPrimary,
                            fontSize:      28,
                            fontWeight:    FontWeight.w300,
                            letterSpacing: -0.6,
                            height:        1.15,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Meta line
                        _MetaLine(vod: vod, duration: _duration),
                        const SizedBox(height: 20),

                        // Divider
                        Container(height: 0.5, color: AppColors.borderSubtle),
                        const SizedBox(height: 20),

                        // Plot
                        if (vod.plot != null) ...[
                          Text(
                            vod.plot!,
                            style: const TextStyle(
                              color:      AppColors.textSecondary,
                              fontSize:   13,
                              fontWeight: FontWeight.w300,
                              height:     1.75,
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Director
                        if (vod.director != null) ...[
                          _DetailLabel('Director'),
                          const SizedBox(height: 4),
                          Text(
                            vod.director!,
                            style: const TextStyle(
                              color:    AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 18),
                        ],

                        // Cast
                        if (vod.cast != null) ...[
                          _DetailLabel('Cast'),
                          const SizedBox(height: 4),
                          Text(
                            vod.cast!,
                            style: const TextStyle(
                              color:    AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w300,
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 18),
                        ],

                        const SizedBox(height: AppSpacing.xl3),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Meta Line ───────────────────────────────────────────────────────────────

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.vod, required this.duration});
  final VodItem vod;
  final String  duration;

  @override
  Widget build(BuildContext context) {
    final parts = <Widget>[];

    if (vod.rating != null && vod.rating! > 0) {
      parts.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color:        const Color(0xFFF5C518),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_rounded, color: Color(0xFF121212), size: 12),
            const SizedBox(width: 2),
            Text(
              vod.rating!.toStringAsFixed(1),
              style: const TextStyle(
                color: Color(0xFF121212), fontSize: 11, fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ));
    }

    final textParts = <String>[
      if (vod.releaseDate != null) vod.releaseDate!,
      if (duration.isNotEmpty) duration,
      if (vod.genre != null) vod.genre!,
    ];

    if (parts.isNotEmpty && textParts.isNotEmpty) {
      parts.add(const SizedBox(width: 12));
    }

    if (textParts.isNotEmpty) {
      parts.add(Text(
        textParts.join('  ·  '),
        style: const TextStyle(
          color:         AppColors.textMuted,
          fontSize:      12,
          fontWeight:    FontWeight.w400,
          letterSpacing: 0.2,
        ),
      ));
    }

    return Row(children: parts);
  }
}

// ── Detail Label ────────────────────────────────────────────────────────────

class _DetailLabel extends StatelessWidget {
  const _DetailLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color:         AppColors.textMuted,
        fontSize:      10,
        fontWeight:    FontWeight.w600,
        letterSpacing: 1.2,
      ),
    );
  }
}

// ── Play Button ─────────────────────────────────────────────────────────────

class _PlayButton extends StatefulWidget {
  const _PlayButton({required this.focusNode, required this.onTap});
  final FocusNode    focusNode;
  final VoidCallback onTap;

  @override
  State<_PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<_PlayButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return FocusableWidget(
      focusNode:    widget.focusNode,
      autofocus:    true,
      borderRadius: 10,
      onTap:        widget.onTap,
      child: Focus(
        canRequestFocus: false,
        onFocusChange: (f) { if (mounted) setState(() => _focused = f); },
        child: AnimatedContainer(
          duration: AppDurations.focus,
          curve:    AppCurves.easeOut,
          width:    double.infinity,
          padding:  const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: _focused ? AppColors.accentPrimary : AppColors.accentSoft,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.play_arrow_rounded,
                color: _focused ? AppColors.background : AppColors.textPrimary,
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                'Play',
                style: TextStyle(
                  color: _focused ? AppColors.background : AppColors.textPrimary,
                  fontSize:      13,
                  fontWeight:    FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Trailer Button ──────────────────────────────────────────────────────────

class _TrailerButton extends StatefulWidget {
  const _TrailerButton({required this.focusNode, required this.onTap});
  final FocusNode    focusNode;
  final VoidCallback onTap;

  @override
  State<_TrailerButton> createState() => _TrailerButtonState();
}

class _TrailerButtonState extends State<_TrailerButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return FocusableWidget(
      focusNode:    widget.focusNode,
      borderRadius: 10,
      onTap:        widget.onTap,
      child: Focus(
        canRequestFocus: false,
        onFocusChange: (f) { if (mounted) setState(() => _focused = f); },
        child: AnimatedContainer(
          duration: AppDurations.focus,
          curve:    AppCurves.easeOut,
          width:    double.infinity,
          padding:  const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: _focused ? const Color(0xFFFF0000) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _focused ? const Color(0xFFFF0000) : AppColors.glassBorder,
              width: 0.5,
            ),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.play_circle_outline_rounded,
                color: _focused ? Colors.white : AppColors.textMuted,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'Trailer',
                style: TextStyle(
                  color: _focused ? Colors.white : AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
