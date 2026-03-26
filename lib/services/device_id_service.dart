import 'dart:math';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DeviceIdService {
  DeviceIdService._();
  static final DeviceIdService instance = DeviceIdService._();

  // v2 key — new MAC format; old UUID stored under v1 is ignored.
  static const _keyDeviceId = 'device_id_v2';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  String? _cached;

  Future<String> getDeviceId() async {
    if (_cached != null) return _cached!;

    final stored = await _storage.read(key: _keyDeviceId);
    if (stored != null && stored.isNotEmpty) {
      _cached = stored;
      return _cached!;
    }

    final id = await _generateMacId();
    await _storage.write(key: _keyDeviceId, value: id);
    _cached = id;
    return _cached!;
  }

  /// Returns a stable, device-unique code in MAC address format (XX:XX:XX:XX:XX:XX).
  /// Derived from the Android ID (stable per device), falling back to random bytes.
  Future<String> _generateMacId() async {
    try {
      final android = await DeviceInfoPlugin().androidInfo;
      // android.id is typically a 16-char lowercase hex string
      final hex = android.id.replaceAll(RegExp(r'[^a-fA-F0-9]'), '');
      if (hex.length >= 12) {
        return _asMac(hex.substring(0, 12).toUpperCase());
      }
    } catch (_) {}

    // Fallback: 6 cryptographically random bytes
    final rand  = Random.secure();
    final bytes = List.generate(6, (_) => rand.nextInt(256));
    return bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(':');
  }

  /// Formats a 12-char uppercase hex string as XX:XX:XX:XX:XX:XX.
  static String _asMac(String h) =>
      [0, 2, 4, 6, 8, 10].map((i) => h.substring(i, i + 2)).join(':');
}
