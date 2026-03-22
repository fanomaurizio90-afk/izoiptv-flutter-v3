import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import 'skeleton_widget.dart';

class LoadingWidget extends StatelessWidget {
  const LoadingWidget({super.key, this.message});
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width:  24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color:       AppColors.textMuted,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              message!,
              style: GoogleFonts.dmSans(
                color:         AppColors.textMuted,
                fontSize:      12,
                fontWeight:    FontWeight.w300,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
