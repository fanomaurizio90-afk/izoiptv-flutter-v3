import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/vod.dart';
import '../../providers/providers.dart';
import '../../widgets/common/focusable_widget.dart';
import '../../widgets/common/skeleton_widget.dart';

// Simple provider — loads from DB only, never blocks on network.
final _vodDetailProvider = FutureProvider.family<VodItem?, int>((ref, id) async {
  return ref.read(vodRepositoryProvider).getVodById(id);
});

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
    // Enrich metadata in background — never blocks the screen from showing.
    // When done, invalidates the provider so the screen rebuilds with poster/plot.
    WidgetsBinding.instance.addPostFrameCallback((_) => _enrichIfNeeded());
  }

  Future<void> _enrichIfNeeded() async {
    if (!mounted) return;
    final repo = ref.read(vodRepositoryProvider);
    final vod  = await repo.getVodById(widget.vodId);
    if (!mounted || vod == null || vod.posterUrl != null || vod.plot != null) return;
    try {
      await repo.fetchVodInfo(widget.vodId);
      if (mounted) ref.invalidate(_vodDetailProvider(widget.vodId));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final vodAsync = ref.watch(_vodDetailProvider(widget.vodId));
    return Scaffold(
      backgroundColor: const Color(0xFF080808),
      body: vodAsync.when(
        data: (vod) {
          if (vod == null) {
            return Center(child: Text('Movie not found',
              style: TextStyle(color: AppColors.textSecondary)));
          }
          return _MovieDetailBody(vod: vod);
        },
        loading: () => const SkeletonDetailBackdrop(),
        error:   (e, _) => Center(child: Text(e.toString(),
          style: TextStyle(color: AppColors.error, fontSize: 12))),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Body
// ─────────────────────────────────────────────────────────────────────────────

class _MovieDetailBody extends ConsumerStatefulWidget {
  const _MovieDetailBody({required this.vod});
  final VodItem vod;

  @override
  ConsumerState<_MovieDetailBody> createState() => _MovieDetailBodyState();
}

class _MovieDetailBodyState extends ConsumerState<_MovieDetailBody> {
  final _backNode = FocusNode();
  final _playNode = FocusNode();
  Map<String, dynamic>? _history;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _backNode.dispose();
    _playNode.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final h = await ref.read(historyRepositoryProvider).getPosition(widget.vod.id, 'movie');
    if (mounted) setState(() => _history = h);
  }

  double get _progress {
    final h = _history;
    if (h == null) return 0.0;
    final pos = (h['position_secs'] as int? ?? 0).toDouble();
    final dur = (h['duration_secs'] as int? ?? 1).toDouble();
    return dur > 0 ? (pos / dur).clamp(0.0, 1.0) : 0.0;
  }

  bool get _isInProgress => _history != null && _progress < 0.9;

  String _fmtPos(int secs) {
    final h = secs ~/ 3600;
    final m = (secs % 3600) ~/ 60;
    final s = secs % 60;
    if (h > 0) return '${h}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '${m}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final topPad  = MediaQuery.of(context).padding.top;
    final screenH = MediaQuery.of(context).size.height;
    final vod     = widget.vod;

    return Stack(
      children: [
        // ── Backdrop — 50% height, fades in on open ───────────────────────────
        Positioned(
          top: 0, left: 0, right: 0,
          height: screenH * 0.50,
          child: AnimatedOpacity(
            opacity:  _visible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 500),
            child: vod.posterUrl != null
                ? CachedNetworkImage(
                    imageUrl:    vod.posterUrl!,
                    fit:         BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(color: AppColors.card),
                  )
                : Container(color: AppColors.card),
          ),
        ),
        // ── Left edge vignette — depth without blocking image ─────────────────
        Positioned(
          top: 0, left: 0, bottom: 0,
          width: screenH * 0.22,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin:  Alignment.centerLeft,
                end:    Alignment.centerRight,
                colors: [Color(0xFF080808), Colors.transparent],
              ),
            ),
          ),
        ),
        // ── Bottom gradient melt — dramatic fade into #080808 ─────────────────
        Positioned(
          top:    screenH * 0.20,
          left:   0, right: 0,
          height: screenH * 0.35,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin:  Alignment.topCenter,
                end:    Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xFF080808)],
                stops:  [0.0, 0.88],
              ),
            ),
          ),
        ),
        // ── Solid base below backdrop ─────────────────────────────────────────
        Positioned(
          top: screenH * 0.50, left: 0, right: 0, bottom: 0,
          child: Container(color: const Color(0xFF080808)),
        ),
        // ── Back button ───────────────────────────────────────────────────────
        Positioned(
          top:  topPad + AppSpacing.sm,
          left: AppSpacing.tvH,
          child: FocusableWidget(
            focusNode: _backNode,
            onTap:     () => context.go('/movies'),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: const Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 18),
            ),
          ),
        ),
        // ── Scrollable content ────────────────────────────────────────────────
        Positioned.fill(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: screenH * 0.32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.tvH),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title — slides up on screen open
                      AnimatedSlide(
                        offset:   _visible ? Offset.zero : const Offset(0, 0.2),
                        duration: const Duration(milliseconds: 350),
                        curve:    Curves.easeOutCubic,
                        child: AnimatedOpacity(
                          opacity:  _visible ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            vod.name,
                            style: const TextStyle(
                              color:         Colors.white,
                              fontSize:      28,
                              fontWeight:    FontWeight.w700,
                              letterSpacing: -0.6,
                              height:        1.15,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Metadata — year · genre · duration
                      AnimatedOpacity(
                        opacity:  _visible ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 400),
                        child:    _MetaRow(vod: vod),
                      ),
                      if (vod.rating != null) ...[
                        const SizedBox(height: 8),
                        AnimatedOpacity(
                          opacity:  _visible ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 450),
                          child:    _RatingBadge(rating: vod.rating!),
                        ),
                      ],
                      if (vod.plot != null) ...[
                        const SizedBox(height: AppSpacing.lg),
                        AnimatedOpacity(
                          opacity:  _visible ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 500),
                          child: Text(
                            vod.plot!,
                            style: const TextStyle(
                              color:      Color(0xFF999999),
                              fontSize:   13,
                              fontWeight: FontWeight.w300,
                              height:     1.6,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl3),
                      // Resume progress — only shown if partially watched
                      if (_isInProgress) ...[
                        AnimatedOpacity(
                          opacity:  _visible ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 500),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.history,
                                      color: Color(0xFF555555), size: 11),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Resume from ${_fmtPos(_history!['position_secs'] as int? ?? 0)}',
                                    style: const TextStyle(
                                      color:    Color(0xFF666666),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(1),
                                child: LinearProgressIndicator(
                                  value:           _progress,
                                  minHeight:       2,
                                  backgroundColor: const Color(0xFF2A2A2A),
                                  valueColor:      const AlwaysStoppedAnimation(Colors.white),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                            ],
                          ),
                        ),
                      ],
                      // Play / Resume button — full width hero CTA
                      AnimatedOpacity(
                        opacity:  _visible ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 550),
                        child: Focus(
                          onKeyEvent: (_, event) {
                            if (event is KeyDownEvent &&
                                event.logicalKey == LogicalKeyboardKey.arrowUp) {
                              _backNode.requestFocus();
                              return KeyEventResult.handled;
                            }
                            return KeyEventResult.ignored;
                          },
                          child: FocusableWidget(
                            focusNode:    _playNode,
                            autofocus:    true,
                            borderRadius: AppSpacing.radiusCard,
                            onTap:        () => context.push('/movies/player', extra: {
                              'vod':      vod,
                              'backPath': '/movies/${vod.id}',
                            }),
                            child: Container(
                              width:   double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              decoration: BoxDecoration(
                                color:        Colors.white,
                                borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.play_arrow_rounded,
                                      color: Color(0xFF080808), size: 22),
                                  const SizedBox(width: 6),
                                  Text(
                                    _isInProgress ? 'Resume' : 'Play',
                                    style: const TextStyle(
                                      color:         Color(0xFF080808),
                                      fontSize:      15,
                                      fontWeight:    FontWeight.w600,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

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
      style: const TextStyle(
        color:         Color(0xFF555555),
        fontSize:      12,
        fontWeight:    FontWeight.w300,
        letterSpacing: 0.5,
        height:        1.4,
      ),
    );
  }
}

class _RatingBadge extends StatelessWidget {
  const _RatingBadge({required this.rating});
  final double rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.star_rounded, color: Color(0xFFFFBB33), size: 13),
        const SizedBox(width: 4),
        Text(
          rating.toStringAsFixed(1),
          style: const TextStyle(
            color:      Color(0xFFCCCCCC),
            fontSize:   12,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(width: 3),
        const Text(
          '/ 10',
          style: TextStyle(color: Color(0xFF444444), fontSize: 11),
        ),
      ],
    );
  }
}
