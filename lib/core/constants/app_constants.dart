abstract final class AppConstants {
  // Database
  static const dbName    = 'izo_iptv.db';
  static const dbVersion = 2;

  // Secure storage keys (used by AuthRepositoryImpl)
  static const keyLoginType = 'login_type';
  static const keyServerUrl = 'server_url';
  static const keyUsername  = 'username';
  static const keyPassword  = 'password';
  static const keyM3uUrl    = 'm3u_url';

  // Layout
  static const double channelRowHeight    = 56.0;
  static const double posterAspectRatio   = 2 / 3;
  static const double homeTopBarHeight    = 56.0;
  static const double homeSafeAreaPadding = 32.0;

  // Activation
  static const activationBaseUrl      = 'https://www.izoiptv.com';
  static const activationPollInterval = Duration(seconds: 15);
}
