import 'package:flutter/material.dart';

import '../../services/app_lock_service.dart';
import 'app_lock_screen.dart';

/// Round 5 (item 12): the app-lock gate.
///
/// Mounted in MaterialApp's builder, ABOVE the Navigator, so when
/// [AppLockService] is locked the gate covers every route (home,
/// player, sheets) without unmounting any of them — navigation state
/// underneath is fully preserved.
///
/// The gate stays inert until the home shell arms the service, which
/// keeps the splash → consent → login chain lock-free on first launch:
/// the lock sits after splash routing, before content.
class AppLockGate extends StatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate>
    with WidgetsBindingObserver {
  final AppLockService _service = AppLockService.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _service.addListener(_onLockChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _service.removeListener(_onLockChanged);
    super.dispose();
  }

  void _onLockChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _service.onBackground();
      case AppLifecycleState.resumed:
        // Fire-and-forget: the service notifies when it re-locks.
        _service.onResume();
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_service.isLocked)
          const Positioned.fill(child: AppLockScreen()),
      ],
    );
  }
}
