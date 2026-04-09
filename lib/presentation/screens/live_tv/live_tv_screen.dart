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
  final _backFocusNode     = FocusNode();
  final _searchFocusNode   = FocusNode();
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
    _backFocusNode.dispose();
    _searchFocusNode.dispose();
    _firstCatFocusNode.dispose();
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
      // Delay focus to avoid the select key-up from the category tap
      // leaking into the first channel row and triggering playback.
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _channelListKey.currentState?.focusFirst();
      });
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
        content: Text(newVal ? '${ch.name} added to Favourites' : '${ch.name} removed from Favourites'),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF1A1A1A),
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
              // ── Top bar ───────────────────────────────────────────────
              _TopBar(
                backFocusNode:     _backFocusNode,
                searchFocusNode:   _searchFocusNode,
                searchCtrl:        _searchCtrl,
                onDownArrow:       () => _firstCatFocusNode.requestFocus(),
                onBackRightArrow:  () => _searchFocusNode.requestFocus(),
                onSearchLeftArrow: () => _backFocusNode.requestFocus(),
              ),
              // ── Category chips ────────────────────────────────────────
              _CategoryBar(
                key:                _categoryBarKey,
                categories:         _categories,
                selectedId:         _selectedCatId,
                onSelect:           _selectCategory,
                firstItemFocusNode: _firstCatFocusNode,
                onUpArrow:          () => _searchFocusNode.requestFocus(),
                onDownArrow:        () => _channelListKey.currentState?.focusFirst(),
                onReorderConfirm:   _onChannelCategoryReorder,
              ),
              // ── Channel list ──────────────────────────────────────────
              Expanded(child: _buildChannelArea()),
            ],
          ),
        ),
      );
  }

  Widget _buildChannelArea() {
    if (_syncing || _loading) return const SkeletonChannelList();
    if (_error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
        const SizedBox(height: AppSpacing.md),
        FocusableWidget(onTap: _load,
          child: const Text('Retry',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13))),
      ]));
    }
    if (_filtered.isEmpty) {
      return const EmptyStateWidget(type: EmptyStateType.channels);
    }
    return _ChannelList(
      key:               _channelListKey,
      channels:          _filtered,
      onUpFromFirst:     () => _categoryBarKey.currentState?.focusSelected(),
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

// ── Top Bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.backFocusNode,
    required this.searchFocusNode,
    required this.searchCtrl,
    required this.onDownArrow,
    required this.onBackRightArrow,
    required this.onSearchLeftArrow,
  });
  final FocusNode             backFocusNode;
  final FocusNode             searchFocusNode;
  final TextEditingController searchCtrl;
  final VoidCallback          onDownArrow;
  final VoidCallback          onBackRightArrow;
  final VoidCallback          onSearchLeftArrow;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.tvH, vertical: AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          // Back button
          Focus(
            onKeyEvent: (_, event) {
              if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
              if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                onBackRightArrow();
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                onDownArrow();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: FocusableWidget(
              focusNode:    backFocusNode,
              autofocus:    true,
              borderRadius: AppSpacing.radiusPill,
              onTap:        () => context.pop(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color:        Colors.transparent,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                  border:       Border.all(color: AppColors.border, width: 1),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textSecondary, size: 11),
                    SizedBox(width: 5),
                    Text('Back', style: TextStyle(
                      color:         AppColors.textSecondary,
                      fontSize:      12,
                      fontWeight:    FontWeight.w400,
                      letterSpacing: 0.1,
                    )),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // Live dot + title
          _LiveDot(),
          const SizedBox(width: 7),
          const Text(
            'Live TV',
            style: TextStyle(
              color:         AppColors.textPrimary,
              fontSize:      14,
              fontWeight:    FontWeight.w500,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(width: AppSpacing.xl2),

          // Search pill
          Expanded(
            child: Focus(
              skipTraversal: true,
              canRequestFocus: false,
              onKeyEvent: (_, event) {
                if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
                if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                  onSearchLeftArrow();
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                  onDownArrow();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: AnimatedBuilder(
                animation: searchFocusNode,
                builder: (context, _) {
                  final focused = searchFocusNode.hasFocus;
                  return Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color:        AppColors.card,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                      border:       Border.all(
                        color: focused ? Colors.white : AppColors.border,
                        width: focused ? 1.0 : 0.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 14),
                        const Icon(Icons.search_rounded, color: AppColors.textMuted, size: 14),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            focusNode:       searchFocusNode,
                            controller:      searchCtrl,
                            textInputAction: TextInputAction.search,
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                            decoration: InputDecoration(
                              hintText:       'Search channels…',
                              hintStyle:      TextStyle(color: AppColors.textMuted, fontSize: 12),
                              border:         InputBorder.none,
                              enabledBorder:  InputBorder.none,
                              focusedBorder:  InputBorder.none,
                              contentPadding: const EdgeInsets.only(bottom: 2),
                              isDense:        true,
                              filled:         true,
                              fillColor:      Colors.transparent,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pulsing live dot ──────────────────────────────────────────────────────────

class _LiveDot extends StatefulWidget {
  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.75, end: 1.0).animate(
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
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width:  7,
        height: 7,
        decoration: const BoxDecoration(
          color: AppColors.success,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ── Category Bar ───────────────────────────────────────────────────────────────

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
          curve:     Curves.easeOut,
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

  // ── Reorder state machine ──────────────────────────────────────────────────

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
    if (_reorderList[newIdx].id < 0) return; // skip virtual categories
    setState(() {
      final item = _reorderList.removeAt(_reorderIdx);
      _reorderList.insert(newIdx, item);
      _reorderIdx = newIdx;
    });
    if (newIdx < _keys.length) _scrollToKey(_keys[newIdx]);
  }

  void _confirmReorder() {
    final list = _reorderList;
    setState(() { _reorderMode = false; _reorderIdx = -1; _reorderList = []; });
    widget.onReorderConfirm?.call(list);
  }

  void _cancelReorder() {
    setState(() { _reorderMode = false; _reorderIdx = -1; _reorderList = []; });
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
        // Let Select/Enter propagate to FocusableWidget.onTap for confirm
        return KeyEventResult.ignored;
      },
      child: SizedBox(
        height: 46,
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
                  borderRadius:    AppSpacing.radiusPill,
                  showFocusBorder: false,
                  onTap:           _reorderMode
                      ? (i == _reorderIdx ? _confirmReorder : () {})
                      : () => widget.onSelect(cat.id),
                  onLongPress:     (!_reorderMode && cat.id > 0 && widget.onReorderConfirm != null)
                      ? () => _startReorder(i)
                      : null,
                  child: Container(
                    decoration: isReordering ? BoxDecoration(
                      border:       Border.all(color: AppColors.accentPrimary, width: 1.5),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                    ) : null,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize:      MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Text(
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
                                fontSize:   13,
                                fontWeight: (isSelected || isReordering) ? FontWeight.w500 : FontWeight.w300,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          AnimatedContainer(
                            duration: AppDurations.medium,
                            curve:    Curves.easeOut,
                            height:   1.5,
                            width:    isSelected ? 18 : 0,
                            decoration: BoxDecoration(
                              color:        AppColors.accentPrimary,
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ],
                      ),
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

// ── Channel List ──────────────────────────────────────────────────────────────

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

  static const double _rowH = 76.0;

  FocusNode _nodeFor(int i) => _nodes.putIfAbsent(i, () => FocusNode());

  @override
  void initState() {
    super.initState();
    _restoreIndex = FocusMemoryService.instance.restore('live_tv') ?? 0;
    if (_restoreIndex >= widget.channels.length) _restoreIndex = 0;
    if (_restoreIndex > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _ensureVisible(_restoreIndex);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _nodeFor(_restoreIndex).requestFocus();
        });
      });
    }
  }

  @override
  void didUpdateWidget(_ChannelList old) {
    super.didUpdateWidget(old);
    if (widget.channels != old.channels) {
      for (final n in _nodes.values) n.dispose();
      _nodes.clear();
    }
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

  void focusFirst() => _moveTo(0);

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
        curve:    Curves.easeOut,
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
          itemBuilder: (_, i) {
            final ch = widget.channels[i];
            return _ChannelRow(
              channel:           ch,
              focusNode:         _nodeFor(i),
              autofocus:         i == 0 && _restoreIndex == 0,
              onTap:             () => widget.onChannelTap(ch, i),
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
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.tvH, vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: _focused ? AppColors.accentSoft : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: _focused ? AppColors.accentPrimary : Colors.transparent,
              width: 3.0,
            ),
            bottom: const BorderSide(color: AppColors.borderSubtle, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            // Logo
            AnimatedContainer(
              duration: AppDurations.fast,
              width:  54,
              height: 54,
              decoration: BoxDecoration(
                color:        AppColors.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _focused ? AppColors.borderGold : AppColors.border,
                  width: _focused ? 1.0 : 0.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(_focused ? 9 : 10),
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

            // Name
            Expanded(
              child: Text(
                widget.channel.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color:      _focused ? AppColors.textPrimary : AppColors.textSecondary,
                  fontSize:   14,
                  fontWeight: _focused ? FontWeight.w500 : FontWeight.w300,
                  height:     1.3,
                ),
              ),
            ),

            // Favourite indicator
            if (widget.channel.isFavourite)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.favorite,
                  color: _focused ? AppColors.accentPrimary : AppColors.accentSoft,
                  size: 12,
                ),
              ),

            // Play icon
            Icon(
              Icons.play_arrow_rounded,
              color: _focused ? AppColors.accentPrimary : AppColors.textMuted.withOpacity(0.5),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

// ── First Letter Placeholder ──────────────────────────────────────────────────

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
        style: const TextStyle(
          color:      AppColors.textSecondary,
          fontSize:   20,
          fontWeight: FontWeight.w300,
        ),
      ),
    );
  }
}
