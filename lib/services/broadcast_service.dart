import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/constants/app_constants.dart';

class Broadcast {
  const Broadcast({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.mandatory,
    this.version,
    this.apkUrl,
  });

  final int     id;
  final String  kind; // 'message' | 'update'
  final String  title;
  final String  body;
  final bool    mandatory;
  final String? version;
  final String? apkUrl;

  bool get isUpdate => kind == 'update';
}

class BroadcastService {
  BroadcastService(this._dio, this._storage);
  final Dio _dio;
  final FlutterSecureStorage _storage;

  static const _baseUrl           = AppConstants.activationBaseUrl;
  static const _lastDismissedKey  = 'broadcast_last_dismissed_id';

  Future<Broadcast?> fetchActive() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_baseUrl/api/broadcasts/active',
      );
      final data = response.data;
      if (data == null) return null;
      final raw = data['broadcast'];
      if (raw is! Map) return null;
      return Broadcast(
        id:        (raw['id'] as num).toInt(),
        kind:      raw['kind']    as String? ?? 'message',
        title:     raw['title']   as String? ?? '',
        body:      raw['body']    as String? ?? '',
        version:   raw['version'] as String?,
        apkUrl:    raw['apk_url'] as String?,
        mandatory: raw['mandatory'] == true,
      );
    } catch (_) {
      return null;
    }
  }

  Future<int?> lastDismissedId() async {
    final raw = await _storage.read(key: _lastDismissedKey);
    if (raw == null) return null;
    return int.tryParse(raw);
  }

  Future<void> markDismissed(int id) async {
    await _storage.write(key: _lastDismissedKey, value: id.toString());
  }
}
