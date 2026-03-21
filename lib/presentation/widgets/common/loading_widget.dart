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
            width:  24,
            height: 24,
            child:  CircularProgressIndicator(
              strokeWidth: 1.5,
              color:       AppColors.accentPrimary,
              backgroundColor: AppColors.borderSubtle,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              message!,
              style: const TextStyle(
                color:         AppColors.textMuted,
                fontSize:      11,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
