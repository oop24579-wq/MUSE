import 'package:flutter/material.dart';

/// Global navigator key (round 4) so non-widget services can route without
/// a BuildContext — currently ApiClient's maintenance hook, which must be
/// able to push the MaintenanceScreen from inside an HTTP error handler.
/// Wired into MaterialApp in main.dart; the hook itself is set in
/// bootstrap.dart.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
