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
import '../../../core/services/focus_memory_service.dart';
import '../../../core/utils/parental_control.dart';

class LiveTvScreen extends ConsumerStatefulWidget {
  const LiveTvScreen({super.key});
  @override
  ConsumerState<LiveTvScreen> createState() => _LiveTvScreenState();
}

class _LiveTvScreenState extends ConsumerState<LiveTvScreen> {
  final _searchCtrl        = TextEditingController();
  final _debounce          = Debounce(duration: const Duration(milliseconds: 250));
  final _searchFocusNode   = FocusNode();
  final _searchIconNode    = FocusNode();
  final _firstCatFocusNode = FocusNode();
  final _categoryBarKey    = GlobalKey<_CategoryBarState>();
  final _channelListKey    = GlobalKey<_ChannelListState>();

  static const _favouritesCatId = -1;

  List<ChannelCategory> _categories     = [];
  int?                  _selectedCatId;
  List<Channel>         _channels       = [];
  List<Channel>         _filtered       = [];
  bool                  _loading        = true;
  bool                  _syncing        = false;
  String?               _error;
  int                   _favouriteCount = 0;
  bool                  _searchActive   = false;
  bool                  _searching      = false;
  List<Channel>         _searchResults  = [];

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
    _searchIconNode.dispose();
    _firstCatFocusNode.dispose();
    super.dispose();
  }

  void _onSearch() {
    _debounce(() async {
      final q = _searchCtrl.text.trim();
      if (!mounted) return;
      if (q.isEmpty) {
        setState(() { _searching = false; _searchResults = []; });
      } else {
        final results = await ref.read(channelRepositoryProvider).searchChannels(q);
        if (!mounted) return;
        setState(() {
          _searching     = true;
          _searchResults = results;
        });
      }
    });
  }

  void _toggleSearch() {
    setState(() {
      _searchActive = !_searchActive;
      if (_searchActive) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _searchFocusNode.requestFocus();
        });
      } else {
        _searchCtrl.clear();
        _searching = false;
        _searchResults = [];
        _searchFocusNode.unfocus();
      }
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
      if (!mounted) return;
      if (cats.isEmpty) { setState(() { _loading = false; }); return; }
      final favs = await repo.getFavourites();
      _favouriteCount = favs.length;
      cats.insert(0, const ChannelCategory(id: _favouritesCatId, name: 'Favourites'));
      final catId    = _selectedCatId ?? cats.first.id;
      final channels = catId == _favouritesCatId
          ? favs
          : await repo.getChannelsByCategory(catId);
      if (!mounted) return;
      setState(() {
        _categories    = cats;
        _selectedCatId = catId;
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
    try {
      final repo = ref.read(channelRepositoryProvider);
      final channels = catId == _favouritesCatId
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
    final newVal = !ch.isFavourite;
    await repo.toggleFavourite(ch.id, newVal);

    Channel update(Channel c) => c.id == ch.id ? c.copyWith(isFavourite: newVal) : c;
    _channels = _channels.map(update).toList();
    _filtered = _filtered.map(update).toList();

    if (_selectedCatId == _favouritesCatId && !newVal) {
      _channels.removeWhere((c) => c.id == ch.id);
      _filtered.removeWhere((c) => c.id == ch.id);
    }

    final favs = await repo.getFavourites();
    _favouriteCount = favs.length;
    final hasFavCat = _categories.any((c) => c.id == _favouritesCatId);
    if (_favouriteCount > 0 && !hasFavCat) {
      _categories.insert(0, const ChannelCategory(id: _favouritesCatId, name: 'Favourites'));
    } else if (_favouriteCount == 0 && hasFavCat) {
      _categories.removeWhere((c) => c.id == _favouritesCatId);
      if (_selectedCatId == _favouritesCatId && _categories.isNotEmpty) {
        _selectCategory(_categories.first.id);
        return;
      }
    }

    if (!mounted) return;
    setState(() {});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          newVal ? '${ch.name} added to Favourites' : '${ch.name} removed from Favourites',
          style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
        ),
        duration:        const Duration(seconds: 2),
        backgroundColor: AppColors.card,
        behavior:        SnackBarBehavior.floating,
        shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin:          const EdgeInsets.all(AppSpacing.xl3),
      ));
    }
  }

  Future<void> _onChannelCategoryReorder(List<ChannelCategory> ordered) async {
    setState(() => _categories = ordered);
    final repo = ref.read(channelRepositoryProvider);
    final realOrdered = ordered.where((c) => c.id > 0).toList();
    await repo.saveCategoryOrder(realOrdered);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              searchCtrl:      _searchCtrl,
              searchFocusNode: _searchFocusNode,
              searchIconNode:  _searchIconNode,
              searchActive:    _searchActive,
              onSearchToggle:  _toggleSearch,
              onDownArrow:     () => _firstCatFocusNode.requestFocus(),
            ),
            _CategoryBar(
              key:                _categoryBarKey,
              categories:         _categories,
              selectedId:         _selectedCatId,
              onSelect:           _selectCategory,
              firstItemFocusNode: _firstCatFocusNode,
              onUpArrow:          () => _searchIconNode.requestFocus(),
              onDownArrow:        () => _channelListKey.currentState?.focusFirst(),
              onReorderConfirm:   _onChannelCategoryReorder,
            ),
            Expanded(child: _buildChannelArea()),
          ],
        ),
      ),
    );
  }

  Widget _buildChannelArea() {
    if (_syncing || _loading) return const SkeletonChannelList();
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: AppSpacing.lg),
          FocusableWidget(
            borderRadius: 8,
            onTap: _load,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                border:       Border.all(color: AppColors.glassBorder, width: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Retry',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ),
          ),
        ]),
      );
    }
    final displayList = _searching ? _searchResults : _filtered;
    if (displayList.isEmpty) {
      return const EmptyStateWidget(type: EmptyStateType.channels);
    }
    return _ChannelList(
      key:               _channelListKey,
      channels:          displayList,
      onUpFromFirst: () {
        if (_searchActive) {
          _searchFocusNode.requestFocus();
        } else {
          _categoryBarKey.currentState?.focusSelected();
        }
      },
      onToggleFavourite: _toggleFavourite,
      onChannelTap:      (ch, i) async {
        final cat = _categories.firstWhere(
          (c) => c.id == ch.categoryId,
          orElse: () => const ChannelCategory(id: 0, name: ''),
        );
        if (isAdultCategory(cat.name) || isAdultCategory(ch.name)) {
          final ok = await showPinDialog(context);
          if (!ok || !mounted) return;
        }
        FocusMemoryService.instance.save('live_tv', i);
        ref.read(selectedChannelProvider.notifier).state     = ch;
        ref.read(currentChannelListProvider.notifier).state  = _filtered;
        ref.read(currentChannelIndexProvider.notifier).state = i;
        if (mounted) context.push('/live/player');
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top Bar
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.searchCtrl,
    required this.searchFocusNode,
    required this.searchIconNode,
    required this.searchActive,
    required this.onSearchToggle,
    this.onDownArrow,
  });
  final TextEditingController searchCtrl;
  final FocusNode             searchFocusNode;
  final FocusNode             searchIconNode;
  final bool                  searchActive;
  final VoidCallback          onSearchToggle;
  final VoidCallback?         onDownArrow;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.tvH, AppSpacing.lg, AppSpacing.tvH, AppSpacing.sm,
      ),
      child: Row(
        children: [
          if (searchActive) ...[
            Expanded(
              child: Focus(
                skipTraversal:   true,
                canRequestFocus: false,
                onKeyEvent: (_, event) {
                  if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
                  if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                    onDownArrow?.call();
                    return KeyEventResult.handled;
                  }
                  if (event.logicalKey == LogicalKeyboardKey.escape ||
                      event.logicalKey == LogicalKeyboardKey.arrowUp) {
                    onSearchToggle();
                    searchIconNode.requestFocus();
                    return KeyEventResult.handled;
                  }
                  if (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
                      searchCtrl.text.isEmpty) {
                    onSearchToggle();
                    searchIconNode.requestFocus();
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: AnimatedContainer(
                  duration: AppDurations.focus,
                  curve:    AppCurves.easeOut,
                  height:   36,
                  decoration: BoxDecoration(
                    color:        AppColors.card,
                    borderRadius: BorderRadius.circular(10),
                    border:       Border.all(
                      color: AppColors.accentPrimary.withValues(alpha: 0.5),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      const Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 14),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          focusNode:       searchFocusNode,
                          controller:      searchCtrl,
                          textInputAction: TextInputAction.search,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                          decoration: const InputDecoration(
                            hintText:       'Search all channels',
                            hintStyle:      TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w300),
                            border:         InputBorder.none,
                            enabledBorder:  InputBorder.none,
                            focusedBorder:  InputBorder.none,
                            contentPadding: EdgeInsets.only(bottom: 2),
                            isDense:        true,
                            filled:         true,
                            fillColor:      Colors.transparent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                  ),
                ),
              ),
            ),
          ] else ...[
            _LiveDot(),
            const SizedBox(width: 8),
            const Text('Live TV',
              style: TextStyle(
                color:         AppColors.textPrimary,
                fontSize:      15,
                fontWeight:    FontWeight.w400,
                letterSpacing: -0.3,
              ),
            ),
            const Spacer(),
            Focus(
              onKeyEvent: (_, event) {
                if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
                if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                  onDownArrow?.call();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: FocusableWidget(
                focusNode:    searchIconNode,
                autofocus:    true,
                borderRadius: 8,
                onTap:        onSearchToggle,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:        AppColors.card,
                    borderRadius: BorderRadius.circular(8),
                    border:       Border.all(color: AppColors.glassBorder, width: 0.5),
                  ),
                  child: const Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 16),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pulsing Live Dot
// ─────────────────────────────────────────────────────────────────────────────

class _LiveDot extends StatefulWidget {
  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width:  6,
        height: 6,
        decoration: BoxDecoration(
          color: AppColors.success,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color:      AppColors.success.withValues(alpha: 0.4),
              blurRadius: 6,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Category Bar
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryBar extends StatefulWidget {
  const _CategoryBar({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.onSelect,
    required this.onUpArrow,
    required this.onDownArrow,
    this.firstItemFocusNode,
    this.onReorderConfirm,
  });
  final List<ChannelCategory>                    categories;
  final int?                                     selectedId;
  final void Function(int)                       onSelect;
  final VoidCallback                             onUpArrow;
  final VoidCallback                             onDownArrow;
  final FocusNode?                               firstItemFocusNode;
  final void Function(List<ChannelCategory>)?    onReorderConfirm;

  @override
  State<_CategoryBar> createState() => _CategoryBarState();
}

class _CategoryBarState extends State<_CategoryBar> {
  final Map<int, FocusNode> _nodes          = {};
  List<GlobalKey>           _keys           = [];
  int                       _focusedCatIdx  = -1;
  int                       _lastFocusedIdx = 0;

  FocusNode _nodeFor(int i) {
    return _nodes.putIfAbsent(i, () {
      final n = FocusNode();
      n.addListener(() {
        if (!mounted) return;
        if (n.hasFocus) {
          _lastFocusedIdx = i;
          setState(() => _focusedCatIdx = i);
          _scrollToKey(_keys[i]);
        } else {
          setState(() { if (_focusedCatIdx == i) _focusedCatIdx = -1; });
        }
      });
      return n;
    });
  }

  @override
  void initState() {
    super.initState();
    _keys = List.generate(widget.categories.length, (_) => GlobalKey());
    widget.firstItemFocusNode?.addListener(_onFirstFocus);
  }

  @override
  void didUpdateWidget(_CategoryBar old) {
    super.didUpdateWidget(old);
    if (widget.categories.length != old.categories.length) _rebuild();
    if (widget.firstItemFocusNode != old.firstItemFocusNode) {
      old.firstItemFocusNode?.removeListener(_onFirstFocus);
      widget.firstItemFocusNode?.addListener(_onFirstFocus);
    }
  }

  @override
  void dispose() {
    widget.firstItemFocusNode?.removeListener(_onFirstFocus);
    for (final n in _nodes.values) n.dispose();
    super.dispose();
  }

  void _onFirstFocus() {
    if (!mounted) return;
    final hasFocus = widget.firstItemFocusNode?.hasFocus == true;
    if (hasFocus) {
      _lastFocusedIdx = 0;
      setState(() => _focusedCatIdx = 0);
      if (_keys.isNotEmpty) _scrollToKey(_keys[0]);
    } else {
      setState(() { if (_focusedCatIdx == 0) _focusedCatIdx = -1; });
    }
  }

  void _rebuild() {
    for (final n in _nodes.values) n.dispose();
    _nodes.clear();
    _keys = List.generate(widget.categories.length, (_) => GlobalKey());
  }

  void _scrollToKey(GlobalKey key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = key.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration:  const Duration(milliseconds: 150),
          curve:     AppCurves.easeOut,
          alignment: 0.5,
        );
      }
    });
  }

  int get _focusedIndex {
    if (widget.firstItemFocusNode?.hasFocus == true) return 0;
    for (final entry in _nodes.entries) {
      if (entry.value.hasFocus) return entry.key;
    }
    return -1;
  }

  bool                    _reorderMode = false;
  int                     _reorderIdx  = -1;
  List<ChannelCategory>   _reorderList = [];

  void _startReorder(int idx) {
    setState(() {
      _reorderMode = true;
      _reorderIdx  = idx;
      _reorderList = List.from(widget.categories);
    });
  }

  void _moveReorder(int direction) {
    final newIdx = _reorderIdx + direction;
    if (newIdx < 0 || newIdx >= _reorderList.length) return;
    if (_reorderList[newIdx].id < 0) return;
    setState(() {
      final item = _reorderList.removeAt(_reorderIdx);
      _reorderList.insert(newIdx, item);
      _reorderIdx = newIdx;
    });
    final node = newIdx == 0 ? widget.firstItemFocusNode : _nodeFor(newIdx);
    node?.requestFocus();
    if (newIdx < _keys.length) _scrollToKey(_keys[newIdx]);
  }

  void _confirmReorder() {
    final list = _reorderList;
    setState(() { _reorderMode = false; _reorderIdx = -1; _reorderList = []; });
    widget.onReorderConfirm?.call(list);
  }

  void _cancelReorder() {
    final idx = _lastFocusedIdx;
    setState(() { _reorderMode = false; _reorderIdx = -1; _reorderList = []; });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (idx >= 0) _nodeFor(idx).requestFocus();
    });
  }

  void focusSelected() {
    if (widget.categories.isEmpty) return;
    if (_lastFocusedIdx <= 0) {
      widget.firstItemFocusNode?.requestFocus();
      if (_keys.isNotEmpty) _scrollToKey(_keys[0]);
    } else {
      _nodeFor(_lastFocusedIdx).requestFocus();
      if (_lastFocusedIdx < _keys.length) _scrollToKey(_keys[_lastFocusedIdx]);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.categories.isEmpty) return const SizedBox(height: 44);
    final cats = _reorderMode ? _reorderList : widget.categories;
    return Focus(
      onKeyEvent: (_, event) {
        if (!_reorderMode) return KeyEventResult.ignored;
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          _moveReorder(1); return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          _moveReorder(-1); return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.escape ||
            event.logicalKey == LogicalKeyboardKey.arrowUp ||
            event.logicalKey == LogicalKeyboardKey.arrowDown) {
          _cancelReorder(); return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Container(
        height: 44,
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.borderSubtle, width: 0.5),
          ),
        ),
        child: ScrollConfiguration(
          behavior: const ScrollBehavior().copyWith(scrollbars: false),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding:         const EdgeInsets.symmetric(horizontal: AppSpacing.tvH),
            itemCount:       cats.length,
            itemBuilder: (_, i) {
              final cat          = cats[i];
              final isSelected   = cat.id == widget.selectedId;
              final isFocused    = _focusedCatIdx == i;
              final isReordering = _reorderMode && i == _reorderIdx;
              final node         = i == 0 ? widget.firstItemFocusNode : _nodeFor(i);
              return Focus(
                key: _keys[i],
                onKeyEvent: (_, event) {
                  if (_reorderMode) return KeyEventResult.ignored;
                  if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
                  if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                    widget.onUpArrow(); return KeyEventResult.handled;
                  }
                  if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                    widget.onDownArrow(); return KeyEventResult.handled;
                  }
                  if (event.logicalKey == LogicalKeyboardKey.arrowLeft && i > 0) {
                    (i == 1 ? widget.firstItemFocusNode : _nodeFor(i - 1))?.requestFocus();
                    return KeyEventResult.handled;
                  }
                  if (event.logicalKey == LogicalKeyboardKey.arrowRight && i < cats.length - 1) {
                    _nodeFor(i + 1).requestFocus(); return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: FocusableWidget(
                  focusNode:       node,
                  autofocus:       i == 0,
                  borderRadius:    6,
                  showFocusBorder: false,
                  onTap:           _reorderMode
                      ? (i == _reorderIdx ? _confirmReorder : () {})
                      : () => widget.onSelect(cat.id),
                  onLongPress:     (!_reorderMode && cat.id > 0 && widget.onReorderConfirm != null)
                      ? () => _startReorder(i)
                      : null,
                  child: Container(
                    margin:  const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isReordering
                          ? AppColors.accentPrimary.withValues(alpha: 0.1)
                          : isSelected && isFocused
                              ? AppColors.accentSoft
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: isReordering
                          ? Border.all(color: AppColors.accentPrimary.withValues(alpha: 0.5), width: 1)
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          cat.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isReordering
                                ? AppColors.accentPrimary
                                : isSelected
                                    ? AppColors.textPrimary
                                    : isFocused
                                        ? AppColors.textSecondary
                                        : AppColors.textMuted,
                            fontSize:   12,
                            fontWeight: isSelected ? FontWeight.w500 : FontWeight.w300,
                            letterSpacing: isSelected ? -0.1 : 0,
                          ),
                        ),
                        if (isSelected && !isReordering) ...[
                          const SizedBox(width: 6),
                          Container(
                            width:  4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppColors.accentPrimary.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Channel List
// ─────────────────────────────────────────────────────────────────────────────

class _ChannelList extends StatefulWidget {
  const _ChannelList({
    super.key,
    required this.channels,
    required this.onUpFromFirst,
    required this.onChannelTap,
    required this.onToggleFavourite,
  });
  final List<Channel>               channels;
  final VoidCallback                onUpFromFirst;
  final void Function(Channel, int) onChannelTap;
  final void Function(Channel)      onToggleFavourite;

  @override
  State<_ChannelList> createState() => _ChannelListState();
}

class _ChannelListState extends State<_ChannelList> {
  final Map<int, FocusNode> _nodes      = {};
  final ScrollController    _scrollCtrl = ScrollController();
  int _restoreIndex = 0;

  static const double _rowH = 72.0;

  FocusNode _nodeFor(int i) => _nodes.putIfAbsent(i, () => FocusNode());

  @override
  void initState() {
    super.initState();
    _restoreIndex = FocusMemoryService.instance.restore('live_tv') ?? 0;
    if (_restoreIndex >= widget.channels.length) _restoreIndex = 0;
  }

  @override
  void didUpdateWidget(_ChannelList old) {
    super.didUpdateWidget(old);
    if (widget.channels.length != old.channels.length ||
        !_sameChannelIds(widget.channels, old.channels)) {
      for (final n in _nodes.values) n.dispose();
      _nodes.clear();
    }
  }

  bool _sameChannelIds(List<Channel> a, List<Channel> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  @override
  void dispose() {
    for (final n in _nodes.values) n.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  int get _focusedIndex {
    for (final entry in _nodes.entries) {
      if (entry.value.hasFocus) return entry.key;
    }
    return -1;
  }

  void _moveTo(int idx) {
    if (idx < 0 || idx >= widget.channels.length) return;
    _nodeFor(idx).requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureVisible(idx));
  }

  void focusFirst() => _moveTo(_restoreIndex > 0 ? _restoreIndex : 0);

  void _ensureVisible(int idx) {
    if (!_scrollCtrl.hasClients) return;
    final itemTop    = idx * _rowH;
    final itemBottom = itemTop + _rowH;
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
        curve:    AppCurves.easeOut,
      );
    }
  }

  KeyEventResult _handleKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final idx = _focusedIndex;
    if (idx < 0) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _moveTo(idx + 1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (idx > 0) {
        _moveTo(idx - 1);
        return KeyEventResult.handled;
      } else {
        widget.onUpFromFirst();
        return KeyEventResult.handled;
      }
    }
    if (event.logicalKey == LogicalKeyboardKey.contextMenu) {
      if (idx < widget.channels.length) {
        widget.onToggleFavourite(widget.channels[idx]);
        return KeyEventResult.handled;
      }
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
          itemExtent: _rowH,
          padding:    const EdgeInsets.only(top: AppSpacing.xs),
          itemBuilder: (_, i) {
            final ch = widget.channels[i];
            return _ChannelRow(
              channel:           ch,
              focusNode:         _nodeFor(i),
              autofocus:         false,
              onTap:             () => widget.onChannelTap(ch, i),
              onToggleFavourite: () => widget.onToggleFavourite(ch),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Channel Row
// ─────────────────────────────────────────────────────────────────────────────

class _ChannelRow extends StatefulWidget {
  const _ChannelRow({
    required this.channel,
    required this.onTap,
    required this.focusNode,
    required this.onToggleFavourite,
    this.autofocus = false,
  });
  final Channel      channel;
  final VoidCallback onTap;
  final FocusNode    focusNode;
  final VoidCallback onToggleFavourite;
  final bool         autofocus;

  @override
  State<_ChannelRow> createState() => _ChannelRowState();
}

class _ChannelRowState extends State<_ChannelRow> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(_ChannelRow old) {
    super.didUpdateWidget(old);
    if (old.focusNode != widget.focusNode) {
      old.focusNode.removeListener(_onFocusChange);
      widget.focusNode.addListener(_onFocusChange);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) setState(() => _focused = widget.focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    return FocusableWidget(
      focusNode:       widget.focusNode,
      autofocus:       widget.autofocus,
      showFocusBorder: false,
      onTap:           widget.onTap,
      onLongPress:     widget.onToggleFavourite,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        curve:    AppCurves.easeOut,
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.tvH),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 10),
        decoration: BoxDecoration(
          color:        _focused ? AppColors.card : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: _focused
              ? Border.all(color: AppColors.glassBorder, width: 0.5)
              : null,
        ),
        child: Row(
          children: [
            // Left accent bar (only when focused)
            AnimatedContainer(
              duration: AppDurations.fast,
              width:    2,
              height:   _focused ? 28 : 0,
              margin:   const EdgeInsets.only(right: AppSpacing.md),
              decoration: BoxDecoration(
                color:        _focused ? AppColors.accentPrimary : Colors.transparent,
                borderRadius: BorderRadius.circular(1),
              ),
            ),

            // Logo
            AnimatedContainer(
              duration: AppDurations.fast,
              width:  48,
              height: 48,
              decoration: BoxDecoration(
                color:        _focused ? AppColors.cardElevated : AppColors.card,
                borderRadius: BorderRadius.circular(10),
                border:       Border.all(
                  color: _focused ? AppColors.borderGold : AppColors.glassBorder,
                  width: 0.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9.5),
                child: widget.channel.logoUrl != null
                    ? CachedNetworkImage(
                        imageUrl:    widget.channel.logoUrl!,
                        fit:         BoxFit.contain,
                        errorWidget: (_, __, ___) =>
                            _LetterAvatar(name: widget.channel.name),
                      )
                    : _LetterAvatar(name: widget.channel.name),
              ),
            ),
            const SizedBox(width: AppSpacing.md),

            // Name
            Expanded(
              child: Text(
                widget.channel.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color:      _focused ? AppColors.textPrimary : AppColors.textSecondary,
                  fontSize:   13,
                  fontWeight: _focused ? FontWeight.w400 : FontWeight.w300,
                  letterSpacing: _focused ? -0.1 : 0,
                ),
              ),
            ),

            // Favourite
            if (widget.channel.isFavourite)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Icon(
                  Icons.favorite_rounded,
                  color: _focused
                      ? AppColors.accentPrimary.withValues(alpha: 0.7)
                      : AppColors.textMuted.withValues(alpha: 0.4),
                  size: 12,
                ),
              ),

            // Chevron
            Icon(
              Icons.chevron_right_rounded,
              color: _focused
                  ? AppColors.accentPrimary.withValues(alpha: 0.5)
                  : AppColors.textMuted.withValues(alpha: 0.2),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Letter Avatar
// ─────────────────────────────────────────────────────────────────────────────

class _LetterAvatar extends StatelessWidget {
  const _LetterAvatar({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final letter = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      color:     AppColors.card,
      alignment: Alignment.center,
      child: Text(
        letter,
        style: const TextStyle(
          color:         AppColors.textMuted,
          fontSize:      18,
          fontWeight:    FontWeight.w300,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}
