import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/app_logo.dart';
import '../../widgets/common/loading_widget.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  // Login method toggle
  bool _isXtream = true;

  // Xtream fields
  final _serverCtrl   = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  // M3U field
  final _m3uCtrl = TextEditingController();

  @override
  void dispose() {
    _serverCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _m3uCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_isXtream) {
      final server   = _serverCtrl.text.trim();
      final username = _usernameCtrl.text.trim();
      final password = _passwordCtrl.text.trim();
      if (server.isEmpty || username.isEmpty || password.isEmpty) return;
      await ref.read(authProvider.notifier).loginXtream(server, username, password);
    } else {
      final url = _m3uCtrl.text.trim();
      if (url.isEmpty) return;
      await ref.read(authProvider.notifier).loginM3u(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isLoading = auth is AuthLoading;

    String? error;
    if (auth is AuthError) error = auth.message;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl3,
              vertical:   AppSpacing.xl5,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: IzoLogo(size: 64)),
                const SizedBox(height: AppSpacing.sm),
                const Center(
                  child: Text(
                    'izoiptv.com',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl4),

                // Method toggle
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _isXtream = true),
                      child: Text(
                        'Xtream Codes',
                        style: TextStyle(
                          color:      _isXtream ? AppColors.textPrimary : AppColors.textMuted,
                          fontSize:   13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    GestureDetector(
                      onTap: () => setState(() => _isXtream = false),
                      child: Text(
                        'M3U URL',
                        style: TextStyle(
                          color:      !_isXtream ? AppColors.textPrimary : AppColors.textMuted,
                          fontSize:   13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl3),

                // Fields
                if (_isXtream) ...[
                  _buildField(_serverCtrl,   'Server URL',  TextInputType.url),
                  const SizedBox(height: AppSpacing.lg),
                  _buildField(_usernameCtrl, 'Username'),
                  const SizedBox(height: AppSpacing.lg),
                  _buildField(_passwordCtrl, 'Password',    TextInputType.text, true),
                ] else ...[
                  _buildField(_m3uCtrl, 'M3U URL', TextInputType.url),
                ],

                // Error
                if (error != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color:        AppColors.errorSurface,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                    ),
                    child: Text(
                      error,
                      style: const TextStyle(color: AppColors.error, fontSize: 12),
                    ),
                  ),
                ],

                const SizedBox(height: AppSpacing.xl3),

                // Login button
                if (isLoading)
                  const LoadingWidget()
                else
                  GestureDetector(
                    onTap: _login,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                      decoration: BoxDecoration(
                        color:        AppColors.card,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                        border:       Border.all(color: AppColors.accentSoft, width: 0.5),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'Sign In',
                        style: TextStyle(
                          color:      AppColors.textPrimary,
                          fontSize:   14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(
    TextEditingController ctrl,
    String hint, [
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
  ]) {
    return TextField(
      controller:      ctrl,
      keyboardType:    keyboardType,
      obscureText:     obscure,
      style:           const TextStyle(color: AppColors.textPrimary, fontSize: 13),
      decoration:      InputDecoration(hintText: hint),
    );
  }
}
