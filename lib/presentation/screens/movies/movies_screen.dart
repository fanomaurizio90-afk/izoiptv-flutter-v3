import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/debounce.dart';
import '../../../domain/entities/vod.dart';
import '../../providers/providers.dart';
import '../../widgets/common/focusable_widget.dart';
import '../../widgets/common/skeleton_widget.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../../core/services/focus_memory_service.dart';
import '../../widgets/common/pin_dialog.dart';
import '../../../core/utils/parental_control.dart';

class MoviesScreen extends ConsumerStatefulWidget {
  const MoviesScreen({super.key});
  @override
  ConsumerState<MoviesScreen> createState() => _MoviesScreenState();
}

class _MoviesScreenState extends ConsumerState<MoviesScreen> {
  final _searchCtrl             = TextEditingController();
  final _debounce               = Debounce(duration: const Duration(milliseconds: 300));
  final _firstCategoryFocusNode = FocusNode();
  final _searchFocusNode        = FocusNode();
  final _backFocusNode          = FocusNode();
  final _contentListKey  = GlobalKey<_ContentListState>();
  final _categoryBarKey  = GlobalKey<_CategoryBarState>();

  List<VodCategory> _categories    = [];
  int?              _selectedCatId;
  List<VodItem>     _items         = [];
  List<VodItem>     _searchResults = [];
  bool              _loading       = true;
  bool              _syncing       = false;
  String?           _error;
  bool              _searching     = false;

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
    _firstCategoryFocusNode.dispose();
    _searchFocusNode.dispose();
    _backFocusNode.dispose();
    super.dispose();
  }

  void _onSearch() {
    _debounce(() {
      final q = _searchCtrl.text.trim();
      if (!mounted) return;
      if (q.isEmpty) {
        setState(() { _searching = false; _searchResults = []; });
      } else {
        setState(() {
          _searching     = true;
          _searchResults = _items.where((v) => v.name.toLowerCase().contains(q.toLowerCase())).toList();
        });
      }
    });
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; _syncing = false; });
    try {
      final repo = ref.read(vodRepositoryProvider);
      var cats = await repo.getCategories();
      if (cats.isEmpty) {
        setState(() { _loading = false; _syncing = true; });
        await repo.syncVod();
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
      final catId = (_selectedCatId != null && cats.any((c) => c.id == _selectedCatId))
          ? _selectedCatId! : cats.first.id;
      final items = await repo.getVodByCategory(catId);
      if (!mounted) return;
      setState(() {
        _categories    = cats;
        _selectedCatId = catId;
        _items         = items;
        _loading       = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _syncing = false; _error = e.toString(); });
    }
  }

  Future<void> _selectCategory(int catId) async {
    setState(() { _selectedCatId = catId; _loading = true; });
    _searchCtrl.clear();
    try {
      final items = await ref.read(vodRepositoryProvider).getVodByCategory(catId);
      if (!mounted) return;
      setState(() { _items = items; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
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
                backFocusNode:   _backFocusNode,
                searchFocusNode: _searchFocusNode,
                onDownArrow:     () => _firstCategoryFocusNode.requestFocus(),
              ),
              if (_categories.isNotEmpty) _CategoryBar(
                key:                _categoryBarKey,
                categories:         _categories,
                selectedId:         _selectedCatId,
                onSelect:           _selectCategory,
                firstItemFocusNode: _firstCategoryFocusNode,
                onDownArrow:        (x) => _contentListKey.currentState?.focusClosestColumnTo(x ?? 0),
                onUpArrow:          () => _backFocusNode.requestFocus(),
              ),
              Expanded(child: _buildContent()),
            ],
          ),
        ),
      );
  }

  Widget _buildContent() {
    final cols = MediaQuery.of(context).size.width >= 900 ? 5 : 3;
    if (_syncing || _loading) return SkeletonPosterGrid(columns: cols);
    if (_error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.error_outline_rounded, color: AppColors.error, size: 22),
        const SizedBox(height: AppSpacing.md),
        Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
        const SizedBox(height: AppSpacing.md),
        FocusableWidget(
          borderRadius: AppSpacing.radiusCard,
          onTap: _load,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
            decoration: BoxDecoration(
              border:       Border.all(color: AppColors.border, width: 0.5),
              borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
            ),
            child: const Text('Retry',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ),
        ),
      ]));
    }
    final display = _searching ? _searchResults : _items;
    if (display.isEmpty) {
      return EmptyStateWidget(
        type:       _searching ? EmptyStateType.search : EmptyStateType.movies,
        searchTerm: _searchCtrl.text.trim(),
      );
    }
    return _ContentList(
      key:              _contentListKey,
      items:            display,
      columns:          cols,
      categories:       _categories,
      focusMemoryKey:   'movies',
      onUpFromFirstRow: (x) => _categoryBarKey.currentState?.focusClosestTo(x),
      onTap:            (vod) async {
        final cat = _categories.firstWhere(
          (c) => c.id == vod.categoryId,
          orElse: () => const VodCategory(id: 0, name: ''),
        );
        if (isAdultCategory(cat.name) || isAdultCategory(vod.name)) {
          final ok = await showPinDialog(context);
          if (!ok || !mounted) return;
        }
        if (!mounted) return;
        await context.push('/movies/player', extra: {
          'vod':      vod,
          'backPath': '/movies',
        });
        if (mounted) _contentListKey.currentState?.restoreFocus();
      },
    );
  }
}

class _ContentList extends StatefulWidget {
  const _ContentList({
    super.key,
    required this.items,
    required this.columns,
    required this.categories,
    required this.onTap,
    required this.onUpFromFirstRow,
    this.focusMemoryKey,
  });
  final List<VodItem>          items;
  final int                    columns;
  final List<VodCategory>      categories;
  final void Function(VodItem) onTap;
  final void Function(double)  onUpFromFirstRow;
  final String?                focusMemoryKey;

  @override
  State<_ContentList> createState() => _ContentListState();
}

class _ContentListState extends State<_ContentList> {
  final Map<int, FocusNode> _nodes     = {};
  final ScrollController    _scrollCtrl = ScrollController();
  double _availableWidth               = 0.0;
  int    _restoreIndex                 = 0;

  @override
  void initState() {
    super.initState();
    if (widget.focusMemoryKey != null) {
      _restoreIndex = FocusMemoryService.instance.restore(widget.focusMemoryKey!) ?? 0;
      if (_restoreIndex >= widget.items.length) _restoreIndex = 0;
    }
    if (_restoreIndex > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _nodeFor(_restoreIndex).requestFocus();
            _ensureVisible(_restoreIndex);
          }
        });
      });
    }
  }

  @override
  void didUpdateWidget(_ContentList old) {
    super.didUpdateWidget(old);
    if (widget.items != old.items) {
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

  FocusNode _nodeFor(int i) => _nodes.putIfAbsent(i, () => FocusNode());

  void restoreFocus() {
    if (widget.focusMemoryKey == null) return;
    final idx = FocusMemoryService.instance.restore(widget.focusMemoryKey!);
    if (idx == null || idx >= widget.items.length) return;
    _ensureVisible(idx);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nodeFor(idx).requestFocus();
    });
  }

  int get _focusedIndex {
    for (final entry in _nodes.entries) {
      if (entry.value.hasFocus) return entry.key;
    }
    return -1;
  }

  void _move(int to) {
    if (to < 0 || to >= widget.items.length) return;
    _nodeFor(to).requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureVisible(to));
  }

  void focusClosestColumnTo(double targetX) {
    if (widget.items.isEmpty || _availableWidth == 0) { _move(0); return; }
    final cols      = widget.columns;
    final itemWidth = (_availableWidth - AppSpacing.tvH * 2 - (cols - 1) * AppSpacing.sm) / cols;
    double bestDist = double.infinity;
    int    bestCol  = 0;
    for (int col = 0; col < cols; col++) {
      final centerX = AppSpacing.tvH + col * (itemWidth + AppSpacing.sm) + itemWidth / 2;
      final dist    = (centerX - targetX).abs();
      if (dist < bestDist) { bestDist = dist; bestCol = col; }
    }
    _move(bestCol.clamp(0, widget.items.length - 1));
  }

  void _ensureVisible(int index) {
    if (!_scrollCtrl.hasClients || _availableWidth == 0) return;
    final cols       = widget.columns;
    final itemWidth  = (_availableWidth - AppSpacing.tvH * 2 - (cols - 1) * AppSpacing.sm) / cols;
    final itemHeight = itemWidth * 3 / 2;
    final rowHeight  = itemHeight + AppSpacing.sm;
    final row        = index ~/ cols;
    final itemTop    = AppSpacing.lg + row * rowHeight;
    final itemBottom = itemTop + itemHeight;
    final viewport   = _scrollCtrl.position.viewportDimension;
    final offset     = _scrollCtrl.offset;
    const pad        = 16.0;
    double? target;
    if (itemTop < offset + pad) {
      target = itemTop - pad;
    } else if (itemBottom > offset + viewport - pad) {
      target = itemBottom - viewport + pad;
    }
    if (target != null) {
      _scrollCtrl.animateTo(
        target.clamp(0.0, _scrollCtrl.position.maxScrollExtent),
        duration: const Duration(milliseconds: 180),
        curve:    Curves.easeOut,
      );
    }
  }

  KeyEventResult _handleGridKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final idx = _focusedIndex;
    if (idx < 0) return KeyEventResult.ignored;
    final col = idx % widget.columns;

    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (col < widget.columns - 1 && idx + 1 < widget.items.length) {
        _move(idx + 1);
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (col > 0) {
        _move(idx - 1);
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _move(idx + widget.columns);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (idx - widget.columns >= 0) {
        _move(idx - widget.columns);
      } else {
        final cols      = widget.columns;
        final col       = idx % cols;
        final itemWidth = _availableWidth > 0
            ? (_availableWidth - AppSpacing.tvH * 2 - (cols - 1) * AppSpacing.sm) / cols
            : 0.0;
        widget.onUpFromFirstRow(
          AppSpacing.tvH + col * (itemWidth + AppSpacing.sm) + itemWidth / 2,
        );
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        _availableWidth = constraints.maxWidth;
        return Focus(
          onKeyEvent:    _handleGridKey,
          skipTraversal: true,
          child: GridView.builder(
            controller: _scrollCtrl,
            padding: EdgeInsets.fromLTRB(
              AppSpacing.tvH, AppSpacing.lg, AppSpacing.tvH, AppSpacing.xl3,
            ),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount:   widget.columns,
              crossAxisSpacing: AppSpacing.sm,
              mainAxisSpacing:  AppSpacing.sm,
              childAspectRatio: 2 / 3,
            ),
            itemCount:   widget.items.length,
            itemBuilder: (_, i) => FocusableWidget(
              focusNode:    _nodeFor(i),
              autofocus:    i == _restoreIndex,
              borderRadius: AppSpacing.radiusCard,
              onTap:        () {
                if (widget.focusMemoryKey != null) {
                  FocusMemoryService.instance.save(widget.focusMemoryKey!, i);
                }
                widget.onTap(widget.items[i]);
              },
              child:        _PosterCard(vod: widget.items[i]),
            ),
          ),
        );
      },
    );
  }
}

// ── Poster Card ────────────────────────────────────────────────────────────────

class _PosterCard extends StatelessWidget {
  const _PosterCard({required this.vod});
  final VodItem vod;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background fill
          Container(color: AppColors.card),

          // Poster image
          if (vod.posterUrl != null)
            CachedNetworkImage(
              imageUrl:    vod.posterUrl!,
              fit:         BoxFit.cover,
              errorWidget: (_, __, ___) => _PlaceholderArt(name: vod.name),
            )
          else
            _PlaceholderArt(name: vod.name),

          // Bottom gradient + title
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin:  Alignment.topCenter,
                  end:    Alignment.bottomCenter,
                  stops:  [0.0, 0.4, 1.0],
                  colors: [Colors.transparent, Color(0xAA070709), Color(0xF8070709)],
                ),
              ),
              padding: const EdgeInsets.fromLTRB(8, 28, 8, 9),
              child: Text(
                vod.name,
                maxLines:  2,
                overflow:  TextOverflow.ellipsis,
                textAlign: TextAlign.left,
                style: const TextStyle(
                  color:      AppColors.textPrimary,
                  fontSize:   11,
                  fontWeight: FontWeight.w400,
                  height:     1.4,
                  letterSpacing: -0.1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceholderArt extends StatelessWidget {
  const _PlaceholderArt({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.card,
      child: Center(
        child: Icon(Icons.movie_outlined, color: AppColors.textMuted.withOpacity(0.35), size: 22),
      ),
    );
  }
}

// ── Top Bar ────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.searchCtrl,
    required this.backFocusNode,
    required this.searchFocusNode,
    this.onDownArrow,
  });
  final TextEditingController searchCtrl;
  final FocusNode             backFocusNode;
  final FocusNode             searchFocusNode;
  final VoidCallback?         onDownArrow;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.tvH, AppSpacing.md, AppSpacing.tvH, AppSpacing.md),
      child: Row(
        children: [
          // Back button
          FocusableWidget(
            focusNode:    backFocusNode,
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
                    'Movies',
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

          const SizedBox(width: AppSpacing.xl),

          // Search field
          Expanded(
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color:        AppColors.card,
                borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                border:       Border.all(color: AppColors.border, width: 0.5),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  const Icon(Icons.search_rounded, color: AppColors.textMuted, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Focus(
                      focusNode: searchFocusNode,
                      onKeyEvent: (_, event) {
                        if ((event is KeyDownEvent || event is KeyRepeatEvent) &&
                            event.logicalKey == LogicalKeyboardKey.arrowDown) {
                          onDownArrow?.call();
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                      child: TextField(
                        controller: searchCtrl,
                        style: const TextStyle(
                          color:      AppColors.textPrimary,
                          fontSize:   12,
                          fontWeight: FontWeight.w300,
                        ),
                        decoration: const InputDecoration(
                          hintText:       'Search movies…',
                          hintStyle:      TextStyle(color: AppColors.textMuted, fontSize: 12),
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
                  ),
                  const SizedBox(width: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Category Bar ──────────────────────────────────────────────────────────────

class _CategoryBar extends StatefulWidget {
  const _CategoryBar({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.onSelect,
    required this.onDownArrow,
    required this.onUpArrow,
    this.firstItemFocusNode,
  });
  final List<VodCategory>       categories;
  final int?                    selectedId;
  final void Function(int)      onSelect;
  final void Function(double?)  onDownArrow;
  final VoidCallback            onUpArrow;
  final FocusNode?              firstItemFocusNode;

  @override
  State<_CategoryBar> createState() => _CategoryBarState();
}

class _CategoryBarState extends State<_CategoryBar> {
  List<FocusNode> _nodes = [];
  List<GlobalKey> _keys  = [];
  int _focusedCatIdx     = -1;

  @override
  void initState() {
    super.initState();
    _rebuild();
    widget.firstItemFocusNode?.addListener(_onFirstFocus);
  }

  @override
  void didUpdateWidget(_CategoryBar old) {
    super.didUpdateWidget(old);
    if (widget.categories.length != _nodes.length + 1) _rebuild();
    if (widget.firstItemFocusNode != old.firstItemFocusNode) {
      old.firstItemFocusNode?.removeListener(_onFirstFocus);
      widget.firstItemFocusNode?.addListener(_onFirstFocus);
    }
  }

  @override
  void dispose() {
    widget.firstItemFocusNode?.removeListener(_onFirstFocus);
    for (final n in _nodes) n.dispose();
    super.dispose();
  }

  void _onFirstFocus() {
    if (!mounted) return;
    final hasFocus = widget.firstItemFocusNode?.hasFocus == true;
    setState(() => _focusedCatIdx = hasFocus ? 0 : (_focusedCatIdx == 0 ? -1 : _focusedCatIdx));
    if (!hasFocus) return;
    final selIdx = widget.categories.indexWhere((c) => c.id == widget.selectedId);
    if (selIdx > 0 && selIdx <= _nodes.length) {
      _nodes[selIdx - 1].requestFocus();
    } else {
      _scrollToKey(_keys[0]);
    }
  }

  void _rebuild() {
    for (final n in _nodes) n.dispose();
    _keys  = List.generate(widget.categories.length, (_) => GlobalKey());
    _nodes = [];
    for (int i = 1; i < widget.categories.length; i++) {
      final key  = _keys[i];
      final idx  = i;
      final n    = FocusNode();
      n.addListener(() {
        if (mounted) setState(() => _focusedCatIdx = n.hasFocus ? idx : (_focusedCatIdx == idx ? -1 : _focusedCatIdx));
        if (n.hasFocus && mounted) _scrollToKey(key);
      });
      _nodes.add(n);
    }
  }

  void _scrollToKey(GlobalKey key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = key.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx,
          duration:  const Duration(milliseconds: 150),
          curve:     Curves.easeOut,
          alignment: 0.5,
        );
      }
    });
  }

  int get _focusedIndex {
    if (widget.firstItemFocusNode?.hasFocus == true) return 0;
    for (int i = 0; i < _nodes.length; i++) {
      if (_nodes[i].hasFocus) return i + 1;
    }
    return -1;
  }

  double? _getCenterX(int i) {
    final ctx = _keys[i].currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return null;
    final pos = box.localToGlobal(Offset.zero);
    return pos.dx + box.size.width / 2;
  }

  void focusClosestTo(double targetX) {
    double bestDist = double.infinity;
    int    bestIdx  = 0;
    for (int i = 0; i < widget.categories.length; i++) {
      final cx = _getCenterX(i);
      if (cx == null) continue;
      final dist = (cx - targetX).abs();
      if (dist < bestDist) { bestDist = dist; bestIdx = i; }
    }
    final node = bestIdx == 0 ? widget.firstItemFocusNode : _nodes[bestIdx - 1];
    node?.requestFocus();
    _scrollToKey(_keys[bestIdx]);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding:         EdgeInsets.symmetric(horizontal: AppSpacing.tvH),
        itemCount:       widget.categories.length,
        itemBuilder:     (_, i) {
          final cat        = widget.categories[i];
          final isSelected = cat.id == widget.selectedId;
          final isFocused  = _focusedCatIdx == i;
          final node       = i == 0 ? widget.firstItemFocusNode : _nodes[i - 1];
          return Focus(
            key: _keys[i],
            onKeyEvent: (_, event) {
              if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
              if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                if (i < widget.categories.length - 1) {
                  _nodes[i].requestFocus();
                }
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                if (i > 0) {
                  (i == 1 ? widget.firstItemFocusNode : _nodes[i - 2])?.requestFocus();
                }
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                widget.onDownArrow(_getCenterX(i));
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                widget.onUpArrow();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: FocusableWidget(
              autofocus:       i == 0,
              focusNode:       node,
              showFocusBorder: false,
              onTap:           () => widget.onSelect(cat.id),
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize:      MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Text(
                        cat.name,
                        style: TextStyle(
                          color: isSelected
                              ? AppColors.textPrimary
                              : isFocused
                                  ? AppColors.textSecondary
                                  : AppColors.textMuted,
                          fontSize:   12,
                          fontWeight: isSelected ? FontWeight.w500 : FontWeight.w300,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    AnimatedContainer(
                      duration: AppDurations.medium,
                      curve:    Curves.easeOut,
                      height:   1.5,
                      width:    isSelected ? 16 : 0,
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
        },
      ),
    );
  }
}
