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
    if (!mounted || result == null) return;

    _pollTimer?.cancel();

    // Save activation credentials
    await DeviceService.instance.saveActivationCredentials(
      playlistType:     result.playlistType,
      xtreamServer:     result.xtreamServer,
      xtreamUsername:   result.xtreamUsername,
      xtreamPassword:   result.xtreamPassword,
      m3uUrl:           result.m3uUrl,
      expiryDate:       result.expiryDate,
      displayName:      result.displayName,
      subscriptionPlan: result.subscriptionPlan,
    );

    // Build credentials map for auth provider
    final creds = <String, String>{};
    if (result.playlistType == 'xtream') {
      if (result.xtreamServer   != null) creds[AppConstants.keyServerUrl] = result.xtreamServer!;
      if (result.xtreamUsername != null) creds[AppConstants.keyUsername]  = result.xtreamUsername!;
      if (result.xtreamPassword != null) creds[AppConstants.keyPassword]  = result.xtreamPassword!;
    } else {
      if (result.m3uUrl != null) creds[AppConstants.keyM3uUrl] = result.m3uUrl!;
    }

    await ref.read(authProvider.notifier).loginFromActivation(
      loginType:   result.playlistType,
      credentials: creds,
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
    return Scaffold(
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
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical:   AppSpacing.md,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                        border: Border.all(color: AppColors.border, width: 0.5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: SelectableText(
                              _deviceId ?? '',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color:      AppColors.textPrimary,
                                fontSize:   18,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'monospace',
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          FocusableWidget(
                            borderRadius: 6,
                            onTap: () {
                              if (_deviceId != null) {
                                Clipboard.setData(ClipboardData(text: _deviceId!));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Device ID copied'),
                                    duration: Duration(seconds: 2),
                                    backgroundColor: AppColors.card,
                                  ),
                                );
                              }
                            },
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
                    ),
                  ),

                const SizedBox(height: AppSpacing.xl2),
                const Text(
                  'Go to izoiptv.com/authenticate\nand enter this code to add your playlist',
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
    );
  }
}
