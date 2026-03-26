import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/app_logo.dart';
import '../../widgets/common/focusable_widget.dart';

class ExpiredScreen extends ConsumerWidget {
  const ExpiredScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope(
      canPop: false,
      child: Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl3),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const IzoLogo(size: 56),
                const SizedBox(height: AppSpacing.xl2),
                const Text(
                  'Subscription Expired',
                  style: TextStyle(
                    color:      AppColors.textPrimary,
                    fontSize:   16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'Visit izoiptv.com to renew your subscription.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: AppSpacing.xl3),
                FocusableWidget(
                  autofocus: true,
                  onTap: () => ref.read(authProvider.notifier).logout(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: const Text(
                      'Sign out',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }
}
