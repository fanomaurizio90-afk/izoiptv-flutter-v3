import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/providers.dart';
import '../../widgets/common/focusable_widget.dart';
import '../../../services/device_id_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _syncing = false;

  // Explicit D-pad navigation chain
  final _backNode      = FocusNode();
  final _managePlNode  = FocusNode();
  final _deviceIdNode  = FocusNode();
  final _refreshNode   = FocusNode();
  final _signOutNode   = FocusNode();

  @override
  void dispose() {
    _backNode.dispose();
    _managePlNode.dispose();
    _deviceIdNode.dispose();
    _refreshNode.dispose();
    _signOutNode.dispose();
    super.dispose();
  }

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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/home');
      },
      child: Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.tvH, AppSpacing.xl2, AppSpacing.tvH, AppSpacing.xl,
              ),
              child: Row(
                children: [
                  FocusableWidget(
                    focusNode: _backNode,
                    autofocus: true,
                    onTap:     () => context.go('/home'),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.arrow_back, color: AppColors.textSecondary, size: 18),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    'Settings',
                    style: const TextStyle(
                      color:      AppColors.textPrimary,
                      fontSize:   16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // ── Rows ──────────────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _SectionHeader('Device'),

                  // Device ID — focusable display row (select copies ID)
                  _DeviceIdRow(
                    focusNode: _deviceIdNode,
                    upNode:    _backNode,
                    downNode:  _managePlNode,
                  ),

                  // Manage Playlist
                  _SettingsRow(
                    label:     'Manage Playlist',
                    value:     'izoiptv.com/authenticate',
                    showArrow: true,
                    focusNode: _managePlNode,
                    upNode:    _deviceIdNode,
                    downNode:  _refreshNode,
                    onTap: () async {
                      final uri = Uri.parse('https://izoiptv.com/authenticate');
                      if (await canLaunchUrl(uri)) await launchUrl(uri);
                    },
                  ),

                  _SectionHeader('Library'),
                  _LibraryStatusRow(),

                  // Refresh Library
                  _SettingsRow(
                    label:     'Refresh Library',
                    value:     _syncing ? 'Syncing…' : 'Refresh now',
                    showArrow: !_syncing,
                    focusNode: _refreshNode,
                    upNode:    _managePlNode,
                    downNode:  _signOutNode,
                    onTap:     _syncing ? null : _forceSync,
                  ),

                  _SectionHeader('App'),
                  _SettingsRow(label: 'Version', value: AppConstants.appVersion),
                  const SizedBox(height: AppSpacing.xl6),

                  // Sign Out
                  _SignOutRow(
                    focusNode: _signOutNode,
                    upNode:    _refreshNode,
                    onTap: () async {
                      await ref.read(authProvider.notifier).logout();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}

// ── Shared row focus mixin ─────────────────────────────────────────────────────
// Every interactive row uses the same pattern:
//   - white left-border accent when focused
//   - up/down arrows move to explicit neighbour nodes
//   - select/enter triggers the action

bool _isActivateKey(KeyEvent event) {
  if (event.logicalKey == LogicalKeyboardKey.select) return true;
  if (event.logicalKey == LogicalKeyboardKey.enter) return true;
  if (event.logicalKey == LogicalKeyboardKey.numpadEnter) return true;
  if (event.logicalKey == LogicalKeyboardKey.gameButtonA) return true;
  if (event.physicalKey.usbHidUsage == 0x00070058) return true;
  if (event.physicalKey == PhysicalKeyboardKey.select) return true;
  if (event.physicalKey == PhysicalKeyboardKey.gameButtonA) return true;
  return false;
}

KeyEventResult _rowKeyEvent(
  KeyEvent event,
  FocusNode? upNode,
  FocusNode? downNode,
  VoidCallback? onTap,
) {
  if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
  if (event.logicalKey == LogicalKeyboardKey.arrowUp   && upNode   != null) {
    upNode.requestFocus();
    return KeyEventResult.handled;
  }
  if (event.logicalKey == LogicalKeyboardKey.arrowDown && downNode != null) {
    downNode.requestFocus();
    return KeyEventResult.handled;
  }
  if (_isActivateKey(event) && onTap != null) {
    onTap();
    return KeyEventResult.handled;
  }
  return KeyEventResult.ignored;
}

// ── Settings Row ───────────────────────────────────────────────────────────────

class _SettingsRow extends StatefulWidget {
  const _SettingsRow({
    required this.label,
    this.value,
    this.onTap,
    this.showArrow = false,
    this.focusNode,
    this.upNode,
    this.downNode,
  });
  final String        label;
  final String?       value;
  final VoidCallback? onTap;
  final bool          showArrow;
  final FocusNode?    focusNode;
  final FocusNode?    upNode;
  final FocusNode?    downNode;

  @override
  State<_SettingsRow> createState() => _SettingsRowState();
}

class _SettingsRowState extends State<_SettingsRow> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final content = AnimatedContainer(
      duration: AppDurations.medium,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.tvH,
        vertical:   AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: _focused ? const Color(0x0AFFFFFF) : Colors.transparent,
        border: Border(
          left: BorderSide(
            color: _focused ? AppColors.focusBorder : Colors.transparent,
            width: 2.5,
          ),
          bottom: const BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Text(
            widget.label,
            style: const TextStyle(
              color:      AppColors.textPrimary,
              fontSize:   13,
              fontWeight: FontWeight.w400,
            ),
          ),
          const Spacer(),
          if (widget.value != null)
            Text(
              widget.value!,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          if (widget.showArrow) ...[
            const SizedBox(width: 6),
            const Icon(Icons.arrow_forward_ios, color: AppColors.textMuted, size: 10),
          ],
        ],
      ),
    );

    // Display-only rows (no focusNode, no onTap)
    if (widget.focusNode == null && widget.onTap == null) return content;

    return Focus(
      focusNode:     widget.focusNode,
      onFocusChange: (f) { if (mounted) setState(() => _focused = f); },
      onKeyEvent: (_, event) => _rowKeyEvent(
        event, widget.upNode, widget.downNode, widget.onTap,
      ),
      child: GestureDetector(
        onTap:  widget.onTap,
        child:  content,
      ),
    );
  }
}

// ── Sign Out Row ───────────────────────────────────────────────────────────────

class _SignOutRow extends StatefulWidget {
  const _SignOutRow({
    required this.focusNode,
    required this.upNode,
    required this.onTap,
  });
  final FocusNode    focusNode;
  final FocusNode    upNode;
  final VoidCallback onTap;

  @override
  State<_SignOutRow> createState() => _SignOutRowState();
}

class _SignOutRowState extends State<_SignOutRow> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode:     widget.focusNode,
      onFocusChange: (f) { if (mounted) setState(() => _focused = f); },
      onKeyEvent: (_, event) => _rowKeyEvent(
        event, widget.upNode, null, widget.onTap,
      ),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppDurations.medium,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.tvH,
            vertical:   AppSpacing.lg,
          ),
          decoration: BoxDecoration(
            color: _focused ? const Color(0x0AFFFFFF) : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: _focused ? AppColors.focusBorder : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          child: Center(
            child: Text(
              'Sign Out',
              style: const TextStyle(
                color:      Color(0xFFE57373),
                fontSize:   13,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Library Status Row ─────────────────────────────────────────────────────────

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
            style: const TextStyle(
              color:      AppColors.textPrimary,
              fontSize:   13,
              fontWeight: FontWeight.w400,
            ),
          ),
          const Spacer(),
          if (active) ...[
            const SizedBox(
              width: 10, height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            value,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ── Section Header ─────────────────────────────────────────────────────────────

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
        style: const TextStyle(
          color:         AppColors.textMuted,
          fontSize:      10,
          fontWeight:    FontWeight.w500,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ── Device ID Row ─────────────────────────────────────────────────────────────

class _DeviceIdRow extends StatefulWidget {
  const _DeviceIdRow({
    required this.focusNode,
    required this.upNode,
    required this.downNode,
  });
  final FocusNode focusNode;
  final FocusNode upNode;
  final FocusNode downNode;

  @override
  State<_DeviceIdRow> createState() => _DeviceIdRowState();
}

class _DeviceIdRowState extends State<_DeviceIdRow> {
  String? _id;
  bool    _copied  = false;
  bool    _focused = false;

  @override
  void initState() {
    super.initState();
    DeviceIdService.instance.getDeviceId().then((id) {
      if (mounted) setState(() => _id = id);
    });
  }

  Future<void> _copy() async {
    if (_id == null) return;
    await Clipboard.setData(ClipboardData(text: _id!));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode:     widget.focusNode,
      onFocusChange: (f) { if (mounted) setState(() => _focused = f); },
      onKeyEvent: (_, event) => _rowKeyEvent(
        event, widget.upNode, widget.downNode, _copy,
      ),
      child: GestureDetector(
        onTap: _copy,
        child: AnimatedContainer(
          duration: AppDurations.medium,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.tvH,
            vertical:   AppSpacing.lg,
          ),
          decoration: BoxDecoration(
            color: _focused ? const Color(0x0AFFFFFF) : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: _focused ? AppColors.focusBorder : Colors.transparent,
                width: 2.5,
              ),
              bottom: const BorderSide(color: AppColors.border, width: 0.5),
            ),
          ),
          child: Row(
            children: [
              Text(
                'Device ID',
                style: const TextStyle(
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
                    color:         AppColors.textMuted,
                    fontSize:      11,
                    fontFamily:    'monospace',
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  child: Icon(
                    _copied ? Icons.check : Icons.copy_outlined,
                    key:   ValueKey(_copied),
                    color: _copied ? AppColors.success : AppColors.textMuted,
                    size:  14,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
