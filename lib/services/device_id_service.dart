import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

class DeviceIdService {
  DeviceIdService._();
  static final DeviceIdService instance = DeviceIdService._();

  static const _keyDeviceId = 'device_id_v1';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  String? _cached;

  Future<String> getDeviceId() async {
    if (_cached != null) return _cached!;

    // Return persisted ID from previous run
    final stored = await _storage.read(key: _keyDeviceId);
    if (stored != null && stored.isNotEmpty) {
      _cached = stored;
      return _cached!;
    }

    // Generate a new unique ID for this device and persist it
    final id = const Uuid().v4();
    await _storage.write(key: _keyDeviceId, value: id);
    _cached = id;
    return _cached!;
  }
}
