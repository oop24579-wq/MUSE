import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:uuid/uuid.dart';

class DeviceIdService {
  static final DeviceIdService _instance = DeviceIdService._internal();
  static DeviceIdService get instance => _instance;

  DeviceIdService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  final Uuid _uuid = const Uuid();

  String? _cachedDeviceId;
  static const String _storageKey = 'device_unique_identity';

  /// Get a persistent Device ID that survives app uninstalls (best effort)
  Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) {
      return _cachedDeviceId!;
    }

    String? deviceId;

    try {
      if (Platform.isAndroid) {
        // Android: Usage of android_id is the standard for persistence across re-installs
        final androidInfo = await _deviceInfo.androidInfo;
        deviceId = androidInfo.id;

        // Fallback if android_id is problematic
        if (deviceId.isEmpty || deviceId == 'unknown') {
          deviceId = await _getFromStorageOrGenerate();
        }
      } else if (Platform.isIOS) {
        // iOS: Keychain data persists across uninstalls
        deviceId = await _getFromStorageOrGenerate();
      } else {
        // Web/Desktop
        deviceId = await _getFromStorageOrGenerate();
      }
    } catch (e) {
      debugPrint('❌ Error getting device ID: $e');
      // Ultimate fallback
      deviceId = await _getFromStorageOrGenerate();
    }

    _cachedDeviceId = deviceId;
    debugPrint('📱 Device ID resolved: $deviceId');
    return deviceId;
  }

  /// Helper: Check Secure Storage or Generate new UUID
  Future<String> _getFromStorageOrGenerate() async {
    // 1. Try to read from Secure Storage
    String? storedId;
    try {
      storedId = await _storage.read(key: _storageKey);
    } catch (e) {
      debugPrint('⚠️ Error reading secure storage: $e');
    }

    if (storedId != null && storedId.isNotEmpty) {
      return storedId;
    }

    // 2. Generate new UUID
    final newId = _uuid.v4();

    // 3. Save to Secure Storage
    try {
      await _storage.write(key: _storageKey, value: newId);
    } catch (e) {
      debugPrint('⚠️ Error writing to secure storage: $e');
    }

    return newId;
  }
}
