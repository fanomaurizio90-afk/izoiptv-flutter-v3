import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/debounce.dart';
import '../../../domain/entities/vod.dart';
import '../../../domain/entities/continue_watching.dart';
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
  static const _allCatId = 0;
  static const _cwCatId  = -1;
  static const _favCatId = -2;

  final _searchCtrl             = TextEditingController();
  final _debounce               = Debounce(duration: const Duration(milliseconds: 300));
  final _firstCategoryFocusNode = FocusNode();
  final _searchFocusNode        = FocusNode();
  final _backFocusNode          = FocusNode();
  final _contentListKey  = GlobalKey<_ContentListState>();
  final _categoryBarKey  = GlobalKey<_CategoryBarState>();

  List<VodCategory>    _categories     = [];
  int?                 _selectedCatId;
  List<VodItem>        _items          = [];
  List<VodItem>        _searchResults  = [];
  Map<int, double>     _progressMap    = {};
  bool                 _loading        = true;
  bool                 _syncing        = false;
  String?              _error;
  bool                 _searching      = false;

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
      cats.insert(0, const VodCategory(id: _allCatId, name: 'All'));

      final histRepo = ref.read(historyRepositoryProvider);
      final cwItems  = await histRepo.getInProgressMovies(limit: 20);
      int insertIdx = 1;
      if (cwItems.isNotEmpty) {
        cats.insert(insertIdx++, const VodCategory(id: _cwCatId, name: 'Continue Watching'));
      }
      final favItems = await repo.getFavourites();
      if (favItems.isNotEmpty) {
        cats.insert(insertIdx, const VodCategory(id: _favCatId, name: 'Favourites'));
      }

      final catId = (_selectedCatId != null && cats.any((c) => c.id == _selectedCatId))
          ? _selectedCatId! : _allCatId;

      List<VodItem> items;
      Map<int, double> progress = {};
      if (catId == _cwCatId) {
        items = [];
        for (final c in cwItems) {
          final vod = await repo.getVodById(c.contentId);
          if (vod != null) { items.add(vod); progress[vod.id] = c.progress; }
        }
      } else if (catId == _favCatId) {
        items = favItems;
      } else if (catId == _allCatId) {
        items = await repo.getAllVod();
      } else {
        items = await repo.getVodByCategory(catId);
      }
      if (!mounted) return;
      setState(() {
        _categories    = cats;
        _selectedCatId = catId;
        _items         = items;
        _progressMap   = progress;
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
      if (catId == _cwCatId) {
        final cwItems = await ref.read(historyRepositoryProvider).getInProgressMovies(limit: 20);
        final repo = ref.read(vodRepositoryProvider);
        final items = <VodItem>[];
        final progress = <int, double>{};
        for (final c in cwItems) {
          final vod = await repo.getVodById(c.contentId);
          if (vod != null) { items.add(vod); progress[vod.id] = c.progress; }
        }
        if (!mounted) return;
        setState(() { _items = items; _progressMap = progress; _loading = false; });
      } else if (catId == _favCatId) {
        final items = await ref.read(vodRepositoryProvider).getFavourites();
        if (!mounted) return;
        setState(() { _items = items; _progressMap = {}; _loading = false; });
      } else {
        final repo  = ref.read(vodRepositoryProvider);
        final items = catId == _allCatId
            ? await repo.getAllVod()
            : await repo.getVodByCategory(catId);
        if (!mounted) return;
        setState(() { _items = items; _progressMap = {}; _loading = false; });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshAfterReturn() async {
    if (!mounted) return;
    final histRepo = ref.read(historyRepositoryProvider);
    final vodRepo  = ref.read(vodRepositoryProvider);
    final cwItems  = await histRepo.getInProgressMovies(limit: 20);
    final favItems = await vodRepo.getFavourites();
    if (!mounted) return;

    final hasCw  = cwItems.isNotEmpty;
    final hasFav = favItems.isNotEmpty;
    final hadCw  = _categories.any((c) => c.id == _cwCatId);
    final hadFav = _categories.any((c) => c.id == _favCatId);

    if (hasCw != hadCw || hasFav != hadFav) {
      final cats = _categories.where((c) => c.id != _cwCatId && c.id != _favCatId).toList();
      int insertIdx = cats.indexWhere((c) => c.id == _allCatId) + 1;
      if (hasCw)  cats.insert(insertIdx++, const VodCategory(id: _cwCatId, name: 'Continue Watching'));
      if (hasFav) cats.insert(insertIdx, const VodCategory(id: _favCatId, name: 'Favourites'));
      setState(() => _categories = cats);
    }

    if (_selectedCatId == _cwCatId || _selectedCatId == _favCatId) {
      _selectCategory(_selectedCatId!);
    }
  }

  Future<void> _onVodCategoryReorder(List<VodCategory> ordered) async {
    final realOrdered = ordered.where((c) => c.id > 0).toList();
    setState(() => _categories = ordered);
    await ref.read(vodRepositoryProvider).saveVodCategoryOrder(realOrdered);
  }

  Future<void> _showItemPopup(VodItem vod) async {
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FocusableWidget(
                autofocus: true,
                borderRadius: 8,
                onTap: () => Navigator.of(ctx).pop('favourite'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(vod.isFavourite ? Icons.favorite : Icons.favorite_border,
                          color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        vod.isFavourite ? 'Remove from Favourites' : 'Add to Favourites',
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (action == 'favourite') _toggleFavouriteVod(vod);
  }

  Future<void> _toggleFavouriteVod(VodItem vod) async {
    final repo   = ref.read(vodRepositoryProvider);
    final newVal = !vod.isFavourite;
    await repo.toggleFavourite(vod.id, newVal);
    VodItem update(VodItem v) => v.id == vod.id ? v.copyWith(isFavourite: newVal) : v;
    if (!mounted) return;

    final favs = await repo.getFavourites();
    final hasFavCat = _categories.any((c) => c.id == _favCatId);

    setState(() {
      if (_selectedCatId == _favCatId && !newVal) {
        _items.removeWhere((v) => v.id == vod.id);
        _searchResults.removeWhere((v) => v.id == vod.id);
      } else {
        _items         = _items.map(update).toList();
        _searchResults = _searchResults.map(update).toList();
      }

      if (favs.isNotEmpty && !hasFavCat) {
        final cwIdx = _categories.indexWhere((c) => c.id == _cwCatId);
        final insertAt = cwIdx >= 0 ? cwIdx + 1 : 1;
        _categories.insert(insertAt, const VodCategory(id: _favCatId, name: 'Favourites'));
      } else if (favs.isEmpty && hasFavCat) {
        _categories.removeWhere((c) => c.id == _favCatId);
        if (_selectedCatId == _favCatId) {
          _selectedCatId = _allCatId;
        }
      }
    });

    if (favs.isEmpty && _selectedCatId == _allCatId) {
      _selectCategory(_allCatId);
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(newVal ? '${vod.name} added to Favourites' : '${vod.name} removed from Favourites'),
      duration: const Duration(seconds: 2),
      backgroundColor: const Color(0xFF1A1A1A),
    ));
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
                onReorderConfirm:   _onVodCategoryReorder,
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
      onLongPress:      _showItemPopup,
      progressMap:      _progressMap,
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
        await context.push('/movies/${vod.id}');
        if (mounted) {
          _contentListKey.currentState?.restoreFocus();
          _refreshAfterReturn();
        }
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
    this.onLongPress,
    this.focusMemoryKey,
    this.progressMap,
  });
  final List<VodItem>           items;
  final int                     columns;
  final List<VodCategory>       categories;
  final void Function(VodItem)  onTap;
  final void Function(double)   onUpFromFirstRow;
  final void Function(VodItem)? onLongPress;
  final String?                 focusMemoryKey;
  final Map<int, double>?       progressMap;

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
              onLongPress:  widget.onLongPress != null
                  ? () => widget.onLongPress!(widget.items[i])
                  : null,
              child:        _PosterCard(
                vod:      widget.items[i],
                progress: widget.progressMap?[widget.items[i].id],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Poster Card ────────────────────────────────────────────────────────────────

class _PosterCard extends StatelessWidget {
  const _PosterCard({required this.vod, this.progress});
  final VodItem vod;
  final double? progress;

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
              imageUrl:       vod.posterUrl!,
              fit:            BoxFit.cover,
              memCacheWidth:  300,
              fadeInDuration: const Duration(milliseconds: 200),
              placeholder:    (_, __) => const SizedBox.shrink(),
              errorWidget:    (_, __, ___) => _PlaceholderArt(name: vod.name),
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

          // Favourite heart
          if (vod.isFavourite)
            const Positioned(
              top:   6,
              right: 6,
              child: Icon(Icons.favorite, color: Colors.white, size: 12),
            ),

          // Progress bar
          if (progress != null)
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft:  Radius.circular(AppSpacing.radiusCard),
                  bottomRight: Radius.circular(AppSpacing.radiusCard),
                ),
                child: LinearProgressIndicator(
                  value:           progress!,
                  minHeight:       3,
                  backgroundColor: Colors.white24,
                  valueColor:      const AlwaysStoppedAnimation<Color>(AppColors.accentPrimary),
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
            onTap:        () => context.pop(),
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
            child: Focus(
              skipTraversal: true,
              canRequestFocus: false,
              onKeyEvent: (_, event) {
                if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
                if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                  onDownArrow?.call();
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
                    event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                  searchFocusNode.unfocus();
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
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          focusNode:  searchFocusNode,
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
    this.onReorderConfirm,
  });
  final List<VodCategory>                      categories;
  final int?                                   selectedId;
  final void Function(int)                     onSelect;
  final void Function(double?)                 onDownArrow;
  final VoidCallback                           onUpArrow;
  final FocusNode?                             firstItemFocusNode;
  final void Function(List<VodCategory>)?      onReorderConfirm;

  @override
  State<_CategoryBar> createState() => _CategoryBarState();
}

class _CategoryBarState extends State<_CategoryBar> {
  final Map<int, FocusNode> _nodes         = {};
  List<GlobalKey>           _keys          = [];
  int                       _focusedCatIdx = -1;

  FocusNode _nodeFor(int i) {
    return _nodes.putIfAbsent(i, () {
      final n = FocusNode();
      n.addListener(() {
        if (!mounted) return;
        setState(() => _focusedCatIdx = n.hasFocus ? i : (_focusedCatIdx == i ? -1 : _focusedCatIdx));
        if (n.hasFocus) _scrollToKey(_keys[i]);
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
    for (final entry in _nodes.entries) {
      if (entry.value.hasFocus) return entry.key;
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
    final node = bestIdx == 0 ? widget.firstItemFocusNode : _nodeFor(bestIdx);
    node?.requestFocus();
    _scrollToKey(_keys[bestIdx]);
  }

  // ── Reorder state machine ──────────────────────────────────────────────────

  bool              _reorderMode = false;
  int               _reorderIdx  = -1;
  List<VodCategory> _reorderList = [];

  void _startReorder(int idx) {
    setState(() {
      _reorderMode = true;
      _reorderIdx  = idx;
      _reorderList = List.from(widget.categories);
    });
  }

  void _moveReorder(int direction) {
    // direction: -1 = left, +1 = right
    final newIdx = _reorderIdx + direction;
    // Don't move into virtual category slots (All=0, CW=-1, Fav=-2)
    if (newIdx < 0 || newIdx >= _reorderList.length) return;
    if (_reorderList[newIdx].id <= 0) return;
    setState(() {
      final item = _reorderList.removeAt(_reorderIdx);
      _reorderList.insert(newIdx, item);
      _reorderIdx = newIdx;
    });
    // Move focus to follow the reordered item
    final node = newIdx == 0 ? widget.firstItemFocusNode : _nodeFor(newIdx);
    node?.requestFocus();
    if (newIdx < _keys.length) _scrollToKey(_keys[newIdx]);
  }

  void _confirmReorder() {
    final list = _reorderList;
    setState(() {
      _reorderMode = false;
      _reorderIdx  = -1;
      _reorderList = [];
    });
    widget.onReorderConfirm?.call(list);
  }

  void _cancelReorder() {
    final idx = _reorderIdx;
    setState(() {
      _reorderMode = false;
      _reorderIdx  = -1;
      _reorderList = [];
    });
    if (idx >= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final node = idx == 0 ? widget.firstItemFocusNode : _nodeFor(idx);
        node?.requestFocus();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding:         EdgeInsets.symmetric(horizontal: AppSpacing.tvH),
          itemCount:       cats.length,
          itemBuilder:     (_, i) {
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
                if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                  if (i < cats.length - 1) _nodeFor(i + 1).requestFocus();
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                  if (i > 0) (i == 1 ? widget.firstItemFocusNode : _nodeFor(i - 1))?.requestFocus();
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                  widget.onDownArrow(_getCenterX(i)); return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                  widget.onUpArrow(); return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: FocusableWidget(
                autofocus:       i == 0,
                focusNode:       node,
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
                              color: isReordering
                                  ? AppColors.accentPrimary
                                  : isSelected
                                      ? AppColors.textPrimary
                                      : isFocused
                                          ? AppColors.textSecondary
                                          : AppColors.textMuted,
                              fontSize:      12,
                              fontWeight:    (isSelected || isReordering) ? FontWeight.w500 : FontWeight.w300,
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
              ),
            );
          },
        ),
      ),
    );
  }
}

