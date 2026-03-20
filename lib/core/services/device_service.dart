import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DeviceService {
  DeviceService._();
  static final DeviceService instance = DeviceService._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _keyActivated        = 'act_activated';
  static const _keyPlaylistType     = 'act_playlist_type';
  static const _keyXtreamServer     = 'act_xtream_server';
  static const _keyXtreamUsername   = 'act_xtream_username';
  static const _keyXtreamPassword   = 'act_xtream_password';
  static const _keyM3uUrl           = 'act_m3u_url';
  static const _keyExpiryDate       = 'act_expiry_date';
  static const _keyDisplayName      = 'act_display_name';
  static const _keySubscriptionPlan = 'act_subscription_plan';

  Future<void> saveActivationCredentials({
    required String playlistType,
    String? xtreamServer,
    String? xtreamUsername,
    String? xtreamPassword,
    String? m3uUrl,
    String? expiryDate,
    String? displayName,
    String? subscriptionPlan,
  }) async {
    await _storage.write(key: _keyActivated,    value: 'true');
    await _storage.write(key: _keyPlaylistType, value: playlistType);
    if (xtreamServer   != null) await _storage.write(key: _keyXtreamServer,     value: xtreamServer);
    if (xtreamUsername != null) await _storage.write(key: _keyXtreamUsername,   value: xtreamUsername);
    if (xtreamPassword != null) await _storage.write(key: _keyXtreamPassword,   value: xtreamPassword);
    if (m3uUrl         != null) await _storage.write(key: _keyM3uUrl,           value: m3uUrl);
    if (expiryDate     != null) await _storage.write(key: _keyExpiryDate,       value: expiryDate);
    if (displayName    != null) await _storage.write(key: _keyDisplayName,      value: displayName);
    if (subscriptionPlan != null) await _storage.write(key: _keySubscriptionPlan, value: subscriptionPlan);
  }

  Future<bool> isActivated() async {
    final val = await _storage.read(key: _keyActivated);
    return val == 'true';
  }

  Future<void> clearActivation() async {
    await _storage.delete(key: _keyActivated);
    await _storage.delete(key: _keyPlaylistType);
    await _storage.delete(key: _keyXtreamServer);
    await _storage.delete(key: _keyXtreamUsername);
    await _storage.delete(key: _keyXtreamPassword);
    await _storage.delete(key: _keyM3uUrl);
    await _storage.delete(key: _keyExpiryDate);
    await _storage.delete(key: _keyDisplayName);
    await _storage.delete(key: _keySubscriptionPlan);
  }
}
