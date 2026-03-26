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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/home');
      },
      child: Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ─────────────────────────────────────────────────
            Container(
              color:   AppColors.surface,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  FocusableWidget(
                    focusNode: _backNode,
                    autofocus: true,
                    onTap:     () => context.go('/home'),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 18),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  const Text(
                    'Favourites',
                    style: TextStyle(
                      color:      AppColors.textPrimary,
                      fontSize:   14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            // ── Tab bar ─────────────────────────────────────────────────
            Row(
              children: [
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
            const Divider(height: 0),
            Expanded(child: _buildContent()),
          ],
        ),
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

class _Tab extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          onLeft();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowRight && onRight != null) {
          onRight!();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: FocusableWidget(
        focusNode: focusNode,
        onTap:     onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md,
          ),
          child: Text(
            label,
            style: TextStyle(
              color:      selected ? AppColors.textPrimary : AppColors.textMuted,
              fontSize:   13,
              fontWeight: selected ? FontWeight.w400 : FontWeight.w300,
            ),
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
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
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
              height:    56,
              padding:   const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              alignment: Alignment.centerLeft,
              child: Text(
                ch.name,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
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
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
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
              height:    56,
              padding:   const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              alignment: Alignment.centerLeft,
              child: Text(
                widget.items[i],
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              ),
            ),
          );
        },
      ),
    );
  }
}
