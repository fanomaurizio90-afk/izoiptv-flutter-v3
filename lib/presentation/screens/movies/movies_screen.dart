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
import '../../widgets/common/pin_dialog.dart';
import '../../../core/utils/parental_control.dart';

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
            _TopBar(searchCtrl: _searchCtrl),
            if (_categories.isNotEmpty) _CategoryBar(
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
      return const Center(
        child: Text('No movies', style: TextStyle(color: AppColors.textMuted, fontSize: 13)));
    }

    return GridView.builder(
      padding:      const EdgeInsets.all(AppSpacing.md),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:   5,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing:  AppSpacing.sm,
        childAspectRatio: 2 / 3,
      ),
      itemCount:   display.length,
      itemBuilder: (_, i) {  // CRITICAL: use _ not context
        final vod = display[i];
        return FocusableWidget(
          autofocus:    i == 0,
          borderRadius: AppSpacing.radiusCard,
          onTap: () async {
            final cat = _categories.firstWhere(
              (c) => c.id == vod.categoryId,
              orElse: () => const VodCategory(id: 0, name: ''),
            );
            if (isAdultCategory(cat.name) || isAdultCategory(vod.name)) {
              final ok = await showPinDialog(context);
              if (!ok || !mounted) return;
            }
            if (mounted) context.push('/movies/${vod.id}');
          },
          child: _PosterCard(name: vod.name, posterUrl: vod.posterUrl),
        );
      },
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
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.borderSubtle, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical:   AppSpacing.sm,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.xs),
              child: const Icon(Icons.arrow_back, color: AppColors.textSecondary, size: 18),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          const Text(
            'MOVIES',
            style: TextStyle(
              color:         AppColors.textPrimary,
              fontSize:      13,
              fontWeight:    FontWeight.w600,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(width: AppSpacing.xl2),
          Expanded(
            child: TextField(
              controller: searchCtrl,
              style:      const TextStyle(color: AppColors.textPrimary, fontSize: 12),
              decoration: const InputDecoration(
                hintText:        'Search...',
                hintStyle:       TextStyle(color: AppColors.textMuted, fontSize: 12),
                border:          InputBorder.none,
                enabledBorder:   InputBorder.none,
                focusedBorder:   InputBorder.none,
                contentPadding:  EdgeInsets.zero,
                prefixIcon:      Icon(Icons.search_outlined, color: AppColors.textMuted, size: 16),
                prefixIconConstraints: BoxConstraints(minWidth: 28, minHeight: 0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Category Bar ───────────────────────────────────────────────────────────────

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({
    required this.categories,
    required this.selectedId,
    required this.onSelect,
  });
  final List<VodCategory>  categories;
  final int?               selectedId;
  final void Function(int) onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.borderSubtle, width: 0.5)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding:         const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical:   AppSpacing.sm,
        ),
        itemCount:   categories.length,
        itemBuilder: (_, i) {
          final cat        = categories[i];
          final isSelected = cat.id == selectedId;
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: FocusableWidget(
              autofocus:    i == 0,
              onTap:        () => onSelect(cat.id),
              borderRadius: 20,
              child: AnimatedContainer(
                duration: AppDurations.fast,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical:   5,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.accentPrimary.withOpacity(0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.accentPrimary.withOpacity(0.40)
                        : AppColors.borderSubtle,
                    width: 0.5,
                  ),
                ),
                child: Text(
                  cat.name,
                  style: TextStyle(
                    color:         isSelected ? AppColors.accentPrimary : AppColors.textMuted,
                    fontSize:      11,
                    fontWeight:    isSelected ? FontWeight.w500 : FontWeight.w300,
                    letterSpacing: 0.3,
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

// ── Poster Card ────────────────────────────────────────────────────────────────

class _PosterCard extends StatelessWidget {
  const _PosterCard({required this.name, required this.posterUrl});
  final String  name;
  final String? posterUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background
          Container(color: AppColors.card),
          // Poster image
          if (posterUrl != null)
            CachedNetworkImage(
              imageUrl:    posterUrl!,
              fit:         BoxFit.cover,
              errorWidget: (_, __, ___) => const Center(
                child: Icon(Icons.movie_outlined, color: AppColors.textMuted, size: 22),
              ),
            )
          else
            const Center(
              child: Icon(Icons.movie_outlined, color: AppColors.textMuted, size: 22),
            ),
          // Bottom gradient with title overlay
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin:  Alignment.topCenter,
                  end:    Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xEE030308)],
                ),
              ),
              padding: const EdgeInsets.fromLTRB(6, 18, 6, 6),
              child: Text(
                name,
                maxLines:  2,
                overflow:  TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color:      Colors.white,
                  fontSize:   9,
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
