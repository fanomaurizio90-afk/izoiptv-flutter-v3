import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/constants/app_constants.dart';
import '../../core/error/app_exception.dart';
import '../../domain/entities/user_info.dart';
import '../../domain/repositories/auth_repository.dart';
import '../remote/api/xtream_api.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._storage, this._xtream);
  final FlutterSecureStorage _storage;
  final XtreamApi            _xtream;

  @override
  Future<UserInfo?> loadSession() async {
    final loginType = await _storage.read(key: AppConstants.keyLoginType);
    if (loginType == null) return null;

    if (loginType == 'xtream') {
      final serverUrl = await _storage.read(key: AppConstants.keyServerUrl);
      final username  = await _storage.read(key: AppConstants.keyUsername);
      final password  = await _storage.read(key: AppConstants.keyPassword);
      if (serverUrl == null || username == null || password == null) return null;

      _xtream.configure(serverUrl: serverUrl, username: username, password: password);

      return UserInfo(
        username:  username,
        status:    'Active',
        serverUrl: serverUrl,
        loginType: 'xtream',
      );
    }

    if (loginType == 'm3u') {
      final m3uUrl = await _storage.read(key: AppConstants.keyM3uUrl);
      if (m3uUrl == null) return null;
      return UserInfo(username: 'm3u', status: 'Active', loginType: 'm3u');
    }

    return null;
  }

  @override
  Future<void> saveSession({
    required String loginType,
    required Map<String, String> credentials,
    required UserInfo userInfo,
  }) async {
    await _storage.write(key: AppConstants.keyLoginType, value: loginType);
    for (final entry in credentials.entries) {
      await _storage.write(key: entry.key, value: entry.value);
    }

    // CRITICAL: configure XtreamApi immediately so channels load without restart
    if (loginType == 'xtream') {
      final serverUrl = credentials[AppConstants.keyServerUrl];
      final username  = credentials[AppConstants.keyUsername];
      final password  = credentials[AppConstants.keyPassword];
      if (serverUrl != null && username != null && password != null) {
        _xtream.configure(serverUrl: serverUrl, username: username, password: password);
      }
    }
  }

  @override
  Future<void> clearSession() async {
    await _storage.delete(key: AppConstants.keyLoginType);
    await _storage.delete(key: AppConstants.keyServerUrl);
    await _storage.delete(key: AppConstants.keyUsername);
    await _storage.delete(key: AppConstants.keyPassword);
    await _storage.delete(key: AppConstants.keyM3uUrl);
  }

  @override
  Future<UserInfo> authenticateXtream({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    _xtream.configure(serverUrl: serverUrl, username: username, password: password);
    try {
      final data = await _xtream.authenticate();
      final userInfo = data['user_info'] as Map<String, dynamic>? ?? {};
      final auth = userInfo['auth'];
      if (auth == 0 || auth == '0' || auth == false) {
        throw const AuthException('Invalid username or password.');
      }
      return UserInfo(
        username:       username,
        status:         userInfo['status'] as String? ?? 'Active',
        expiryDate:     userInfo['exp_date'] as String?,
        maxConnections: int.tryParse(userInfo['max_connections']?.toString() ?? ''),
        activeCons:     int.tryParse(userInfo['active_cons']?.toString() ?? ''),
        isTrial:        (userInfo['is_trial']?.toString() ?? '0') == '1',
        loginType:      'xtream',
        serverUrl:      serverUrl,
      );
    } on AuthException {
      rethrow;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw const NetworkException('Connection timed out. Please check your server URL.');
      }
      if (e.response?.statusCode == 404) {
        throw const NetworkException('Server not found. Please check your server URL.');
      }
      throw NetworkException('No internet connection. (${e.message})');
    }
  }
}
