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
    if (!mounted || vod == null || vod.posterUrl != null || vod.plot != null) return;
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
            return _MovieDetailBody(vod: vod);
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
  const _MovieDetailBody({required this.vod});
  final VodItem vod;

  @override
  State<_MovieDetailBody> createState() => _MovieDetailBodyState();
}

class _MovieDetailBodyState extends State<_MovieDetailBody>
    with SingleTickerProviderStateMixin {
  final _backNode = FocusNode();
  final _playNode = FocusNode();
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
    _playNode.dispose();
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

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final screenW = MediaQuery.of(context).size.width;
    final topPad  = MediaQuery.of(context).padding.top;
    final vod     = widget.vod;

    return Stack(
      children: [
        // ── Full-bleed backdrop ────────────────────────────────────────────
        Positioned(
          top: 0, left: 0, right: 0,
          height: screenH * 0.60,
          child: vod.posterUrl != null
              ? CachedNetworkImage(
                  imageUrl:    vod.posterUrl!,
                  fit:         BoxFit.cover,
                  width:       screenW,
                  errorWidget: (_, __, ___) => Container(color: AppColors.card),
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

        // ── Back chevron ───────────────────────────────────────────────────
        Positioned(
          top:  topPad + AppSpacing.md,
          left: AppSpacing.tvH,
          child: FocusableWidget(
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

                          // ── Meta chips ─────────────────────────────────────
                          _MetaRow(vod: vod, duration: _duration),
                          const SizedBox(height: AppSpacing.sm),

                          // ── Rating ─────────────────────────────────────────
                          if (vod.rating != null) ...[
                            _RatingBar(rating: vod.rating!),
                            const SizedBox(height: AppSpacing.xl),
                          ] else
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
                            const SizedBox(height: AppSpacing.xl3),
                          ] else
                            const SizedBox(height: AppSpacing.xl2),

                          // ── Play button ────────────────────────────────────
                          _PlayButton(
                            focusNode: _playNode,
                            backNode:  _backNode,
                            onPlay: () => context.push('/movies/player', extra: {
                              'vod':      vod,
                              'backPath': '/movies/${vod.id}',
                            }),
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
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(
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
    );
  }
}

// ── Rating Bar ───────────────────────────────────────────────────────────────

class _RatingBar extends StatelessWidget {
  const _RatingBar({required this.rating});
  final double rating;

  @override
  Widget build(BuildContext context) {
    final filled = (rating / 2).round().clamp(0, 5);
    return Row(
      children: [
        ...List.generate(5, (i) => Padding(
          padding: const EdgeInsets.only(right: 3),
          child: Icon(
            i < filled ? Icons.star_rounded : Icons.star_outline_rounded,
            color: i < filled
                ? AppColors.accentPrimary
                : const Color(0x33FFFFFF),
            size: 13,
          ),
        )),
        const SizedBox(width: 8),
        Text(
          rating.toStringAsFixed(1),
          style: const TextStyle(
            color:    AppColors.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

// ── Play Button ──────────────────────────────────────────────────────────────

class _PlayButton extends StatefulWidget {
  const _PlayButton({
    required this.focusNode,
    required this.backNode,
    required this.onPlay,
  });
  final FocusNode    focusNode;
  final FocusNode    backNode;
  final VoidCallback onPlay;

  @override
  State<_PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<_PlayButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (_, event) {
        if ((event is KeyDownEvent || event is KeyRepeatEvent) &&
            event.logicalKey == LogicalKeyboardKey.arrowUp) {
          widget.backNode.requestFocus();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: FocusableWidget(
        focusNode:    widget.focusNode,
        autofocus:    true,
        borderRadius: AppSpacing.radiusPill,
        onTap:        widget.onPlay,
        child: Focus(
          canRequestFocus: false,
          onFocusChange: (f) { if (mounted) setState(() => _focused = f); },
          child: AnimatedContainer(
            duration: AppDurations.focus,
            width:    double.infinity,
            padding:  const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: _focused
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
                  color: _focused ? AppColors.background : AppColors.textPrimary,
                  size:  22,
                ),
                const SizedBox(width: 8),
                Text(
                  'Play',
                  style: TextStyle(
                    color:         _focused ? AppColors.background : AppColors.textPrimary,
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
    );
  }
}
