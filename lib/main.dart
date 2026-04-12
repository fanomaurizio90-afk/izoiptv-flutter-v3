import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'app_router.dart';
import 'core/theme/app_theme.dart';
import 'presentation/widgets/broadcast_overlay.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized(); // MUST be before runApp
  // Edge-to-edge so SafeArea insets are always correct on Fire Stick
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  // Cap decoded-image RAM: 500 images / 200 MB — safe for Fire Stick's limited memory
  PaintingBinding.instance.imageCache
    ..maximumSize      = 500
    ..maximumSizeBytes = 200 * 1024 * 1024;
  runApp(const ProviderScope(child: IzoApp()));
}

class IzoApp extends ConsumerWidget {
  const IzoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title:             'IZO IPTV',
      theme:             AppTheme.dark,
      routerConfig:      router,
      debugShowCheckedModeBanner: false,
      // _BackKeyHandler runs inside MaterialApp so GoRouter.of(context) is valid.
      builder: (context, child) => BroadcastOverlay(
        child: _BackKeyHandler(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}

/// Intercepts all back key variants at the root of the navigator.
///
/// Placed via MaterialApp.builder so GoRouter.of(context) is valid and key
/// events from focused screens bubble up correctly through the Focus tree.
///
/// Handles every key code Fire Stick / Android TV remotes use for "back":
///   goBack      — KEYCODE_BACK (4), most Fire Stick remotes
///   escape      — keyboards / emulators
///   browserBack — some remotes map to browser back
///   gameButtonB — Android TV game controllers
///
/// When canPop is false (home screen) the event is left unhandled so Android's
/// system back fires → triggers PopScope → shows the exit dialog.
class _BackKeyHandler extends StatelessWidget {
  const _BackKeyHandler({required this.child});
  final Widget child;

  static bool _isBackKey(KeyEvent event) {
    final lk = event.logicalKey;
    if (lk == LogicalKeyboardKey.goBack)      return true;
    if (lk == LogicalKeyboardKey.escape)      return true;
    if (lk == LogicalKeyboardKey.browserBack) return true;
    if (lk == LogicalKeyboardKey.gameButtonB) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      autofocus: false,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (!_isBackKey(event))    return KeyEventResult.ignored;

        final router = GoRouter.of(context);
        if (router.canPop()) {
          router.pop();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: child,
    );
  }
}

