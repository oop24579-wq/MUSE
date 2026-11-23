import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/app_navigator.dart';
import '../../services/app_lock_service.dart';
import '../../services/auth/auth_service.dart';
import '../../services/haptics_service.dart';

/// The full-screen lock gate UI (round 5, item 12): biometric unlock
/// when the device offers it, PIN pad always available as the
/// fallback.
///
/// Everything is rendered inline (no dialogs/snackbars): this screen
/// lives ABOVE the app's Navigator in the MaterialApp builder, so
/// routed overlays would appear underneath it and be invisible.
///
/// "Forgot PIN" = sign out + reset the lock (see AppLockService):
/// after re-login the user can set a fresh PIN in Settings.
class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  String _pin = '';
  String? _error;
  bool _biometricAvailable = false;
  bool _confirmingForgot = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      final available = await _localAuth.getAvailableBiometrics();
      if (mounted) {
        setState(() =>
            _biometricAvailable = supported && canCheck && available.isNotEmpty);
      }
    } catch (_) {
      // No biometrics → PIN pad only.
    }
  }

  Future<void> _tryBiometric() async {
    if (_busy) return;
    _busy = true;
    try {
      final ok = await _localAuth.authenticate(
        localizedReason: 'Unlock HERO DRAMA',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
      if (ok) {
        HapticsService.instance.success();
        AppLockService.instance.unlock();
        return;
      }
    } catch (_) {
      // Fall through to the PIN pad.
    } finally {
      _busy = false;
    }
  }

  void _onDigit(String digit) {
    if (_pin.length >= 6 || _busy) return;
    HapticsService.instance.selection();
    setState(() {
      _pin += digit;
      _error = null;
    });
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _onConfirm() async {
    if (_pin.length < 4 || _busy) return;
    _busy = true;
    final ok = await AppLockService.instance.verifyPin(_pin);
    _busy = false;
    if (!mounted) return;
    if (ok) {
      HapticsService.instance.success();
      AppLockService.instance.unlock();
    } else {
      HapticsService.instance.heavy();
      setState(() {
        _pin = '';
        _error = 'Incorrect PIN — try again';
      });
    }
  }

  Future<void> _onForgotConfirmed() async {
    if (_busy) return;
    _busy = true;
    // Reset first (wipes PIN + setting + drops the gate), then sign
    // out and route to /login.
    await AppLockService.instance.resetLock();
    try {
      await AuthService.instance.signOutToLogin();
    } catch (_) {}
    _busy = false;
    appNavigatorKey.currentState
        ?.pushNamedAndRemoveUntil('/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF0B0B10),
      child: SafeArea(
        child: _confirmingForgot ? _forgotView() : _pinView(),
      ),
    );
  }

  Widget _pinView() {
    return Column(
      children: [
        const Spacer(flex: 2),
        const Icon(Icons.lock_rounded, color: Colors.white, size: 44),
        const SizedBox(height: 14),
        const Text(
          'HERO DRAMA is locked',
          style: TextStyle(
              color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        const Text(
          'Enter your PIN to continue',
          style: TextStyle(color: Colors.white54, fontSize: 13),
        ),
        const SizedBox(height: 22),
        // PIN dots (buffer length only — never the digits).
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 6; i++)
              Container(
                width: 13,
                height: 13,
                margin: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < _pin.length
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.22),
                ),
              ),
          ],
        ),
        SizedBox(
          height: 20,
          child: _error == null
              ? null
              : Text(_error!,
                  style: const TextStyle(
                      color: Color(0xFFFF6B81), fontSize: 12.5)),
        ),
        const Spacer(),
        _pad(),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_biometricAvailable)
              TextButton.icon(
                onPressed: _tryBiometric,
                icon: const Icon(Icons.fingerprint_rounded,
                    color: Colors.white70, size: 20),
                label: const Text('Use biometrics',
                    style: TextStyle(color: Colors.white70)),
              ),
            TextButton(
              onPressed: () => setState(() => _confirmingForgot = true),
              child: const Text('Forgot PIN?',
                  style: TextStyle(color: Colors.white54)),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _pad() {
    Widget key(String label, VoidCallback? onTap,
        {Widget? child, Color? color}) {
      return SizedBox(
        width: 76,
        height: 62,
        child: TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            shape: const CircleBorder(),
            foregroundColor: color ?? Colors.white,
          ),
          child: child ??
              Text(label,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w500)),
        ),
      );
    }

    return Column(
      children: [
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final d in row) key(d, () => _onDigit(d)),
            ],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            key('', _pin.isEmpty ? null : _onBackspace,
                child: const Icon(Icons.backspace_outlined,
                    color: Colors.white, size: 22)),
            key('0', () => _onDigit('0')),
            key('', _pin.length >= 4 ? _onConfirm : null,
                child: Icon(Icons.check_rounded,
                    color: _pin.length >= 4
                        ? const Color(0xFF4ADE80)
                        : Colors.white24,
                    size: 26)),
          ],
        ),
      ],
    );
  }

  Widget _forgotView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_reset_rounded,
              color: Colors.white, size: 44),
          const SizedBox(height: 16),
          const Text(
            'Reset app lock?',
            style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          const Text(
            'This signs you out and removes the app lock. After signing '
            'back in you can set a new PIN in Settings.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _busy ? null : _onForgotConfirmed,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
            ),
            child: const Text('Sign out & reset lock'),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => setState(() => _confirmingForgot = false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }
}
