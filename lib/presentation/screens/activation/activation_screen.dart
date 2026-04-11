import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/providers.dart';
import '../../widgets/common/app_logo.dart';
import '../../widgets/common/focusable_widget.dart';
import '../../../services/device_id_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/device_service.dart';

class IzoActivationScreen extends ConsumerStatefulWidget {
  const IzoActivationScreen({super.key});

  @override
  ConsumerState<IzoActivationScreen> createState() => _IzoActivationScreenState();
}

class _IzoActivationScreenState extends ConsumerState<IzoActivationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;
  Timer?   _pollTimer;
  String?  _deviceId;
  bool     _loading = true;

  @override
  void initState() {
    super.initState();

    // Breathing pulse animation: 0.98 → 1.0, 2 seconds
    _pulseCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(seconds: 2),
    );
    _pulseAnim = Tween<double>(begin: 0.98, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _pulseCtrl.repeat(reverse: true);

    _init();
  }

  Future<void> _init() async {
    final id = await DeviceIdService.instance.getDeviceId();
    if (!mounted) return;
    setState(() { _deviceId = id; _loading = false; });
    _startPolling();
  }

  void _startPolling() {
    _poll(); // poll immediately
    _pollTimer = Timer.periodic(AppConstants.activationPollInterval, (_) => _poll());
  }

  Future<void> _poll() async {
    if (_deviceId == null) return;
    final result = await ref.read(activationServiceProvider).checkActivation(_deviceId!);
    if (!mounted) return;

    final creds = result.credentials;
    if (creds == null) return;

    _pollTimer?.cancel();

    await DeviceService.instance.saveActivationCredentials(
      playlistType:     creds.playlistType,
      xtreamServer:     creds.xtreamServer,
      xtreamUsername:   creds.xtreamUsername,
      xtreamPassword:   creds.xtreamPassword,
      m3uUrl:           creds.m3uUrl,
      expiryDate:       creds.expiryDate,
      displayName:      creds.displayName,
      subscriptionPlan: creds.subscriptionPlan,
    );

    final loginCreds = <String, String>{};
    if (creds.playlistType == 'xtream') {
      if (creds.xtreamServer   != null) loginCreds[AppConstants.keyServerUrl] = creds.xtreamServer!;
      if (creds.xtreamUsername != null) loginCreds[AppConstants.keyUsername]  = creds.xtreamUsername!;
      if (creds.xtreamPassword != null) loginCreds[AppConstants.keyPassword]  = creds.xtreamPassword!;
    } else {
      if (creds.m3uUrl != null) loginCreds[AppConstants.keyM3uUrl] = creds.m3uUrl!;
    }

    await ref.read(authProvider.notifier).loginFromActivation(
      loginType:   creds.playlistType,
      credentials: loginCreds,
    );
  }

  void _copy(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 12)),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl3),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const IzoLogo(size: 72),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'izoiptv.com',
                  style: TextStyle(
                    color:    AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl4),

                // Device ID card with pulse
                if (_loading)
                  const SizedBox(
                    width:  20,
                    height: 20,
                    child:  CircularProgressIndicator(strokeWidth: 1, color: AppColors.textMuted),
                  )
                else
                  ScaleTransition(
                    scale: _pulseAnim,
                    child: _CredentialCard(
                      label: 'MAC ADDRESS',
                      value: _deviceId ?? '',
                      autofocus: true,
                      onCopy: () => _copy(_deviceId!, 'MAC address copied'),
                    ),
                  ),

                const SizedBox(height: AppSpacing.xl2),
                const Text(
                  'Go to izoiptv.com/authenticate\nand enter the MAC address above to activate',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color:    AppColors.textSecondary,
                    fontSize: 13,
                    height:   1.6,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'App will load automatically once your playlist is added',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
                const SizedBox(height: AppSpacing.xl3),

                // Polling indicator
                const SizedBox(
                  width:  14,
                  height: 14,
                  child:  CircularProgressIndicator(
                    strokeWidth: 1,
                    color: AppColors.textMuted,
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

class _CredentialCard extends StatelessWidget {
  const _CredentialCard({
    required this.label,
    required this.value,
    required this.autofocus,
    required this.onCopy,
    this.bigValue = false,
  });

  final String label;
  final String value;
  final bool autofocus;
  final bool bigValue;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical:   AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: AppColors.glassBorder, width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: SelectableText(
                  value,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color:      AppColors.textPrimary,
                    fontSize:   bigValue ? 28 : 18,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                    letterSpacing: bigValue ? 6 : 2,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (onCopy != null)
                FocusableWidget(
                  autofocus: autofocus,
                  borderRadius: 6,
                  onTap: onCopy!,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.copy_outlined,
                      color: AppColors.textSecondary,
                      size:  18,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
