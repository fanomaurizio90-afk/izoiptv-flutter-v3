import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'app_router.dart';
import 'core/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized(); // MUST be before runApp
  // Edge-to-edge so SafeArea insets are always correct on Fire Stick
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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
    );
  }
}
