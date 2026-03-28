abstract final class AppConstants {
  // App version — mirrors pubspec.yaml version field; update both together
  static const appVersion     = '2.9.0';
  static const appVersionCode = 15;

  // Database
  static const dbName    = 'izo_iptv.db';
  static const dbVersion = 3;

  // Secure storage keys (used by AuthRepositoryImpl)
  static const keyLoginType = 'login_type';
  static const keyServerUrl = 'server_url';
  static const keyUsername  = 'username';
  static const keyPassword  = 'password';
  static const keyM3uUrl    = 'm3u_url';
  static const keyExpDate        = 'exp_date';         // Unix-timestamp string from Xtream
  static const keyLiveFormat     = 'live_format';       // Preferred live stream format (ts/m3u8)
  static const keyVodFormat      = 'vod_format';        // Preferred VOD format (mp4/mkv/ts)

  // Layout
  static const double channelRowHeight    = 72.0;
  static const double posterAspectRatio   = 2 / 3;
  static const double homeTopBarHeight    = 56.0;
  static const double homeSafeAreaPadding = 32.0;

  // Activation
  static const activationBaseUrl      = 'https://www.izoiptv.com';
  static const activationPollInterval = Duration(seconds: 15);
}
