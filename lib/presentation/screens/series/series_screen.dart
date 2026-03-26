import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/debounce.dart';
import '../../../domain/entities/series.dart';
import '../../providers/providers.dart';
import '../../widgets/common/focusable_widget.dart';
import '../../widgets/common/skeleton_widget.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/common/pin_dialog.dart';
import '../../../core/utils/parental_control.dart';

class SeriesScreen extends ConsumerStatefulWidget {
  const SeriesScreen({super.key});
  @override
  ConsumerState<SeriesScreen> createState() => _SeriesScreenState();
}

class _SeriesScreenState extends ConsumerState<SeriesScreen> {
  final _searchCtrl             = TextEditingController();
  final _debounce               = Debounce(duration: const Duration(milliseconds: 300));
  final _firstCategoryFocusNode = FocusNode();
  final _searchFocusNode        = FocusNode();
  final _backFocusNode          = FocusNode();
  FocusNode? _firstGridFocusNode;

  List<SeriesCategory> _categories    = [];
  int?                 _selectedCatId;
  List<SeriesItem>     _items         = [];
  List<SeriesItem>     _searchResults = [];
  bool                 _loading       = true;
  bool                 _syncing       = false;
  String?              _error;
  bool                 _searching     = false;

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
          _searchResults = _items.where((s) => s.name.toLowerCase().contains(q.toLowerCase())).toList();
        });
      }
    });
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; _syncing = false; });
    try {
      final repo = ref.read(seriesRepositoryProvider);
      var cats = await repo.getCategories();
      if (cats.isEmpty) {
        setState(() { _loading = false; _syncing = true; });
        await repo.syncSeries();
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
          ? _selectedCatId!
          : cats.first.id;
      final items = await repo.getSeriesByCategory(catId);
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
      final items = await ref.read(seriesRepositoryProvider).getSeriesByCategory(catId);
      if (!mounted) return;
      setState(() { _items = items; _loading = false; _searching = false; _searchResults = []; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) context.go('/home');
      },
      child: Scaffold(
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
              categories:         _categories,
              selectedId:         _selectedCatId,
              onSelect:           _selectCategory,
              firstItemFocusNode: _firstCategoryFocusNode,
              onRightArrow:       () => _firstGridFocusNode?.requestFocus(),
            ),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
      ), // Scaffold
    ); // PopScope
  }

  Widget _buildContent() {
    final cols = MediaQuery.of(context).size.width >= 900 ? 5 : 3;
    if (_syncing || _loading) return SkeletonPosterGrid(columns: cols);
    if (_error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
        const SizedBox(height: AppSpacing.md),
        GestureDetector(onTap: _load,
          child: Text('Retry', style: GoogleFonts.dmSans(color: AppColors.textSecondary, fontSize: 13))),
      ]));
    }
    final display = _searching ? _searchResults : _items;
    if (display.isEmpty) {
      return EmptyStateWidget(
        type:       _searching ? EmptyStateType.search : EmptyStateType.series,
        searchTerm: _searchCtrl.text.trim(),
      );
    }
    return _ContentList(
      items:             display,
      columns:           cols,
      categories:        _categories,
      categoryFocusNode: _firstCategoryFocusNode,
      onFirstNodeReady:  (node) { _firstGridFocusNode = node; },
      onTap:             (s) async {
        final cat = _categories.firstWhere(
          (c) => c.id == s.categoryId,
          orElse: () => const SeriesCategory(id: 0, name: ''),
        );
        if (isAdultCategory(cat.name) || isAdultCategory(s.name)) {
          final ok = await showPinDialog(context);
          if (!ok || !mounted) return;
        }
        if (mounted) context.push('/series/${s.id}', extra: s);
      },
    );
  }
}

class _ContentList extends StatefulWidget {
  const _ContentList({
    required this.items,
    required this.columns,
    required this.categories,
    required this.onTap,
    required this.onFirstNodeReady,
    this.categoryFocusNode,
  });
  final List<SeriesItem>          items;
  final int                       columns;
  final List<SeriesCategory>      categories;
  final void Function(SeriesItem) onTap;
  final void Function(FocusNode)  onFirstNodeReady;
  final FocusNode?                categoryFocusNode;

  @override
  State<_ContentList> createState() => _ContentListState();
}

class _ContentListState extends State<_ContentList> {
  List<FocusNode>        _nodes     = [];
  final ScrollController _scrollCtrl = ScrollController();
  double _availableWidth             = 0.0;

  @override
  void initState() {
    super.initState();
    _nodes = List.generate(widget.items.length, (_) => FocusNode());
    _notifyFirstNode();
  }

  @override
  void didUpdateWidget(_ContentList old) {
    super.didUpdateWidget(old);
    if (widget.items.length != _nodes.length) {
      for (final n in _nodes) n.dispose();
      _nodes = List.generate(widget.items.length, (_) => FocusNode());
      _notifyFirstNode();
    }
  }

  void _notifyFirstNode() {
    if (_nodes.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onFirstNodeReady(_nodes[0]);
      });
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

  void _move(int to) {
    if (to < 0 || to >= _nodes.length) return;
    _nodes[to].requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureVisible(to));
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
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final idx = _focusedIndex;
    if (idx < 0) return KeyEventResult.ignored;
    final col = idx % widget.columns;

    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _move(idx + 1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (col > 0) {
        _move(idx - 1);
      } else {
        widget.categoryFocusNode?.requestFocus();
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
        widget.categoryFocusNode?.requestFocus();
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
        return SingleChildScrollView(
          controller: _scrollCtrl,
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.lg),
              Focus(
                onKeyEvent:    _handleGridKey,
                skipTraversal: true,
                child: GridView.builder(
                  shrinkWrap:   true,
                  physics:      const NeverScrollableScrollPhysics(),
                  padding:      const EdgeInsets.symmetric(horizontal: AppSpacing.tvH),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount:   widget.columns,
                    crossAxisSpacing: AppSpacing.sm,
                    mainAxisSpacing:  AppSpacing.sm,
                    childAspectRatio: 2 / 3,
                  ),
                  itemCount:   widget.items.length,
                  itemBuilder: (_, i) => FocusableWidget(
                    focusNode:    _nodes[i],
                    autofocus:    i == 0,
                    borderRadius: AppSpacing.radiusCard,
                    onTap:        () => widget.onTap(widget.items[i]),
                    child:        _PosterCard(series: widget.items[i]),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl3),
            ],
          ),
        );
      },
    );
  }
}

// ── Poster Card ────────────────────────────────────────────────────────────────

class _PosterCard extends StatelessWidget {
  const _PosterCard({required this.series});
  final SeriesItem series;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: AppColors.card),
          if (series.posterUrl != null)
            CachedNetworkImage(
              imageUrl:    series.posterUrl!,
              fit:         BoxFit.cover,
              errorWidget: (_, __, ___) => const Center(
                child: Icon(Icons.tv, color: AppColors.textMuted, size: 22),
              ),
            )
          else
            const Center(child: Icon(Icons.tv, color: AppColors.textMuted, size: 22)),
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin:  Alignment.topCenter,
                  end:    Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xF0080808)],
                ),
              ),
              padding: const EdgeInsets.fromLTRB(6, 20, 6, 6),
              child: Text(
                series.name,
                maxLines:  2,
                overflow:  TextOverflow.ellipsis,
                textAlign: TextAlign.left,
                style: GoogleFonts.dmSans(
                  color:      AppColors.textPrimary,
                  fontSize:   10,
                  fontWeight: FontWeight.w400,
                  height:     1.35,
                ),
              ),
            ),
          ),
        ],
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.tvH, vertical: AppSpacing.md),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          FocusableWidget(
            focusNode: backFocusNode,
            onTap:     () => context.pop(),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.arrow_back, color: AppColors.textSecondary, size: 18),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            'Series',
            style: GoogleFonts.dmSans(
              color:      AppColors.textPrimary,
              fontSize:   14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: AppSpacing.xl2),
          Expanded(
            child: Focus(
              focusNode: searchFocusNode,
              onKeyEvent: (_, event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.arrowDown) {
                  onDownArrow?.call();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: TextField(
                controller: searchCtrl,
                style: GoogleFonts.dmSans(color: AppColors.textPrimary, fontSize: 12),
                decoration: InputDecoration(
                  hintText:       'Search in this category...',
                  hintStyle:      GoogleFonts.dmSans(color: AppColors.textMuted, fontSize: 12),
                  border:         InputBorder.none,
                  enabledBorder:  InputBorder.none,
                  focusedBorder:  InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense:        true,
                  filled:         true,
                  fillColor:      Colors.transparent,
                ),
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
    required this.categories,
    required this.selectedId,
    required this.onSelect,
    required this.onRightArrow,
    this.firstItemFocusNode,
  });
  final List<SeriesCategory> categories;
  final int?                 selectedId;
  final void Function(int)   onSelect;
  final VoidCallback         onRightArrow;
  final FocusNode?           firstItemFocusNode;

  @override
  State<_CategoryBar> createState() => _CategoryBarState();
}

class _CategoryBarState extends State<_CategoryBar> {
  List<FocusNode> _nodes = [];
  List<GlobalKey> _keys  = [];

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
    if (widget.firstItemFocusNode?.hasFocus == true && mounted) {
      _scrollToKey(_keys[0]);
    }
  }

  void _rebuild() {
    for (final n in _nodes) n.dispose();
    _keys  = List.generate(widget.categories.length, (_) => GlobalKey());
    _nodes = [];
    for (int i = 1; i < widget.categories.length; i++) {
      final key = _keys[i];
      final n   = FocusNode();
      n.addListener(() {
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

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding:         const EdgeInsets.symmetric(horizontal: AppSpacing.tvH),
        itemCount:       widget.categories.length,
        itemBuilder:     (_, i) {
          final cat        = widget.categories[i];
          final isSelected = cat.id == widget.selectedId;
          final node       = i == 0 ? widget.firstItemFocusNode : _nodes[i - 1];
          return Focus(
            key: _keys[i],
            onKeyEvent: (_, event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.arrowRight &&
                  i == widget.categories.length - 1) {
                widget.onRightArrow();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: FocusableWidget(
              autofocus: i == 0,
              focusNode: node,
              onTap:     () => widget.onSelect(cat.id),
              child: Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xl2),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        cat.name,
                        style: GoogleFonts.dmSans(
                          color:      isSelected ? AppColors.textPrimary : AppColors.textMuted,
                          fontSize:   12,
                          fontWeight: isSelected ? FontWeight.w500 : FontWeight.w300,
                        ),
                      ),
                      AnimatedContainer(
                        duration: AppDurations.fast,
                        margin: const EdgeInsets.only(top: 3),
                        height: 1,
                        width:  isSelected ? 20 : 0,
                        color:  AppColors.textPrimary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
