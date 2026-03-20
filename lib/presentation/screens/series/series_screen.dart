import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/debounce.dart';
import '../../../domain/entities/series.dart';
import '../../providers/providers.dart';
import '../../widgets/common/focusable_widget.dart';
import '../../widgets/common/loading_widget.dart';

class SeriesScreen extends ConsumerStatefulWidget {
  const SeriesScreen({super.key});

  @override
  ConsumerState<SeriesScreen> createState() => _SeriesScreenState();
}

class _SeriesScreenState extends ConsumerState<SeriesScreen> {
  final _searchCtrl = TextEditingController();
  final _debounce   = Debounce(duration: const Duration(milliseconds: 300));

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
            Container(
              color:   AppColors.surface,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: const Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 18),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  const Text('Series', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(width: AppSpacing.xl2),
                  Expanded(
                    child: TextField(
                      controller:   _searchCtrl,
                      style:        const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                      decoration:   const InputDecoration(
                        hintText:      'Search...',
                        border:        InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_categories.isNotEmpty) _SeriesCategoryBar(
              categories: _categories,
              selectedId: _selectedCatId,
              onSelect:   _selectCategory,
            ),
            Expanded(child: _buildGrid()),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid() {
    if (_syncing) return const LoadingWidget(message: 'Syncing series...');
    if (_loading) return const LoadingWidget();
    if (_error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
        const SizedBox(height: AppSpacing.md),
        GestureDetector(onTap: _load,
          child: const Text('Retry', style: TextStyle(color: AppColors.textSecondary, fontSize: 13))),
      ]));
    }
    final display = _searching ? _searchResults : _items;
    if (display.isEmpty) {
      return const Center(child: Text('No series', style: TextStyle(color: AppColors.textMuted, fontSize: 13)));
    }
    return GridView.builder(
      padding:     const EdgeInsets.all(AppSpacing.md),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:   3,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing:  AppSpacing.sm,
        childAspectRatio: 2 / 3,
      ),
      itemCount:   display.length,
      itemBuilder: (_, i) {  // CRITICAL: use _ not context
        final s = display[i];
        return FocusableWidget(
          borderRadius: AppSpacing.radiusCard,
          onTap: () => context.push('/series/${s.id}'),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
            child: Container(
              color: AppColors.card,
              child: s.posterUrl != null
                  ? CachedNetworkImage(
                      imageUrl:   s.posterUrl!,
                      fit:        BoxFit.cover,
                      errorWidget: (_, __, ___) => Center(
                        child: Text(s.name, maxLines: 3, textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                      ),
                    )
                  : Center(child: Text(s.name, maxLines: 3, textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 10))),
            ),
          ),
        );
      },
    );
  }
}

class _SeriesCategoryBar extends StatelessWidget {
  const _SeriesCategoryBar({required this.categories, required this.selectedId, required this.onSelect});
  final List<SeriesCategory> categories;
  final int?                 selectedId;
  final void Function(int)   onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding:         const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount:       categories.length,
        itemBuilder:     (_, i) {
          final cat        = categories[i];
          final isSelected = cat.id == selectedId;
          return GestureDetector(
            onTap: () => onSelect(cat.id),
            child: Padding(
              padding: const EdgeInsets.only(right: AppSpacing.lg),
              child: Center(
                child: Text(cat.name, style: TextStyle(
                  color:      isSelected ? AppColors.textPrimary : AppColors.textMuted,
                  fontSize:   12,
                  fontWeight: isSelected ? FontWeight.w400 : FontWeight.w300,
                )),
              ),
            ),
          );
        },
      ),
    );
  }
}
