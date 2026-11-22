import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/force_update_status.dart';
import 'firebase/remote_config_service.dart';

/// Checks minimum / latest build numbers from Firebase Remote Config.
class ForceUpdateService {
  static final ForceUpdateService _instance = ForceUpdateService._internal();
  static ForceUpdateService get instance => _instance;
  ForceUpdateService._internal();

  final _remoteConfig = RemoteConfigService.instance;
  PackageInfo? _packageInfo;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _packageInfo = await PackageInfo.fromPlatform();
      _initialized = true;
      debugPrint(
        '📱 App Version: ${_packageInfo?.version} (Build ${_packageInfo?.buildNumber})',
      );
    } catch (e) {
      debugPrint('❌ Error loading package info: $e');
    }
  }

  int get currentBuildNumber {
    final buildNumber = _packageInfo?.buildNumber ?? '1';
    return int.tryParse(buildNumber) ?? 1;
  }

  String get currentVersion => _packageInfo?.version ?? '1.0.0';

  Future<ForceUpdateStatus> checkForUpdate() async {
    if (!_initialized || _packageInfo == null) {
      await initialize();
    }

    final current = currentBuildNumber;
    final bool isEnabled;
    final int minBuild;
    final int latestBuild;
    final String storeUrl;

    if (Platform.isIOS) {
      isEnabled = _remoteConfig.iosForceUpdateEnabled;
      minBuild = _remoteConfig.iosMinBuildNumber;
      latestBuild = _remoteConfig.iosLatestBuildNumber;
      storeUrl = _remoteConfig.iosStoreUrl;
    } else if (Platform.isAndroid) {
      isEnabled = _remoteConfig.androidForceUpdateEnabled;
      minBuild = _remoteConfig.androidMinBuildNumber;
      latestBuild = _remoteConfig.androidLatestBuildNumber;
      storeUrl = _remoteConfig.androidStoreUrl;
    } else {
      return ForceUpdateStatus.noUpdateNeeded();
    }

    UpdateType updateType;
    if (!isEnabled) {
      updateType = UpdateType.none;
    } else if (current < minBuild) {
      updateType = UpdateType.force;
    } else if (current < latestBuild) {
      updateType = UpdateType.optional;
    } else {
      updateType = UpdateType.none;
    }

    return ForceUpdateStatus(
      updateType: updateType,
      currentBuildNumber: current,
      minBuildNumber: minBuild,
      latestBuildNumber: latestBuild,
      storeUrl: storeUrl,
    );
  }

  Future<bool> openStore(String storeUrl) async {
    try {
      final uri = Uri.parse(storeUrl);
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('❌ Error opening store: $e');
      return false;
    }
  }
}
