import 'package:flutter/material.dart';

import '../../services/api/api_client.dart';
import '../../services/app_config_service.dart';

/// Round 4: branded maintenance screen.
///
/// Shown two ways, both loop-free:
///  - Splash routes here (replacement) when GET /config reports
///    maintenanceMode at launch.
///  - ApiClient's global 503 MAINTENANCE hook pushes it on top of whatever
///    the user was doing when maintenance starts mid-session.
///
/// Retry re-fetches /config (the one endpoint exempt from the maintenance
/// gate). When the flag has cleared, Retry exits the screen: pop when it
/// was pushed over a live stack, or restart the normal flow from splash
/// when it is the root. While the flag is still on, Retry stays put and
/// says so — it never navigates in a circle.
///
/// [recheckMaintenance] / [onCleared] are injectable for widget tests; in
/// production they default to the real config re-check and navigation.
class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key, this.recheckMaintenance, this.onCleared});

  /// Returns true when maintenance is STILL on after re-checking.
  final Future<bool> Function()? recheckMaintenance;

  /// Called instead of the default navigation once maintenance clears.
  final VoidCallback? onCleared;

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  bool _checking = false;
  bool _stillDown = false;

  Future<bool> _defaultRecheck() async {
    await AppConfigService.instance.load();
    return AppConfigService.instance.maintenanceMode;
  }

  Future<void> _onRetry() async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _stillDown = false;
    });
    var stillDown = true;
    try {
      stillDown = await (widget.recheckMaintenance ?? _defaultRecheck)();
    } catch (_) {
      stillDown = true; // a failed re-check means we cannot prove it cleared
    }
    if (!mounted) return;
    if (stillDown) {
      setState(() {
        _checking = false;
        _stillDown = true;
      });
      return;
    }
    // Maintenance cleared: release the ApiClient latch so a future
    // maintenance episode can route here again, then leave.
    ApiClient.instance.clearMaintenanceLatch();
    final onCleared = widget.onCleared;
    if (onCleared != null) {
      onCleared();
      return;
    }
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    } else {
      nav.pushReplacementNamed('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = AppConfigService.instance.maintenanceMessage;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFF4D6D).withValues(alpha: 0.14),
                ),
                child: const Icon(
                  Icons.build_circle_outlined,
                  size: 48,
                  color: Color(0xFFFF4D6D),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'HERO DRAMA',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3.2,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                "We'll be right back",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                (message != null && message.isNotEmpty)
                    ? message
                    : 'HERO DRAMA is temporarily down for maintenance. '
                        'Please try again soon!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFB0B0B0),
                  fontSize: 15,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 36),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  key: const ValueKey('maintenance-retry'),
                  onPressed: _checking ? null : _onRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF4D6D),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                  ),
                  child: _checking
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Retry',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              if (_stillDown) ...[
                const SizedBox(height: 16),
                const Text(
                  'Still under maintenance — please try again in a little while.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF909090), fontSize: 13),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
