import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../../services/device_id_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
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
                  const Text('Settings', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  // Device section
                  _SectionHeader('Device'),
                  _DeviceIdRow(),
                  _Row(
                    label: 'Manage Playlist',
                    value: 'izoiptv.com/authenticate',
                    onTap: () async {
                      final uri = Uri.parse('https://izoiptv.com/authenticate');
                      if (await canLaunchUrl(uri)) await launchUrl(uri);
                    },
                  ),

                  // App section
                  _SectionHeader('App'),
                  _Row(label: 'Version', value: '1.0.0'),

                  // Logout
                  const SizedBox(height: AppSpacing.xl3),
                  GestureDetector(
                    onTap: () async {
                      await ref.read(authProvider.notifier).logout();
                    },
                    child: const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.md),
                        child: Text(
                          'Sign Out',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xs),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color:         AppColors.textMuted,
          fontSize:      11,
          fontWeight:    FontWeight.w400,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, this.value, this.onTap});
  final String   label;
  final String?  value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
        ),
        child: Row(
          children: [
            Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
            const Spacer(),
            if (value != null)
              Text(value!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            if (onTap != null)
              const Icon(Icons.arrow_forward_ios, color: AppColors.textMuted, size: 12),
          ],
        ),
      ),
    );
  }
}

class _DeviceIdRow extends StatefulWidget {
  @override
  State<_DeviceIdRow> createState() => _DeviceIdRowState();
}

class _DeviceIdRowState extends State<_DeviceIdRow> {
  String? _id;

  @override
  void initState() {
    super.initState();
    DeviceIdService.instance.getDeviceId().then((id) {
      if (mounted) setState(() => _id = id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          const Text('Device ID', style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
          const Spacer(),
          if (_id != null) ...[
            Text(
              _id!.length > 12 ? '${_id!.substring(0, 12)}...' : _id!,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontFamily: 'monospace'),
            ),
            const SizedBox(width: AppSpacing.xs),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: _id!));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied'), duration: Duration(seconds: 1)),
                );
              },
              child: const Icon(Icons.copy_outlined, color: AppColors.textMuted, size: 14),
            ),
          ],
        ],
      ),
    );
  }
}
