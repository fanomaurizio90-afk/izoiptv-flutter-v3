import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/debounce.dart';
import '../../../domain/entities/channel.dart';
import '../../providers/channel_provider.dart';
import '../../providers/providers.dart';
import '../../widgets/common/focusable_widget.dart';
import '../../widgets/common/skeleton_widget.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/common/pin_dialog.dart';
import '../../../core/utils/parental_control.dart';

const int _kFavCatId = -1; // Virtual "Favourites" category — not in DB

class LiveTvScreen extends ConsumerStatefulWidget {
  const LiveTvScreen({super.key});
  @override
  ConsumerState<LiveTvScreen> createState() => _LiveTvScreenState();
}

class _LiveTvScreenState extends ConsumerState<LiveTvScreen> {
  final _searchCtrl = TextEditingController();
  final _debounce   = Debounce(duration: const Duration(milliseconds: 250));

  List<ChannelCategory> _categories    = [];
  int?                  _selectedCatId;
  List<Channel>         _channels      = [];
  List<Channel>         _filtered      = [];
  Set<int>              _favouriteIds  = {};
  bool                  _loading       = true;
  bool                  _syncing       = false;
  String?               _error;

  // Focus nodes for cross-panel navigation
  final _searchFocusNode   = FocusNode();
  final _firstSidebarNode  = FocusNode();
  // First channel row focus — set via callback from _ChannelList
  FocusNode? _firstChannelNode;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearch);
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearch);
    _searchCtrl.dispose();
    _debounce.dispose();
    _searchFocusNode.dispose();
    _firstSidebarNode.dispose();
    super.dispose();
  }

  void _onSearch() {
    _debounce(() {
      final q = _searchCtrl.text.trim();
      if (!mounted) return;
      setState(() {
        _filtered = q.isEmpty
            ? _channels
            : _channels.where((c) => c.name.toLowerCase().contains(q.toLowerCase())).toList();
      });
    });
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final repo = ref.read(channelRepositoryProvider);
      var cats = await repo.getCategories();
      if (cats.isEmpty) {
        setState(() { _loading = false; _syncing = true; });
        await repo.syncChannels();
        if (!mounted) return;
        setState(() { _syncing = false; _loading = true; });
        cats = await repo.getCategories();
      }
      cats.sort((a, b) {
        final aA = isAdultCategory(a.name);
        final bA = isAdultCategory(b.name);
        if (aA == bA) return 0;
        return aA ? 1 : -1;
      });
      // Prepend virtual Favourites category at the top
      cats = [const ChannelCategory(id: _kFavCatId, name: '★  Favourites'), ...cats];

      // Load favourite IDs for star indicators
      final favChannels = await repo.getFavourites();
      final favIds      = favChannels.map((c) => c.id).toSet();

      if (!mounted) return;
      if (cats.length <= 1) { setState(() { _loading = false; }); return; }
      final catId    = (_selectedCatId != null && cats.any((c) => c.id == _selectedCatId))
          ? _selectedCatId!
          : cats[1].id; // default to first real category (index 1)
      final channels = catId == _kFavCatId
          ? favChannels
          : await repo.getChannelsByCategory(catId);
      if (!mounted) return;
      setState(() {
        _categories    = cats;
        _selectedCatId = catId;
        _favouriteIds  = favIds;
        _channels      = channels;
        _filtered      = channels;
        _loading       = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _syncing = false; _error = e.toString(); });
    }
  }

  Future<void> _selectCategory(int catId) async {
    setState(() { _selectedCatId = catId; _loading = true; });
    _firstChannelNode = null;
    try {
      final repo = ref.read(channelRepositoryProvider);
      final channels = catId == _kFavCatId
          ? await repo.getFavourites()
          : await repo.getChannelsByCategory(catId);
      if (!mounted) return;
      setState(() {
        _channels = channels;
        _filtered = channels;
        _loading  = false;
      });
      _searchCtrl.clear();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFavourite(Channel ch) async {
    final repo   = ref.read(channelRepositoryProvider);
    final newFav = !_favouriteIds.contains(ch.id);
    await repo.toggleFavourite(ch.id, newFav);
    if (!mounted) return;
    setState(() {
      if (newFav) {
        _favouriteIds.add(ch.id);
      } else {
        _favouriteIds.remove(ch.id);
        // If we're viewing Favourites, remove it from the visible list too
        if (_selectedCatId == _kFavCatId) {
          _channels = _channels.where((c) => c.id != ch.id).toList();
          _filtered = _filtered.where((c) => c.id != ch.id).toList();
        }
      }
    });
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
        child: Row(
          children: [
            _CategorySidebar(
              categories:     _categories,
              selectedId:     _selectedCatId,
              onSelect:       _selectCategory,
              firstItemNode:  _firstSidebarNode,
              // Right arrow on sidebar → search bar or first channel
              onRightArrow:   () => (_firstChannelNode ?? _searchFocusNode).requestFocus(),
            ),
            Container(width: 0.5, color: AppColors.border),
            Expanded(
              child: Column(
                children: [
                  _SearchBar(
                    controller:     _searchCtrl,
                    focusNode:      _searchFocusNode,
                    onLeftArrow:    () => _firstSidebarNode.requestFocus(),
                    onDownArrow:    () => _firstChannelNode?.requestFocus(),
                  ),
                  Expanded(child: _buildChannelList()),
                ],
              ),
            ),
          ],
        ),
      ),
      ), // Scaffold
    ); // PopScope
  }

  Widget _buildChannelList() {
    if (_syncing || _loading) return const SkeletonChannelList();
    if (_error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
        const SizedBox(height: AppSpacing.md),
        GestureDetector(onTap: _load,
          child: Text('Retry', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
      ]));
    }
    if (_filtered.isEmpty) {
      return const EmptyStateWidget(type: EmptyStateType.channels);
    }
    return _ChannelList(
      channels:         _filtered,
      categories:       _categories,
      favouriteIds:     _favouriteIds,
      sidebarNode:      _firstSidebarNode,
      onFirstNodeReady: (node) { _firstChannelNode = node; },
      onToggleFavourite: _toggleFavourite,
      onChannelTap:     (ch, i) async {
        final cat = _categories.firstWhere(
          (c) => c.id == ch.categoryId,
          orElse: () => const ChannelCategory(id: 0, name: ''),
        );
        if (isAdultCategory(cat.name) || isAdultCategory(ch.name)) {
          final ok = await showPinDialog(context);
          if (!ok || !mounted) return;
        }
        ref.read(selectedChannelProvider.notifier).state     = ch;
        ref.read(currentChannelListProvider.notifier).state  = _filtered;
        ref.read(currentChannelIndexProvider.notifier).state = i;
        if (mounted) context.push('/live/player');
      },
    );
  }
}

// ── Search Bar ────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.onLeftArrow,
    required this.onDownArrow,
  });
  final TextEditingController controller;
  final FocusNode             focusNode;
  final VoidCallback          onLeftArrow;
  final VoidCallback          onDownArrow;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(
        left: AppSpacing.md, right: AppSpacing.tvH,
        top: AppSpacing.sm,  bottom: AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_outlined, color: AppColors.textMuted, size: 16),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Focus(
              onKeyEvent: (_, event) {
                if (event is! KeyDownEvent) return KeyEventResult.ignored;
                if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                  onLeftArrow();
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                  onDownArrow();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: TextField(
                controller: controller,
                focusNode:  focusNode,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText:       'Search channels',
                  hintStyle:      TextStyle(color: AppColors.textMuted, fontSize: 13),
                  border:         InputBorder.none,
                  enabledBorder:  InputBorder.none,
                  focusedBorder:  InputBorder.none,
                  isDense:        true,
                  contentPadding: EdgeInsets.zero,
                  fillColor:      Colors.transparent,
                  filled:         true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Channel List ──────────────────────────────────────────────────────────────

class _ChannelList extends StatefulWidget {
  const _ChannelList({
    required this.channels,
    required this.categories,
    required this.favouriteIds,
    required this.sidebarNode,
    required this.onFirstNodeReady,
    required this.onToggleFavourite,
    required this.onChannelTap,
  });
  final List<Channel>                     channels;
  final List<ChannelCategory>             categories;
  final Set<int>                          favouriteIds;
  final FocusNode                         sidebarNode;
  final void Function(FocusNode)          onFirstNodeReady;
  final Future<void> Function(Channel)    onToggleFavourite;
  final void Function(Channel, int)       onChannelTap;

  @override
  State<_ChannelList> createState() => _ChannelListState();
}

class _ChannelListState extends State<_ChannelList> {
  List<FocusNode>        _nodes     = [];
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _nodes = List.generate(widget.channels.length, (_) => FocusNode());
    _notifyFirst();
  }

  @override
  void didUpdateWidget(_ChannelList old) {
    super.didUpdateWidget(old);
    if (widget.channels.length != _nodes.length) {
      for (final n in _nodes) n.dispose();
      _nodes = List.generate(widget.channels.length, (_) => FocusNode());
      _notifyFirst();
    }
  }

  @override
  void dispose() {
    for (final n in _nodes) n.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _notifyFirst() {
    if (_nodes.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onFirstNodeReady(_nodes[0]);
      });
    }
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
    final itemTop    = idx * AppConstants.channelRowHeight;
    final itemBottom = itemTop + AppConstants.channelRowHeight;
    final viewport   = _scrollCtrl.position.viewportDimension;
    final offset     = _scrollCtrl.offset;
    double? target;
    if (itemTop < offset) {
      target = itemTop;
    } else if (itemBottom > offset + viewport) {
      target = itemBottom - viewport;
    }
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
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _moveTo(idx + 1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (idx > 0) {
        _moveTo(idx - 1);
      } else {
        // First item — let focus go up to the search bar
        return KeyEventResult.ignored;
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      widget.sidebarNode.requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: const ScrollBehavior().copyWith(scrollbars: false),
      child: Focus(
        onKeyEvent:    _handleKey,
        skipTraversal: true,
        child: ListView.builder(
          controller: _scrollCtrl,
          itemCount:  widget.channels.length,
          itemExtent: AppConstants.channelRowHeight,
          itemBuilder: (_, i) {
            final ch = widget.channels[i];
            return _ChannelRow(
              channel:          ch,
              focusNode:        _nodes[i],
              isFavourite:      widget.favouriteIds.contains(ch.id),
              onTap:            () => widget.onChannelTap(ch, i),
              onToggleFavourite: () => widget.onToggleFavourite(ch),
            );
          },
        ),
      ),
    );
  }
}

// ── Channel Row ───────────────────────────────────────────────────────────────

class _ChannelRow extends StatefulWidget {
  const _ChannelRow({
    required this.channel,
    required this.onTap,
    required this.focusNode,
    required this.isFavourite,
    required this.onToggleFavourite,
  });
  final Channel           channel;
  final VoidCallback      onTap;
  final FocusNode         focusNode;
  final bool              isFavourite;
  final VoidCallback      onToggleFavourite;

  @override
  State<_ChannelRow> createState() => _ChannelRowState();
}

class _ChannelRowState extends State<_ChannelRow> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode:     widget.focusNode,
      onFocusChange: (f) { if (mounted) setState(() => _focused = f); },
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter) {
            widget.onTap();
            return KeyEventResult.handled;
          }
          // Fire Stick MENU button (≡) toggles favourite
          if (event.logicalKey == LogicalKeyboardKey.contextMenu) {
            widget.onToggleFavourite();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height:  AppConstants.channelRowHeight,
          padding: const EdgeInsets.only(left: AppSpacing.md, right: AppSpacing.md),
          decoration: BoxDecoration(
            color: _focused ? const Color(0x1AFFFFFF) : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: _focused ? AppColors.textPrimary : Colors.transparent,
                width: _focused ? 3.0 : 2.5,
              ),
              bottom: const BorderSide(color: AppColors.borderSubtle, width: 0.5),
            ),
          ),
          child: Row(
            children: [
              Container(
                width:  48,
                height: 48,
                decoration: BoxDecoration(
                  color:        AppColors.card,
                  borderRadius: BorderRadius.circular(8),
                  border:       Border.all(color: AppColors.border, width: 0.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7.5),
                  child: widget.channel.logoUrl != null
                      ? CachedNetworkImage(
                          imageUrl:    widget.channel.logoUrl!,
                          fit:         BoxFit.contain,
                          errorWidget: (_, __, ___) =>
                              _FirstLetterPlaceholder(name: widget.channel.name),
                        )
                      : _FirstLetterPlaceholder(name: widget.channel.name),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  widget.channel.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color:      AppColors.textPrimary,
                    fontSize:   _focused ? 14 : 13,
                    fontWeight: _focused ? FontWeight.w500 : FontWeight.w400,
                    height:     1.4,
                  ),
                ),
              ),
              // Favourite star indicator — always visible, amber when saved
              // Press remote MENU (≡) while focused to toggle
              AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity:  (widget.isFavourite || _focused) ? 1.0 : 0.0,
                child: Icon(
                  widget.isFavourite ? Icons.star : Icons.star_border,
                  color: widget.isFavourite
                      ? const Color(0xCCFFB300)   // amber, slightly dimmed
                      : AppColors.textMuted,
                  size: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FirstLetterPlaceholder extends StatelessWidget {
  const _FirstLetterPlaceholder({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final letter = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      color:     AppColors.card,
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          color:      AppColors.textSecondary,
          fontSize:   18,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ── Category Sidebar ──────────────────────────────────────────────────────────

class _CategorySidebar extends StatefulWidget {
  const _CategorySidebar({
    required this.categories,
    required this.selectedId,
    required this.onSelect,
    required this.onRightArrow,
    this.firstItemNode,
  });
  final List<ChannelCategory> categories;
  final int?                  selectedId;
  final void Function(int)    onSelect;
  final VoidCallback          onRightArrow;
  final FocusNode?            firstItemNode;

  @override
  State<_CategorySidebar> createState() => _CategorySidebarState();
}

class _CategorySidebarState extends State<_CategorySidebar> {
  final ScrollController _scrollCtrl = ScrollController();
  // _nodes[i] is for item index i+1 (item 0 uses widget.firstItemNode)
  List<FocusNode> _nodes = [];

  @override
  void initState() {
    super.initState();
    _rebuildNodes();
    widget.firstItemNode?.addListener(_onFirstNodeFocus);
  }

  @override
  void didUpdateWidget(_CategorySidebar old) {
    super.didUpdateWidget(old);
    if (widget.categories.length - 1 != _nodes.length) _rebuildNodes();
    if (widget.firstItemNode != old.firstItemNode) {
      old.firstItemNode?.removeListener(_onFirstNodeFocus);
      widget.firstItemNode?.addListener(_onFirstNodeFocus);
    }
  }

  @override
  void dispose() {
    widget.firstItemNode?.removeListener(_onFirstNodeFocus);
    for (final n in _nodes) n.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onFirstNodeFocus() {
    if (widget.firstItemNode?.hasFocus != true || !mounted) return;
    final selIdx = widget.categories.indexWhere((c) => c.id == widget.selectedId);
    if (selIdx > 0 && selIdx <= _nodes.length) {
      _nodes[selIdx - 1].requestFocus();
    } else {
      _ensureVisible(0);
    }
  }

  void _rebuildNodes() {
    for (final n in _nodes) n.dispose();
    _nodes = [];
    for (int i = 1; i < widget.categories.length; i++) {
      final idx = i;
      final n   = FocusNode();
      n.addListener(() { if (n.hasFocus && mounted) _ensureVisible(idx); });
      _nodes.add(n);
    }
  }

  void _ensureVisible(int idx) {
    if (!_scrollCtrl.hasClients) return;
    const h      = 56.0;
    final top    = idx * h;
    final bottom = top + h;
    final vp     = _scrollCtrl.position.viewportDimension;
    final off    = _scrollCtrl.offset;
    double? target;
    if (top < off) {
      target = top;
    } else if (bottom > off + vp) {
      target = bottom - vp;
    }
    if (target != null) {
      _scrollCtrl.animateTo(
        target.clamp(0.0, _scrollCtrl.position.maxScrollExtent),
        duration: const Duration(milliseconds: 150),
        curve:    Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: ScrollConfiguration(
        behavior: const ScrollBehavior().copyWith(scrollbars: false),
        child: ListView.builder(
          controller: _scrollCtrl,
          itemCount:  widget.categories.length,
          itemExtent: 56,
          itemBuilder: (_, i) {
            final cat        = widget.categories[i];
            final isSelected = cat.id == widget.selectedId;
            final node       = i == 0 ? widget.firstItemNode : _nodes[i - 1];
            return Focus(
              onKeyEvent: (_, event) {
                if (event is! KeyDownEvent) return KeyEventResult.ignored;
                if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                  widget.onRightArrow();
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
                    i < widget.categories.length - 1) {
                  _nodes[i].requestFocus(); // focus item i+1
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.arrowUp && i > 0) {
                  (i == 1 ? widget.firstItemNode : _nodes[i - 2])?.requestFocus();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: FocusableWidget(
                focusNode: node,
                autofocus: i == 0,
                onTap:     () => widget.onSelect(cat.id),
                child: Container(
                  height:   56,
                  padding:  const EdgeInsets.only(left: AppSpacing.tvH, right: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0x14FFFFFF) : Colors.transparent,
                    border: Border(
                      left: BorderSide(
                        color: isSelected ? AppColors.textPrimary : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                  ),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    cat.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color:      isSelected ? AppColors.textPrimary : AppColors.textMuted,
                      fontSize:   12,
                      fontWeight: isSelected ? FontWeight.w500 : FontWeight.w300,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
