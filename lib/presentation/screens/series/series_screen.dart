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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(searchCtrl: _searchCtrl),
            if (_categories.isNotEmpty) _CategoryBar(
              categories:         _categories,
              selectedId:         _selectedCatId,
              onSelect:           _selectCategory,
              firstItemFocusNode: _firstCategoryFocusNode,
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
    this.categoryFocusNode,
  });
  final List<SeriesItem>      items;
  final int                   columns;
  final List<SeriesCategory>  categories;
  final void Function(SeriesItem) onTap;
  final FocusNode?            categoryFocusNode;

  @override
  State<_ContentList> createState() => _ContentListState();
}

class _ContentListState extends State<_ContentList> {
  List<FocusNode> _nodes = [];

  List<SeriesItem> get _rest =>
      widget.items.length > 1 ? widget.items.sublist(1) : <SeriesItem>[];

  @override
  void initState() {
    super.initState();
    _nodes = List.generate(_rest.length, (_) => FocusNode());
  }

  @override
  void didUpdateWidget(_ContentList old) {
    super.didUpdateWidget(old);
    if (_rest.length != _nodes.length) {
      for (final n in _nodes) n.dispose();
      _nodes = List.generate(_rest.length, (_) => FocusNode());
    }
  }

  @override
  void dispose() {
    for (final n in _nodes) n.dispose();
    super.dispose();
  }

  int get _focusedIndex {
    for (int i = 0; i < _nodes.length; i++) {
      if (_nodes[i].hasFocus) return i;
    }
    return -1;
  }

  void _move(int to) {
    if (to >= 0 && to < _nodes.length) _nodes[to].requestFocus();
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
      if (idx - widget.columns >= 0) _move(idx - widget.columns);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final hero = widget.items.first;
    final rest = _rest;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FocusableWidget(
            autofocus:    true,
            borderRadius: 0,
            onTap:        () => widget.onTap(hero),
            child: _HeroCard(series: hero),
          ),
          if (rest.isNotEmpty) ...[
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
                itemCount:   rest.length,
                itemBuilder: (_, i) => FocusableWidget(
                  focusNode:    _nodes[i],
                  autofocus:    false,
                  borderRadius: AppSpacing.radiusCard,
                  onTap:        () => widget.onTap(rest[i]),
                  child:        _PosterCard(series: rest[i]),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl3),
          ],
        ],
      ),
    );
  }
}

// ── Hero Card ──────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.series});
  final SeriesItem series;

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height * 0.32;
    return SizedBox(
      height: h,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (series.posterUrl != null)
            CachedNetworkImage(
              imageUrl:    series.posterUrl!,
              fit:         BoxFit.cover,
              errorWidget: (_, __, ___) => Container(color: AppColors.card),
            )
          else
            Container(color: AppColors.card),
          // Dark gradient overlay
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin:  Alignment.topCenter,
                end:    Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xCC080808), Color(0xFF080808)],
                stops:  [0.3, 0.75, 1.0],
              ),
            ),
          ),
          // Title bottom-left
          Positioned(
            left: AppSpacing.tvH, right: AppSpacing.tvH, bottom: AppSpacing.lg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize:       MainAxisSize.min,
              children: [
                Text(
                  series.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    color:      AppColors.textPrimary,
                    fontSize:   18,
                    fontWeight: FontWeight.w500,
                    height:     1.2,
                    letterSpacing: -0.2,
                  ),
                ),
                if (series.genre != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    series.genre!,
                    style: GoogleFonts.dmSans(
                      color:    AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // FEATURED badge top left
          Positioned(
            top: AppSpacing.md, left: AppSpacing.md,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color:        AppColors.textPrimary,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                'FEATURED',
                style: GoogleFonts.dmSans(
                  color:         AppColors.background,
                  fontSize:      8,
                  fontWeight:    FontWeight.w600,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
        ],
      ),
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
          // Bottom title gradient
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
  const _TopBar({required this.searchCtrl});
  final TextEditingController searchCtrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.tvH, vertical: AppSpacing.md),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: const Icon(Icons.arrow_back, color: AppColors.textSecondary, size: 18),
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
            child: TextField(
              controller: searchCtrl,
              style: GoogleFonts.dmSans(color: AppColors.textPrimary, fontSize: 12),
              decoration: InputDecoration(
                hintText:       'Search...',
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
        ],
      ),
    );
  }
}

// ── Category Bar — plain text links ───────────────────────────────────────────

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({
    required this.categories,
    required this.selectedId,
    required this.onSelect,
    this.firstItemFocusNode,
  });
  final List<SeriesCategory> categories;
  final int?                 selectedId;
  final void Function(int)   onSelect;
  final FocusNode?           firstItemFocusNode;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding:         const EdgeInsets.symmetric(horizontal: AppSpacing.tvH),
        itemCount:       categories.length,
        itemBuilder:     (_, i) {
          final cat        = categories[i];
          final isSelected = cat.id == selectedId;
          return FocusableWidget(
            autofocus: i == 0,
            focusNode: i == 0 ? firstItemFocusNode : null,
            onTap:     () => onSelect(cat.id),
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
                    // Active underline
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
          );
        },
      ),
    );
  }
}
