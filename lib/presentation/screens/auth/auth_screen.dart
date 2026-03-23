import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/app_logo.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/focusable_widget.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _isXtream = true;

  final _serverCtrl   = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _m3uCtrl      = TextEditingController();

  // Focus nodes for D-pad navigation
  final _xtreamTabNode = FocusNode();
  final _m3uTabNode    = FocusNode();
  final _serverNode    = FocusNode();
  final _usernameNode  = FocusNode();
  final _passwordNode  = FocusNode();
  final _m3uUrlNode    = FocusNode();
  final _signInNode    = FocusNode();

  @override
  void dispose() {
    _serverCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _m3uCtrl.dispose();
    _xtreamTabNode.dispose();
    _m3uTabNode.dispose();
    _serverNode.dispose();
    _usernameNode.dispose();
    _passwordNode.dispose();
    _m3uUrlNode.dispose();
    _signInNode.dispose();
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

  // Key handler for tab buttons — down arrow enters the first field
  KeyEventResult _tabKeyEvent(KeyEvent event, FocusNode firstField) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      firstField.requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // Key handler for text fields — up/down navigates between fields
  KeyEventResult _fieldKeyEvent(KeyEvent event, FocusNode? prev, FocusNode? next) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown && next != null) {
      next.requestFocus();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp && prev != null) {
      prev.requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final auth      = ref.watch(authProvider);
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
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl4),

                // ── Method toggle ─────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Focus(
                      onKeyEvent: (_, e) => _tabKeyEvent(e, _serverNode),
                      child: FocusableWidget(
                        focusNode: _xtreamTabNode,
                        autofocus: true,
                        onTap: () {
                          setState(() => _isXtream = true);
                          _serverNode.requestFocus();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          child: Text(
                            'Xtream Codes',
                            style: TextStyle(
                              color:      _isXtream ? AppColors.textPrimary : AppColors.textMuted,
                              fontSize:   13,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Focus(
                      onKeyEvent: (_, e) => _tabKeyEvent(e, _m3uUrlNode),
                      child: FocusableWidget(
                        focusNode: _m3uTabNode,
                        onTap: () {
                          setState(() => _isXtream = false);
                          _m3uUrlNode.requestFocus();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          child: Text(
                            'M3U URL',
                            style: TextStyle(
                              color:      !_isXtream ? AppColors.textPrimary : AppColors.textMuted,
                              fontSize:   13,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl3),

                // ── Fields ────────────────────────────────────────────────
                if (_isXtream) ...[
                  _buildField(
                    ctrl: _serverCtrl,   hint: 'Server URL',
                    node: _serverNode,   prev: _xtreamTabNode, next: _usernameNode,
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _buildField(
                    ctrl: _usernameCtrl, hint: 'Username',
                    node: _usernameNode, prev: _serverNode,    next: _passwordNode,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _buildField(
                    ctrl: _passwordCtrl, hint: 'Password',
                    node: _passwordNode, prev: _usernameNode,  next: _signInNode,
                    obscure: true,
                  ),
                ] else ...[
                  _buildField(
                    ctrl: _m3uCtrl,    hint: 'M3U URL',
                    node: _m3uUrlNode, prev: _m3uTabNode,   next: _signInNode,
                    keyboardType: TextInputType.url,
                  ),
                ],

                // ── Error ─────────────────────────────────────────────────
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

                // ── Sign In button ────────────────────────────────────────
                if (isLoading)
                  const LoadingWidget()
                else
                  FocusableWidget(
                    focusNode:    _signInNode,
                    borderRadius: AppSpacing.radiusCard,
                    onTap:        _login,
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

  Widget _buildField({
    required TextEditingController ctrl,
    required String     hint,
    required FocusNode  node,
    required FocusNode? prev,
    required FocusNode? next,
    TextInputType keyboardType = TextInputType.text,
    bool          obscure      = false,
  }) {
    return Focus(
      // Parent Focus intercepts up/down arrows that the TextField doesn't consume
      onKeyEvent: (_, e) => _fieldKeyEvent(e, prev, next),
      child: TextField(
        controller:      ctrl,
        focusNode:       node,
        keyboardType:    keyboardType,
        obscureText:     obscure,
        textInputAction: next != null ? TextInputAction.next : TextInputAction.done,
        onSubmitted:     (_) => next?.requestFocus(),
        style:           const TextStyle(color: AppColors.textPrimary, fontSize: 13),
        decoration:      InputDecoration(hintText: hint),
      ),
    );
  }
}
