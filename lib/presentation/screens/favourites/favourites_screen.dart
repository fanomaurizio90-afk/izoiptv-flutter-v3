import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/channel.dart';
import '../../../domain/entities/vod.dart';
import '../../../domain/entities/series.dart';
import '../../providers/channel_provider.dart';
import '../../providers/providers.dart';
import '../../widgets/common/focusable_widget.dart';
import '../../widgets/common/loading_widget.dart';

final _favChannelsProvider = FutureProvider<List<Channel>>((ref) =>
    ref.watch(favouritesRepositoryProvider).getFavouriteChannels());
final _favVodProvider      = FutureProvider<List<VodItem>>((ref) =>
    ref.watch(favouritesRepositoryProvider).getFavouriteVod());
final _favSeriesProvider   = FutureProvider<List<SeriesItem>>((ref) =>
    ref.watch(favouritesRepositoryProvider).getFavouriteSeries());

class FavouritesScreen extends ConsumerStatefulWidget {
  const FavouritesScreen({super.key});

  @override
  ConsumerState<FavouritesScreen> createState() => _FavouritesScreenState();
}

class _FavouritesScreenState extends ConsumerState<FavouritesScreen> {
  int _tab = 0; // 0=Channels 1=Movies 2=Series

  final _backNode  = FocusNode();
  final _tabNode0  = FocusNode();
  final _tabNode1  = FocusNode();
  final _tabNode2  = FocusNode();

  @override
  void dispose() {
    _backNode.dispose();
    _tabNode0.dispose();
    _tabNode1.dispose();
    _tabNode2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.tvH, AppSpacing.xl, AppSpacing.tvH, AppSpacing.sm,
              ),
              child: FocusableWidget(
                focusNode:    _backNode,
                autofocus:    true,
                borderRadius: AppSpacing.radiusPill,
                onTap:        () => context.go('/home'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                    border:       Border.all(color: AppColors.border, width: 0.5),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textMuted, size: 10),
                      SizedBox(width: 6),
                      Text(
                        'Favourites',
                        style: TextStyle(
                          color:         AppColors.textSecondary,
                          fontSize:      13,
                          fontWeight:    FontWeight.w400,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // ── Tab bar ─────────────────────────────────────────────────
            SizedBox(
              height: 46,
              child: Row(
                children: [
                  const SizedBox(width: AppSpacing.tvH),
                  _Tab(
                    label:     'Channels',
                    selected:  _tab == 0,
                    focusNode: _tabNode0,
                    onTap: () => setState(() => _tab = 0),
                    onLeft:  () => _backNode.requestFocus(),
                    onRight: () => _tabNode1.requestFocus(),
                  ),
                  _Tab(
                    label:     'Movies',
                    selected:  _tab == 1,
                    focusNode: _tabNode1,
                    onTap: () => setState(() => _tab = 1),
                    onLeft:  () => _tabNode0.requestFocus(),
                    onRight: () => _tabNode2.requestFocus(),
                  ),
                  _Tab(
                    label:     'Series',
                    selected:  _tab == 2,
                    focusNode: _tabNode2,
                    onTap: () => setState(() => _tab = 2),
                    onLeft:  () => _tabNode1.requestFocus(),
                    onRight: null,
                  ),
                ],
              ),
            ),
            Container(height: 0.5, color: AppColors.border),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_tab) {
      case 0:
        return ref.watch(_favChannelsProvider).when(
          data:    (items) => _ChannelList(channels: items),
          loading: () => const LoadingWidget(),
          error:   (e, _) => Center(child: Text(e.toString(), style: const TextStyle(color: AppColors.error, fontSize: 12))),
        );
      case 1:
        return ref.watch(_favVodProvider).when(
          data:    (items) => _SimpleList(
            items: items.map((v) => v.name).toList(),
            onTap: (i) => context.push('/movies/${items[i].id}'),
          ),
          loading: () => const LoadingWidget(),
          error:   (e, _) => Center(child: Text(e.toString(), style: const TextStyle(color: AppColors.error, fontSize: 12))),
        );
      case 2:
        return ref.watch(_favSeriesProvider).when(
          data:    (items) => _SimpleList(
            items: items.map((s) => s.name).toList(),
            onTap: (i) => context.push('/series/${items[i].id}'),
          ),
          loading: () => const LoadingWidget(),
          error:   (e, _) => Center(child: Text(e.toString(), style: const TextStyle(color: AppColors.error, fontSize: 12))),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// ── Tab ────────────────────────────────────────────────────────────────────────

class _Tab extends StatefulWidget {
  const _Tab({
    required this.label,
    required this.selected,
    required this.focusNode,
    required this.onTap,
    required this.onLeft,
    required this.onRight,
  });
  final String        label;
  final bool          selected;
  final FocusNode     focusNode;
  final VoidCallback  onTap;
  final VoidCallback  onLeft;
  final VoidCallback? onRight;

  @override
  State<_Tab> createState() => _TabState();
}

class _TabState extends State<_Tab> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(_Tab old) {
    super.didUpdateWidget(old);
    if (old.focusNode != widget.focusNode) {
      old.focusNode.removeListener(_onFocus);
      widget.focusNode.addListener(_onFocus);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() {
    if (mounted) setState(() => _focused = widget.focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          widget.onLeft();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowRight && widget.onRight != null) {
          widget.onRight!();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: FocusableWidget(
        focusNode:       widget.focusNode,
        onTap:           widget.onTap,
        showFocusBorder: false,
        child: Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize:      MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: widget.selected
                        ? AppColors.textPrimary
                        : _focused
                            ? AppColors.textSecondary
                            : AppColors.textMuted,
                    fontSize:   12,
                    fontWeight: widget.selected ? FontWeight.w500 : FontWeight.w300,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: AppDurations.medium,
                curve:    Curves.easeOut,
                height:   1.5,
                width:    widget.selected ? 16 : 0,
                decoration: BoxDecoration(
                  color:        AppColors.accentPrimary,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Channel List ──────────────────────────────────────────────────────────────

class _ChannelList extends ConsumerStatefulWidget {
  const _ChannelList({required this.channels});
  final List<Channel> channels;

  @override
  ConsumerState<_ChannelList> createState() => _ChannelListState();
}

class _ChannelListState extends ConsumerState<_ChannelList> {
  List<FocusNode>        _nodes      = [];
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _nodes = List.generate(widget.channels.length, (_) => FocusNode());
  }

  @override
  void didUpdateWidget(_ChannelList old) {
    super.didUpdateWidget(old);
    if (widget.channels.length != _nodes.length) {
      for (final n in _nodes) n.dispose();
      _nodes = List.generate(widget.channels.length, (_) => FocusNode());
    }
  }

  @override
  void dispose() {
    for (final n in _nodes) n.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  int get _focusedIndex {
    for (int i = 0; i < _nodes.length; i++) {
      if (_nodes[i].hasFocus) return i;
    }
    return -1;
  }

  void _moveTo(int idx) {
    if (idx < 0 || idx >= _nodes.length) return;
    _nodes[idx].requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureVisible(idx));
  }

  void _ensureVisible(int idx) {
    if (!_scrollCtrl.hasClients) return;
    const h      = 56.0;
    final top    = idx * h;
    final bottom = top + h;
    final vp     = _scrollCtrl.position.viewportDimension;
    final off    = _scrollCtrl.offset;
    double? target;
    if (top < off) target = top;
    else if (bottom > off + vp) target = bottom - vp;
    if (target != null) {
      _scrollCtrl.animateTo(
        target.clamp(0.0, _scrollCtrl.position.maxScrollExtent),
        duration: const Duration(milliseconds: 150),
        curve:    Curves.easeOut,
      );
    }
  }

  KeyEventResult _handleKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final idx = _focusedIndex;
    if (idx < 0) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown && idx + 1 < _nodes.length) {
      _moveTo(idx + 1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp && idx > 0) {
      _moveTo(idx - 1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.channels.isEmpty) {
      return const Center(
        child: Text('No favourite channels',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
      );
    }
    return Focus(
      onKeyEvent:    _handleKey,
      skipTraversal: true,
      child: ListView.builder(
        controller: _scrollCtrl,
        itemCount:  widget.channels.length,
        itemExtent: 56,
        itemBuilder: (_, i) {
          final ch = widget.channels[i];
          return FocusableWidget(
            focusNode: _nodes[i],
            autofocus: i == 0,
            onTap: () {
              ref.read(selectedChannelProvider.notifier).state     = ch;
              ref.read(currentChannelListProvider.notifier).state  = widget.channels;
              ref.read(currentChannelIndexProvider.notifier).state = i;
              context.push('/live/player');
            },
            child: Container(
              height:  56,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.tvH),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.borderSubtle, width: 0.5)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color:        AppColors.card,
                      borderRadius: BorderRadius.circular(8),
                      border:       Border.all(color: AppColors.border, width: 0.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        color:    AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      ch.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color:      AppColors.textPrimary,
                        fontSize:   13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 14),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Simple List (Movies / Series) ─────────────────────────────────────────────

class _SimpleList extends StatefulWidget {
  const _SimpleList({required this.items, required this.onTap});
  final List<String>       items;
  final void Function(int) onTap;

  @override
  State<_SimpleList> createState() => _SimpleListState();
}

class _SimpleListState extends State<_SimpleList> {
  List<FocusNode>        _nodes      = [];
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _nodes = List.generate(widget.items.length, (_) => FocusNode());
  }

  @override
  void didUpdateWidget(_SimpleList old) {
    super.didUpdateWidget(old);
    if (widget.items.length != _nodes.length) {
      for (final n in _nodes) n.dispose();
      _nodes = List.generate(widget.items.length, (_) => FocusNode());
    }
  }

  @override
  void dispose() {
    for (final n in _nodes) n.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  int get _focusedIndex {
    for (int i = 0; i < _nodes.length; i++) {
      if (_nodes[i].hasFocus) return i;
    }
    return -1;
  }

  void _moveTo(int idx) {
    if (idx < 0 || idx >= _nodes.length) return;
    _nodes[idx].requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureVisible(idx));
  }

  void _ensureVisible(int idx) {
    if (!_scrollCtrl.hasClients) return;
    const h      = 56.0;
    final top    = idx * h;
    final bottom = top + h;
    final vp     = _scrollCtrl.position.viewportDimension;
    final off    = _scrollCtrl.offset;
    double? target;
    if (top < off) target = top;
    else if (bottom > off + vp) target = bottom - vp;
    if (target != null) {
      _scrollCtrl.animateTo(
        target.clamp(0.0, _scrollCtrl.position.maxScrollExtent),
        duration: const Duration(milliseconds: 150),
        curve:    Curves.easeOut,
      );
    }
  }

  KeyEventResult _handleKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final idx = _focusedIndex;
    if (idx < 0) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown && idx + 1 < _nodes.length) {
      _moveTo(idx + 1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp && idx > 0) {
      _moveTo(idx - 1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const Center(
        child: Text('No favourites',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
      );
    }
    return Focus(
      onKeyEvent:    _handleKey,
      skipTraversal: true,
      child: ListView.builder(
        controller: _scrollCtrl,
        itemCount:  widget.items.length,
        itemExtent: 56,
        itemBuilder: (_, i) {
          return FocusableWidget(
            focusNode: _nodes[i],
            autofocus: i == 0,
            onTap:     () => widget.onTap(i),
            child: Container(
              height:  56,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.tvH),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.borderSubtle, width: 0.5)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.items[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color:      AppColors.textPrimary,
                        fontSize:   13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 14),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
