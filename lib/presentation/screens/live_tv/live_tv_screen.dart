import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/debounce.dart';
import '../../../domain/entities/channel.dart';
import '../../providers/channel_provider.dart';
import '../../providers/providers.dart';
import '../../widgets/common/focusable_widget.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/pin_dialog.dart';
import '../../../core/utils/parental_control.dart';

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
  bool                  _loading       = true;
  bool                  _syncing       = false;
  String?               _error;

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
      if (!mounted) return;
      if (cats.isEmpty) { setState(() { _loading = false; }); return; }
      final catId   = _selectedCatId ?? cats.first.id;
      final channels = await repo.getChannelsByCategory(catId);
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
      final channels = await ref.read(channelRepositoryProvider).getChannelsByCategory(catId);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Row(
          children: [
            // Left sidebar — categories
            _CategorySidebar(
              categories:    _categories,
              selectedId:    _selectedCatId,
              onSelect:      _selectCategory,
            ),
            // Divider
            Container(width: 0.5, color: AppColors.border),
            // Right — channels
            Expanded(
              child: Column(
                children: [
                  // Search bar
                  Container(
                    color:   AppColors.surface,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical:   AppSpacing.xs,
                    ),
                    child: TextField(
                      controller:   _searchCtrl,
                      style:        const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                      decoration:   const InputDecoration(
                        hintText:    'Search channels...',
                        prefixIcon:  Icon(Icons.search_outlined, color: AppColors.textMuted, size: 18),
                        border:      InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ),
                  Container(height: 0.5, color: AppColors.border),
                  Expanded(child: _buildChannelList()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChannelList() {
    if (_syncing) return const LoadingWidget(message: 'Syncing channels...');
    if (_loading) return const LoadingWidget();
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
            const SizedBox(height: AppSpacing.md),
            GestureDetector(
              onTap: _load,
              child: const Text('Retry', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ),
          ],
        ),
      );
    }
    if (_filtered.isEmpty) {
      return const Center(
        child: Text('No channels', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
      );
    }

    return ListView.builder(
      itemCount: _filtered.length,
      itemExtent: AppConstants_channelRowHeight,
      itemBuilder: (_, i) {
        final ch = _filtered[i];
        return FocusableWidget(
          autofocus: i == 0,
          onTap: () async {
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
          child: Container(
            height:  AppConstants_channelRowHeight,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              color: _selectedCatId == ch.categoryId
                  ? AppColors.card
                  : AppColors.transparent,
            ),
            child: Row(
              children: [
                // Logo
                SizedBox(
                  width:  32,
                  height: 32,
                  child: ch.logoUrl != null
                      ? CachedNetworkImage(
                          imageUrl: ch.logoUrl!,
                          fit:      BoxFit.contain,
                          errorWidget: (_, __, ___) => const Icon(
                            Icons.live_tv_outlined,
                            color: AppColors.textMuted,
                            size:  18,
                          ),
                        )
                      : const Icon(Icons.live_tv_outlined, color: AppColors.textMuted, size: 18),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    ch.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color:      AppColors.textPrimary,
                      fontSize:   13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Workaround for constant usage in itemExtent
const double AppConstants_channelRowHeight = 56.0;

class _CategorySidebar extends StatelessWidget {
  const _CategorySidebar({
    required this.categories,
    required this.selectedId,
    required this.onSelect,
  });
  final List<ChannelCategory> categories;
  final int?                  selectedId;
  final void Function(int)    onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: ListView.builder(
        itemCount:  categories.length,
        itemExtent: 44,
        itemBuilder: (_, i) {
          final cat       = categories[i];
          final isSelected = cat.id == selectedId;
          return FocusableWidget(
            onTap: () => onSelect(cat.id),
            child: Container(
              height:  44,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              decoration: BoxDecoration(
                border: isSelected
                    ? const Border(
                        left: BorderSide(color: AppColors.accentPrimary, width: 1),
                      )
                    : null,
              ),
              alignment: Alignment.centerLeft,
              child: Text(
                cat.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color:      isSelected ? AppColors.textPrimary : AppColors.textMuted,
                  fontSize:   12,
                  fontWeight: isSelected ? FontWeight.w400 : FontWeight.w300,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
