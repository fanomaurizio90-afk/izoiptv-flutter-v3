import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/debounce.dart';
import '../../../domain/entities/vod.dart';
import '../../providers/providers.dart';
import '../../widgets/common/focusable_widget.dart';
import '../../widgets/common/loading_widget.dart';

class MoviesScreen extends ConsumerStatefulWidget {
  const MoviesScreen({super.key});

  @override
  ConsumerState<MoviesScreen> createState() => _MoviesScreenState();
}

class _MoviesScreenState extends ConsumerState<MoviesScreen> {
  final _searchCtrl = TextEditingController();
  final _debounce   = Debounce(duration: const Duration(milliseconds: 300));

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
      if (!mounted) return;
      if (cats.isEmpty) { setState(() { _loading = false; }); return; }
      final catId = (_selectedCatId != null && cats.any((c) => c.id == _selectedCatId))
          ? _selectedCatId!
          : cats.first.id;
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
            // Top bar
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
                  const Text('Movies', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(width: AppSpacing.xl2),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      style:      const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                      decoration: const InputDecoration(
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
            // Category filters
            if (_categories.isNotEmpty) _CategoryBar(
              categories: _categories,
              selectedId: _selectedCatId,
              onSelect:   _selectCategory,
            ),
            // Grid
            Expanded(child: _buildGrid()),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid() {
    if (_syncing)  return const LoadingWidget(message: 'Syncing movies...');
    if (_loading)  return const LoadingWidget();
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
      return const Center(child: Text('No movies', style: TextStyle(color: AppColors.textMuted, fontSize: 13)));
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
      itemBuilder: (_, i) {  // CRITICAL: use _ not context to avoid context shadowing
        final vod = display[i];
        return FocusableWidget(
          borderRadius: AppSpacing.radiusCard,
          onTap: () => context.push('/movies/${vod.id}'),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
            child: Container(
              color: AppColors.card,
              child: vod.posterUrl != null
                  ? CachedNetworkImage(
                      imageUrl:   vod.posterUrl!,
                      fit:        BoxFit.cover,
                      errorWidget: (_, __, ___) => _PosterPlaceholder(name: vod.name),
                    )
                  : _PosterPlaceholder(name: vod.name),
            ),
          ),
        );
      },
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({required this.categories, required this.selectedId, required this.onSelect});
  final List<VodCategory> categories;
  final int?              selectedId;
  final void Function(int) onSelect;

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
                child: Text(
                  cat.name,
                  style: TextStyle(
                    color:      isSelected ? AppColors.textPrimary : AppColors.textMuted,
                    fontSize:   12,
                    fontWeight: isSelected ? FontWeight.w400 : FontWeight.w300,
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

class _PosterPlaceholder extends StatelessWidget {
  const _PosterPlaceholder({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.card,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Center(
        child: Text(
          name,
          maxLines: 3,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
        ),
      ),
    );
  }
}
