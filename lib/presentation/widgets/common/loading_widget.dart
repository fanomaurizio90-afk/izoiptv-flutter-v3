import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class LoadingWidget extends StatelessWidget {
  const LoadingWidget({super.key, this.message});
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width:  20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color:       AppColors.accentPrimary.withValues(alpha: 0.6),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              message!,
              style: const TextStyle(
                color:         AppColors.textMuted,
                fontSize:      11,
                fontWeight:    FontWeight.w300,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
