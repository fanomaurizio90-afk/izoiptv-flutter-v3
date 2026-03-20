import '../entities/user_info.dart';

abstract interface class AuthRepository {
  Future<UserInfo?> loadSession();
  Future<void> saveSession({
    required String loginType,
    required Map<String, String> credentials,
    required UserInfo userInfo,
  });
  Future<void> clearSession();
  Future<UserInfo> authenticateXtream({
    required String serverUrl,
    required String username,
    required String password,
  });
}
