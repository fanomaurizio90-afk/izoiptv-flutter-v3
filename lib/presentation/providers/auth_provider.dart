import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/device_service.dart';
import '../../domain/entities/user_info.dart';
import 'providers.dart';

// ─── Auth States ─────────────────────────────────────────────────────────────

sealed class AuthState { const AuthState(); }
final class AuthUnknown       extends AuthState { const AuthUnknown(); }    // INITIAL — before tryAutoLogin
final class AuthInitial       extends AuthState { const AuthInitial(); }    // no credentials ever
final class AuthLoading       extends AuthState { const AuthLoading(); }
final class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);
  final UserInfo user;
}
final class AuthExpired  extends AuthState { const AuthExpired(); }
final class AuthError    extends AuthState {
  const AuthError(this.message);
  final String message;
}

// ─── Auth Notifier ────────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._ref) : super(const AuthUnknown()); // MUST be AuthUnknown

  final Ref _ref;

  /// Called by splash screen once on start
  Future<void> tryAutoLogin() async {
    state = const AuthLoading();
    try {
      final repo = _ref.read(authRepositoryProvider);
      final user = await repo.loadSession();
      if (user == null) {
        state = const AuthInitial();
      } else {
        // Check activation expiry stored by DeviceService
        final expiryStr = await DeviceService.instance.readExpiryDate();
        if (expiryStr != null) {
          final expiry = DateTime.tryParse(expiryStr);
          if (expiry != null && DateTime.now().isAfter(expiry)) {
            state = const AuthExpired();
            return;
          }
        }
        // Check Xtream subscription expiry (Unix timestamp from exp_date field)
        if (_isExpired(user.expiryDate)) {
          state = const AuthExpired();
          return;
        }
        state = AuthAuthenticated(user);
      }
    } catch (e) {
      // Network/transient error — show retry instead of clearing session
      state = AuthError(e.toString());
    }
  }

  /// Manual Xtream login from auth screen
  Future<void> loginXtream(String serverUrl, String username, String password) async {
    state = const AuthLoading();
    try {
      final repo = _ref.read(authRepositoryProvider);
      final user = await repo.authenticateXtream(
        serverUrl: serverUrl,
        username:  username,
        password:  password,
      );
      await repo.saveSession(
        loginType:   'xtream',
        credentials: {
          AppConstants.keyServerUrl: serverUrl,
          AppConstants.keyUsername:  username,
          AppConstants.keyPassword:  password,
        },
        userInfo: user,
      );
      // Subscription already expired at login time
      if (_isExpired(user.expiryDate)) {
        state = const AuthExpired();
        return;
      }
      state = AuthAuthenticated(user);
    } catch (e) {
      state = AuthError(e.toString());
    }
  }

  /// M3U login
  Future<void> loginM3u(String m3uUrl) async {
    state = const AuthLoading();
    try {
      final repo = _ref.read(authRepositoryProvider);
      final user = UserInfo(username: 'm3u', status: 'Active', loginType: 'm3u');
      await repo.saveSession(
        loginType:   'm3u',
        credentials: {AppConstants.keyM3uUrl: m3uUrl},
        userInfo:    user,
      );
      state = AuthAuthenticated(user);
    } catch (e) {
      state = AuthError(e.toString());
    }
  }

  /// Called after device activation — does NOT validate against IPTV server
  Future<void> loginFromActivation({
    required String loginType,
    required Map<String, String> credentials,
  }) async {
    state = const AuthLoading();
    try {
      final repo = _ref.read(authRepositoryProvider);
      final user = UserInfo(
        username:  credentials[AppConstants.keyUsername] ?? 'user',
        status:    'Active',
        loginType: loginType,
        serverUrl: credentials[AppConstants.keyServerUrl],
      );
      await repo.saveSession(
        loginType:   loginType,
        credentials: credentials,
        userInfo:    user,
      );
      state = AuthAuthenticated(user);
    } catch (e) {
      state = AuthError(e.toString());
    }
  }

  Future<void> logout() async {
    try {
      await _ref.read(authRepositoryProvider).clearSession();
    } catch (_) {}
    state = const AuthInitial();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Returns true if the Xtream exp_date Unix timestamp is in the past.
  /// null, "0", "-1" all mean unlimited per Xtream API docs — never expired.
  static bool _isExpired(String? expDate) {
    if (expDate == null) return false;
    final secs = int.tryParse(expDate);
    if (secs == null || secs <= 0) return false;
    return DateTime.fromMillisecondsSinceEpoch(secs * 1000).isBefore(DateTime.now());
  }

  /// Days remaining until expiry. Null = unlimited or unparseable.
  static int? daysUntilExpiry(String? expDate) {
    if (expDate == null) return null;
    final secs = int.tryParse(expDate);
    if (secs == null || secs <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(secs * 1000)
        .difference(DateTime.now())
        .inDays;
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});
