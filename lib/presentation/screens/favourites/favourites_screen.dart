import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/channel.dart';
import '../../../domain/entities/vod.dart';
import '../../../domain/entities/series.dart';
import '../../providers/providers.dart';
import '../../widgets/common/loading_widget.dart';

final _favChannelsProvider = FutureProvider<List<Channel>>((ref) =>
    ref.watch(favouritesRepositoryProvider).getFavouriteChannels());
final _favVodProvider      = FutureProvider<List<VodItem>>((ref) =>
    ref.watch(favouritesRepositoryProvider).getFavouriteVod());
final _favSeriesProvider   = FutureProvider<List<SeriesItem>>((ref) =>
    ref.watch(favouritesRepositoryProvider).getFavouriteSeries());

class FavouritesScreen extends ConsumerStatefulWidget {
  const FavouritesScreen({super.key});

  @override
  ConsumerState<FavouritesScreen> createState() => _FavouritesScreenState();
}

class _FavouritesScreenState extends ConsumerState<FavouritesScreen> {
  int _tab = 0; // 0=Channels 1=Movies 2=Series

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
                  const Text('Favourites', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            // Tab bar
            Row(
              children: [
                _Tab(label: 'Channels', selected: _tab == 0, onTap: () => setState(() => _tab = 0)),
                _Tab(label: 'Movies',   selected: _tab == 1, onTap: () => setState(() => _tab = 1)),
                _Tab(label: 'Series',   selected: _tab == 2, onTap: () => setState(() => _tab = 2)),
              ],
            ),
            const Divider(height: 0),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_tab) {
      case 0:
        return ref.watch(_favChannelsProvider).when(
          data:    (items) => _ChannelList(channels: items),
          loading: () => const LoadingWidget(),
          error:   (e, _) => Center(child: Text(e.toString(), style: const TextStyle(color: AppColors.error, fontSize: 12))),
        );
      case 1:
        return ref.watch(_favVodProvider).when(
          data:    (items) => _SimpleList(items: items.map((v) => v.name).toList(), onTap: (i) => context.push('/movies/${items[i].id}')),
          loading: () => const LoadingWidget(),
          error:   (e, _) => Center(child: Text(e.toString(), style: const TextStyle(color: AppColors.error, fontSize: 12))),
        );
      case 2:
        return ref.watch(_favSeriesProvider).when(
          data:    (items) => _SimpleList(items: items.map((s) => s.name).toList(), onTap: (i) => context.push('/series/${items[i].id}')),
          loading: () => const LoadingWidget(),
          error:   (e, _) => Center(child: Text(e.toString(), style: const TextStyle(color: AppColors.error, fontSize: 12))),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.selected, required this.onTap});
  final String       label;
  final bool         selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Text(
          label,
          style: TextStyle(
            color:      selected ? AppColors.textPrimary : AppColors.textMuted,
            fontSize:   13,
            fontWeight: selected ? FontWeight.w400 : FontWeight.w300,
          ),
        ),
      ),
    );
  }
}

class _ChannelList extends StatelessWidget {
  const _ChannelList({required this.channels});
  final List<Channel> channels;

  @override
  Widget build(BuildContext context) {
    if (channels.isEmpty) {
      return const Center(child: Text('No favourite channels', style: TextStyle(color: AppColors.textMuted, fontSize: 13)));
    }
    return ListView.builder(
      itemCount:  channels.length,
      itemExtent: 56,
      itemBuilder: (_, i) {
        final ch = channels[i];
        return Container(
          height:  56,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          alignment: Alignment.centerLeft,
          child: Text(ch.name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
        );
      },
    );
  }
}

class _SimpleList extends StatelessWidget {
  const _SimpleList({required this.items, required this.onTap});
  final List<String>       items;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('No favourites', style: TextStyle(color: AppColors.textMuted, fontSize: 13)));
    }
    return ListView.builder(
      itemCount:  items.length,
      itemExtent: 56,
      itemBuilder: (_, i) {
        return GestureDetector(
          onTap: () => onTap(i),
          child: Container(
            height:  56,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            alignment: Alignment.centerLeft,
            child: Text(items[i], style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
          ),
        );
      },
    );
  }
}
