import 'package:dio/dio.dart';
import '../core/constants/app_constants.dart';

class ActivationCredentials {
  const ActivationCredentials({
    required this.playlistType,
    this.xtreamServer,
    this.xtreamUsername,
    this.xtreamPassword,
    this.m3uUrl,
    this.expiryDate,
    this.displayName,
    this.subscriptionPlan,
  });
  final String  playlistType;
  final String? xtreamServer;
  final String? xtreamUsername;
  final String? xtreamPassword;
  final String? m3uUrl;
  final String? expiryDate;
  final String? displayName;
  final String? subscriptionPlan;
}

class ActivationService {
  ActivationService._();
  static final ActivationService instance = ActivationService._();

  // CRITICAL: www.izoiptv.com — NOT api.izoiptv.com
  static const _baseUrl = AppConstants.activationBaseUrl;

  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
  ));

  Future<ActivationCredentials?> checkActivation(String deviceId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_baseUrl/api/activate',
        queryParameters: {'device_id': deviceId},
      );
      final data = response.data;
      if (data == null || data['activated'] != true) return null;

      return ActivationCredentials(
        playlistType:     data['playlist_type'] as String? ?? 'xtream',
        xtreamServer:     data['xtream_server']   as String?,
        xtreamUsername:   data['xtream_username'] as String?,
        xtreamPassword:   data['xtream_password'] as String?,
        m3uUrl:           data['m3u_url']         as String?,
        expiryDate:       data['expiry_date']     as String?,
        displayName:      data['display_name']    as String?,
        subscriptionPlan: data['subscription_plan'] as String?,
      );
    } catch (_) {
      return null; // Always silent — never show error
    }
  }
}
