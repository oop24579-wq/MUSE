/// Represents the update status for the app.
enum UpdateType {
  none,
  optional,
  force,
}

/// Result of a force-update check. Copy comes from [AppLocalizations].
class ForceUpdateStatus {
  final UpdateType updateType;
  final int currentBuildNumber;
  final int minBuildNumber;
  final int latestBuildNumber;
  final String storeUrl;

  const ForceUpdateStatus({
    required this.updateType,
    required this.currentBuildNumber,
    required this.minBuildNumber,
    required this.latestBuildNumber,
    required this.storeUrl,
  });

  bool get needsUpdate => updateType != UpdateType.none;

  bool get isMandatory => updateType == UpdateType.force;

  factory ForceUpdateStatus.noUpdateNeeded() {
    return const ForceUpdateStatus(
      updateType: UpdateType.none,
      currentBuildNumber: 0,
      minBuildNumber: 0,
      latestBuildNumber: 0,
      storeUrl: '',
    );
  }

  @override
  String toString() {
    return 'ForceUpdateStatus(type: $updateType, current: $currentBuildNumber, min: $minBuildNumber, latest: $latestBuildNumber)';
  }
}
