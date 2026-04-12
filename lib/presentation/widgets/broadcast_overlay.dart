import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../services/broadcast_service.dart';
import '../providers/broadcast_provider.dart';

/// Wraps the app and overlays a dismissible modal whenever an active broadcast
/// is available. Intercepts the remote/back key so the overlay consumes it
/// before the app's default back handler.
class BroadcastOverlay extends ConsumerStatefulWidget {
  const BroadcastOverlay({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<BroadcastOverlay> createState() => _BroadcastOverlayState();
}

class _BroadcastOverlayState extends ConsumerState<BroadcastOverlay> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'BroadcastOverlay');

  @override
  void initState() {
    super.initState();
    // Start polling immediately on app launch — independent of auth state.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(broadcastProvider.notifier).start();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  static bool _isBackKey(KeyEvent e) {
    final lk = e.logicalKey;
    return lk == LogicalKeyboardKey.goBack
        || lk == LogicalKeyboardKey.escape
        || lk == LogicalKeyboardKey.browserBack
        || lk == LogicalKeyboardKey.gameButtonB;
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final broadcast = ref.watch(broadcastProvider);

    // Request focus when a broadcast appears so the Focus below us catches keys.
    if (broadcast != null && !_focusNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ref.read(broadcastProvider) != null) {
          _focusNode.requestFocus();
        }
      });
    }

    return Stack(
      children: [
        widget.child,
        if (broadcast != null)
          Positioned.fill(
            child: Focus(
              focusNode: _focusNode,
              autofocus: true,
              onKeyEvent: (_, event) {
                if (event is! KeyDownEvent) return KeyEventResult.ignored;
                if (!_isBackKey(event))     return KeyEventResult.ignored;
                if (broadcast.mandatory)    return KeyEventResult.handled; // absorb
                ref.read(broadcastProvider.notifier).dismiss();
                return KeyEventResult.handled;
              },
              child: _BroadcastModal(
                broadcast: broadcast,
                onDismiss: broadcast.mandatory
                    ? null
                    : () => ref.read(broadcastProvider.notifier).dismiss(),
                onDownload: broadcast.isUpdate && broadcast.apkUrl != null
                    ? () => _openUrl(broadcast.apkUrl!)
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}

class _BroadcastModal extends StatelessWidget {
  const _BroadcastModal({
    required this.broadcast,
    required this.onDismiss,
    required this.onDownload,
  });

  final Broadcast      broadcast;
  final VoidCallback?  onDismiss;
  final VoidCallback?  onDownload;

  @override
  Widget build(BuildContext context) {
    final isUpdate = broadcast.isUpdate;
    final accent   = isUpdate ? AppColors.accentPrimary : AppColors.accentPrimary;

    return Material(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 560),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
              border: Border.all(color: accent.withValues(alpha: 0.3), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: accent.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        isUpdate ? 'UPDATE AVAILABLE' : 'ANNOUNCEMENT',
                        style: TextStyle(
                          color: accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    if (isUpdate && broadcast.version != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        'v${broadcast.version}',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  broadcast.title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  broadcast.body,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (onDismiss != null)
                      TextButton(
                        onPressed: onDismiss,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        child: Text(isUpdate ? 'Later' : 'Dismiss'),
                      ),
                    if (onDownload != null) ...[
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: onDownload,
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          textStyle: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        child: const Text('Download'),
                      ),
                    ],
                  ],
                ),
                if (broadcast.mandatory && !isUpdate) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'This message cannot be dismissed.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 10),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
