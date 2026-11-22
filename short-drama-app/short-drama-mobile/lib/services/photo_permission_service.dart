import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service class to handle camera and photo library permissions
/// for both iOS and Android platforms
class PhotoPermissionService {
  /// Request camera permission
  static Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  /// Request photo library permission
  /// Handles different permission types based on platform and OS version
  static Future<bool> requestPhotoLibraryPermission() async {
    if (Platform.isAndroid) {
      // For Android 13+ (API 33+), use photos permission
      // For older versions, use storage permission
      final androidInfo = await _getAndroidSdkVersion();
      if (androidInfo >= 33) {
        final status = await Permission.photos.request();
        return status.isGranted || status.isLimited;
      } else {
        final status = await Permission.storage.request();
        return status.isGranted;
      }
    } else if (Platform.isIOS) {
      final status = await Permission.photos.request();
      return status.isGranted || status.isLimited;
    }
    return false;
  }

  /// Check if camera permission is granted
  static Future<bool> hasCameraPermission() async {
    final status = await Permission.camera.status;
    return status.isGranted;
  }

  /// Check if photo library permission is granted
  static Future<bool> hasPhotoLibraryPermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await _getAndroidSdkVersion();
      if (androidInfo >= 33) {
        final status = await Permission.photos.status;
        return status.isGranted || status.isLimited;
      } else {
        final status = await Permission.storage.status;
        return status.isGranted;
      }
    } else if (Platform.isIOS) {
      final status = await Permission.photos.status;
      return status.isGranted || status.isLimited;
    }
    return false;
  }

  /// Request all required permissions at once
  static Future<Map<String, bool>> requestAllPermissions() async {
    final camera = await requestCameraPermission();
    final photos = await requestPhotoLibraryPermission();

    return {
      'camera': camera,
      'photos': photos,
    };
  }

  /// Check if permission is permanently denied
  static Future<bool> isCameraPermissionPermanentlyDenied() async {
    return await Permission.camera.isPermanentlyDenied;
  }

  /// Check if photo library permission is permanently denied
  static Future<bool> isPhotoLibraryPermissionPermanentlyDenied() async {
    if (Platform.isAndroid) {
      final androidInfo = await _getAndroidSdkVersion();
      if (androidInfo >= 33) {
        return await Permission.photos.isPermanentlyDenied;
      } else {
        return await Permission.storage.isPermanentlyDenied;
      }
    } else if (Platform.isIOS) {
      return await Permission.photos.isPermanentlyDenied;
    }
    return false;
  }

  /// Open app settings for user to grant permissions manually
  static Future<bool> openSettings() async {
    return await openAppSettings();
  }

  /// Show permission dialog when permission is denied
  static Future<void> showPermissionDeniedDialog(
    BuildContext context, {
    required String permissionType,
    required VoidCallback onOpenSettings,
  }) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$permissionType Permission Required'),
        content: Text(
          'This feature requires $permissionType access. Please enable it in your device settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onOpenSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  /// Get Android SDK version
  static Future<int> _getAndroidSdkVersion() async {
    if (!Platform.isAndroid) return 0;
    final info = await DeviceInfoPlugin().androidInfo;
    return info.version.sdkInt;
  }
}

