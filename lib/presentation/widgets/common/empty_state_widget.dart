import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

enum EmptyStateType { channels, movies, series, favourites, search }

class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({
    super.key,
    required this.type,
    this.searchTerm,
  });
  final EmptyStateType type;
  final String?        searchTerm;

  @override
  Widget build(BuildContext context) {
    final cfg = _config(type, searchTerm);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon container
          Container(
            width:  64,
            height: 64,
            decoration: BoxDecoration(
              color:        AppColors.card,
              borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
              border:       Border.all(color: AppColors.glassBorder, width: 0.5),
            ),
            child: Icon(
              _icon(type),
              color: AppColors.textMuted,
              size:  26,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            cfg.$1,
            style: const TextStyle(
              color:         AppColors.textPrimary,
              fontSize:      15,
              fontWeight:    FontWeight.w500,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            cfg.$2,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color:    AppColors.textMuted,
              fontSize: 12,
              height:   1.6,
            ),
          ),
        ],
      ),
    );
  }

  static (String, String) _config(EmptyStateType t, String? q) {
    switch (t) {
      case EmptyStateType.channels:
        return ('No channels found', 'Try a different category');
      case EmptyStateType.movies:
        return ('No movies found', 'Try a different category or search term');
      case EmptyStateType.series:
        return ('No series found', 'Try a different category or search term');
      case EmptyStateType.favourites:
        return ('Nothing saved yet', 'Tap the heart on any channel or movie');
      case EmptyStateType.search:
        return ('No results for "${q ?? ''}"', 'Check your spelling or try something else');
    }
  }

  static IconData _icon(EmptyStateType t) {
    switch (t) {
      case EmptyStateType.channels:   return Icons.live_tv_outlined;
      case EmptyStateType.movies:     return Icons.movie_outlined;
      case EmptyStateType.series:     return Icons.tv_outlined;
      case EmptyStateType.favourites: return Icons.bookmark_outline_rounded;
      case EmptyStateType.search:     return Icons.search_outlined;
    }
  }
}
