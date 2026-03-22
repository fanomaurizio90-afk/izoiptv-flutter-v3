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
      final catId    = _selectedCatId ?? cats.first.id;
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
              categories: _categories,
              selectedId: _selectedCatId,
              onSelect:   _selectCategory,
            ),
            // Divider
            Container(
              width: 0.5,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin:  Alignment.topCenter,
                  end:    Alignment.bottomCenter,
                  colors: [AppColors.borderSubtle, AppColors.border, AppColors.borderSubtle],
                ),
              ),
            ),
            // Right panel — search + channels
            Expanded(
              child: Column(
                children: [
                  _SearchBar(controller: _searchCtrl),
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
      itemCount:  _filtered.length,
      itemExtent: kChannelRowHeight,
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
          child: _ChannelRow(channel: ch),
        );
      },
    );
  }
}

const double kChannelRowHeight = 68.0;

// ── Search Bar ─────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.borderSubtle, width: 0.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical:   AppSpacing.xs,
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
        decoration: const InputDecoration(
          hintText:  'Search channels...',
          hintStyle: TextStyle(
            color:         AppColors.textMuted,
            fontSize:      13,
            letterSpacing: 0.3,
          ),
          prefixIcon:    Icon(Icons.search_outlined, color: AppColors.textMuted, size: 18),
          border:        InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }
}

// ── Channel Row ────────────────────────────────────────────────────────────────

class _ChannelRow extends StatelessWidget {
  const _ChannelRow({required this.channel});
  final Channel channel;

  @override
  Widget build(BuildContext context) {
    return Container(
      height:  kChannelRowHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.borderSubtle, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Logo container
          Container(
            width:  44,
            height: 44,
            decoration: BoxDecoration(
              color:        AppColors.card,
              borderRadius: BorderRadius.circular(6),
              border:       Border.all(color: AppColors.border, width: 0.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5.5),
              child: channel.logoUrl != null
                  ? CachedNetworkImage(
                      imageUrl: channel.logoUrl!,
                      fit:      BoxFit.contain,
                      errorWidget: (_, __, ___) => const Icon(
                        Icons.live_tv_outlined,
                        color: AppColors.textMuted,
                        size:  20,
                      ),
                    )
                  : const Icon(
                      Icons.live_tv_outlined,
                      color: AppColors.textMuted,
                      size:  20,
                    ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // Name
          Expanded(
            child: Text(
              channel.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color:      AppColors.textPrimary,
                fontSize:   13,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          // Play indicator
          const Icon(
            Icons.chevron_right,
            color: AppColors.textMuted,
            size:  16,
          ),
        ],
      ),
    );
  }
}

// ── Category Sidebar ───────────────────────────────────────────────────────────

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
    return Container(
      width: 168,
      color: AppColors.surface,
      child: ListView.builder(
        itemCount:  categories.length,
        itemExtent: 48,
        itemBuilder: (_, i) {
          final cat        = categories[i];
          final isSelected = cat.id == selectedId;
          return FocusableWidget(
            onTap: () => onSelect(cat.id),
            child: _CategoryItem(category: cat, isSelected: isSelected),
          );
        },
      ),
    );
  }
}

class _CategoryItem extends StatelessWidget {
  const _CategoryItem({required this.category, required this.isSelected});
  final ChannelCategory category;
  final bool            isSelected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppDurations.fast,
      height:   48,
      decoration: BoxDecoration(
        gradient: isSelected
            ? const LinearGradient(
                begin:  Alignment.centerLeft,
                end:    Alignment.centerRight,
                colors: [Color(0x1A00F0FF), Colors.transparent],
              )
            : null,
        border: isSelected
            ? const Border(
                left: BorderSide(color: AppColors.accentPrimary, width: 2),
              )
            : const Border(
                left: BorderSide(color: Colors.transparent, width: 2),
              ),
      ),
      padding: const EdgeInsets.only(left: AppSpacing.md, right: AppSpacing.md),
      alignment: Alignment.centerLeft,
      child: Text(
        category.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color:      isSelected ? AppColors.textPrimary : AppColors.textMuted,
          fontSize:   12,
          fontWeight: isSelected ? FontWeight.w500 : FontWeight.w300,
          letterSpacing: isSelected ? 0.3 : 0,
        ),
      ),
    );
  }
}
