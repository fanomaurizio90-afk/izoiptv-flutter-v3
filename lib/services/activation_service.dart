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

class ActivationCheckResult {
  const ActivationCheckResult({this.credentials, this.pin});
  final ActivationCredentials? credentials;
  final String? pin;
}

class ActivationService {
  ActivationService(this._dio);
  final Dio _dio;

  // CRITICAL: www.izoiptv.com — NOT api.izoiptv.com
  static const _baseUrl = AppConstants.activationBaseUrl;

  Future<ActivationCheckResult> checkActivation(String deviceId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_baseUrl/api/activate',
        queryParameters: {'device_id': deviceId},
      );
      final data = response.data;
      if (data == null) return const ActivationCheckResult();

      final pin = data['pin'] as String?;

      if (data['activated'] != true) {
        return ActivationCheckResult(pin: pin);
      }

      return ActivationCheckResult(
        pin: pin,
        credentials: ActivationCredentials(
          playlistType:     data['playlist_type'] as String? ?? 'xtream',
          xtreamServer:     data['xtream_server']   as String?,
          xtreamUsername:   data['xtream_username'] as String?,
          xtreamPassword:   data['xtream_password'] as String?,
          m3uUrl:           data['m3u_url']         as String?,
          expiryDate:       data['expiry_date']     as String?,
          displayName:      data['display_name']    as String?,
          subscriptionPlan: data['subscription_plan'] as String?,
        ),
      );
    } catch (_) {
      return const ActivationCheckResult(); // Always silent — never show error
    }
  }
}
