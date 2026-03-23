import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/providers.dart';
import '../../../services/device_id_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _syncing = false;

  Future<void> _forceSync() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      await ref.read(syncProvider.notifier).syncAndEnrich();
    } catch (_) {}
    if (mounted) setState(() => _syncing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.tvH, AppSpacing.xl2, AppSpacing.tvH, AppSpacing.xl,
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: const Icon(Icons.arrow_back, color: AppColors.textSecondary, size: 18),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    'Settings',
                    style: GoogleFonts.dmSans(
                      color:      AppColors.textPrimary,
                      fontSize:   16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _SectionHeader('Device'),
                  _DeviceIdRow(),
                  _SettingsRow(
                    label: 'Manage Playlist',
                    value: 'izoiptv.com/authenticate',
                    showArrow: true,
                    onTap: () async {
                      final uri = Uri.parse('https://izoiptv.com/authenticate');
                      if (await canLaunchUrl(uri)) await launchUrl(uri);
                    },
                  ),
                  _SectionHeader('Library'),
                  _LibraryStatusRow(),
                  _SettingsRow(
                    label: 'Refresh Library',
                    value: _syncing ? 'Syncing…' : 'Refresh now',
                    showArrow: !_syncing,
                    onTap: _syncing ? null : _forceSync,
                  ),
                  _SectionHeader('App'),
                  const _SettingsRow(label: 'Version', value: '1.8.0'),
                  const SizedBox(height: AppSpacing.xl6),
                  // Logout — muted red text only, no button shape
                  GestureDetector(
                    onTap: () async {
                      await ref.read(authProvider.notifier).logout();
                    },
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl2),
                        child: Text(
                          'Sign Out',
                          style: GoogleFonts.dmSans(
                            color:    const Color(0xFFE57373),
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
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

// ── Library status row ─────────────────────────────────────────────────────────

class _LibraryStatusRow extends ConsumerStatefulWidget {
  @override
  ConsumerState<_LibraryStatusRow> createState() => _LibraryStatusRowState();
}

class _LibraryStatusRowState extends ConsumerState<_LibraryStatusRow> {
  DateTime? _lastSynced;

  @override
  void initState() {
    super.initState();
    ref.read(syncProvider.notifier).lastSyncedAt().then((t) {
      if (mounted) setState(() => _lastSynced = t);
    });
  }

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1)  return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours   < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(syncProvider);

    final String rowLabel;
    final String value;
    final bool   active;

    switch (syncState) {
      case SyncDownloading():
        rowLabel = 'Status';
        value    = 'Downloading playlist…';
        active   = true;
      case SyncEnriching(:final done, :final total, :final label):
        rowLabel = 'Status';
        value    = 'Loading $label artwork · $done / $total';
        active   = true;
      case SyncDone():
        rowLabel = 'Status';
        value    = 'Complete ✓';
        active   = false;
      default:
        rowLabel = 'Last synced';
        value    = _lastSynced != null ? _timeAgo(_lastSynced!) : 'Never';
        active   = false;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.tvH,
        vertical:   AppSpacing.lg,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          Text(
            rowLabel,
            style: GoogleFonts.dmSans(
              color:      AppColors.textPrimary,
              fontSize:   13,
              fontWeight: FontWeight.w400,
            ),
          ),
          const Spacer(),
          if (active)
            const SizedBox(
              width: 10, height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: AppColors.textMuted,
              ),
            ),
          if (active) const SizedBox(width: 8),
          Text(
            value,
            style: GoogleFonts.dmSans(
              color:    AppColors.textMuted,
              fontSize: 13,
            ),
          ),
        ],
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
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.tvH, AppSpacing.xl2, AppSpacing.tvH, AppSpacing.sm,
      ),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.dmSans(
          color:         AppColors.textMuted,
          fontSize:      10,
          fontWeight:    FontWeight.w500,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.label,
    this.value,
    this.onTap,
    this.showArrow = false,
  });
  final String        label;
  final String?       value;
  final VoidCallback? onTap;
  final bool          showArrow;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.tvH,
          vertical:   AppSpacing.lg,
        ),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: GoogleFonts.dmSans(
                color:      AppColors.textPrimary,
                fontSize:   13,
                fontWeight: FontWeight.w400,
              ),
            ),
            const Spacer(),
            if (value != null)
              Text(
                value!,
                style: GoogleFonts.dmSans(
                  color:    AppColors.textMuted,
                  fontSize: 13,
                ),
              ),
            if (showArrow) ...[
              const SizedBox(width: 6),
              const Icon(Icons.arrow_forward_ios, color: AppColors.textMuted, size: 10),
            ],
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
  bool    _copied = false;

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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl2,
        vertical:   AppSpacing.lg,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          Text(
            'Device ID',
            style: GoogleFonts.dmSans(
              color:      AppColors.textPrimary,
              fontSize:   13,
              fontWeight: FontWeight.w400,
            ),
          ),
          const Spacer(),
          if (_id != null) ...[
            Text(
              _id!.length > 14 ? '${_id!.substring(0, 14)}...' : _id!,
              style: const TextStyle(
                color:      AppColors.textMuted,
                fontSize:   11,
                fontFamily: 'monospace',
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            GestureDetector(
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: _id!));
                if (!mounted) return;
                setState(() => _copied = true);
                await Future.delayed(const Duration(seconds: 2));
                if (mounted) setState(() => _copied = false);
              },
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: Icon(
                  _copied ? Icons.check : Icons.copy_outlined,
                  key:   ValueKey(_copied),
                  color: _copied ? AppColors.success : AppColors.textMuted,
                  size:  14,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
