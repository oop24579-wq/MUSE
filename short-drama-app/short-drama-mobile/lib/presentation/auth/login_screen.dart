import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/app_export.dart';
import '../../services/auth/auth_service.dart';

/// Plain-language auth failure surfaced to the login UI.
class AuthActionException implements Exception {
  AuthActionException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Testability seam for [LoginScreen]: every auth side-effect goes
/// through this interface, so widget tests can inject a fake and never
/// touch Firebase.
abstract class AuthActions {
  Future<void> signInEmail(String email, String password);
  Future<void> registerEmail({
    required String name,
    required String email,
    required String password,
  });
  Future<bool> signInGoogle();
  Future<bool> signInApple();
  Future<bool> signInGuest();
  Future<bool> sendPasswordReset(String email);
}

/// Production [AuthActions] delegating to [AuthService].
///
/// IMPORTANT: this class must stay free of Firebase access at
/// construction time — [AuthService.instance] is only touched inside
/// the methods, so merely building a [LoginScreen] (e.g. in a widget
/// test with default actions never invoked) never initializes Firebase.
class FirebaseAuthActions implements AuthActions {
  const FirebaseAuthActions();

  @override
  Future<void> signInEmail(String email, String password) async {
    try {
      final cred = await AuthService.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (cred == null) {
        throw AuthActionException('Sign-in failed. Please try again.');
      }
    } on AuthActionException {
      rethrow;
    } catch (e) {
      throw AuthActionException(
        AuthService.instance.getAuthErrorMessage(e),
      );
    }
  }

  @override
  Future<void> registerEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final cred = await AuthService.instance.signUpWithEmailAndPassword(
        email: email,
        password: password,
        displayName: name,
      );
      if (cred == null) {
        throw AuthActionException(
          'Could not create your account. Please try again.',
        );
      }
    } on AuthActionException {
      rethrow;
    } catch (e) {
      throw AuthActionException(
        AuthService.instance.getAuthErrorMessage(e),
      );
    }
  }

  @override
  Future<bool> signInGoogle() => AuthService.instance.signInWithGoogle();

  @override
  Future<bool> signInApple() => AuthService.instance.signInWithApple();

  @override
  Future<bool> signInGuest() => AuthService.instance.signInAsGuest();

  @override
  Future<bool> sendPasswordReset(String email) =>
      AuthService.instance.sendPasswordResetEmail(email);
}

enum _AuthMode { signIn, register }

/// Login / register gate shown to returning users with no restorable
/// session (see SplashScreen) and after an explicit sign-out.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.actions});

  /// Injectable for tests; defaults to [FirebaseAuthActions].
  final AuthActions? actions;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Lazily resolved so an injected fake is used as-is and the default
  // is only built when the screen is.
  late final AuthActions _actions =
      widget.actions ?? const FirebaseAuthActions();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  _AuthMode _mode = _AuthMode.signIn;
  bool _busy = false;
  bool _obscurePassword = true;
  bool _termsAccepted = false;
  String? _error;

  late final TapGestureRecognizer _termsRecognizer = TapGestureRecognizer()
    ..onTap = () => Navigator.pushNamed(context, '/legal/terms');
  late final TapGestureRecognizer _privacyRecognizer = TapGestureRecognizer()
    ..onTap = () => Navigator.pushNamed(context, '/legal/privacy');

  bool get _isRegister => _mode == _AuthMode.register;

  bool get _registerReady =>
      _termsAccepted &&
      _nameController.text.trim().isNotEmpty &&
      _emailController.text.trim().isNotEmpty &&
      _passwordController.text.isNotEmpty;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  void _switchMode(_AuthMode mode) {
    if (_busy || mode == _mode) return;
    setState(() {
      _mode = mode;
      _error = null;
    });
  }

  void _goHome() {
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/home');
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.error : null,
      ),
    );
  }

  Future<void> _runGuarded(
    Future<void> Function() body, {
    required void Function(Object error) onError,
  }) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await body();
    } catch (e) {
      onError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _messageFor(Object e) =>
      e is AuthActionException ? e.message : e.toString();

  Future<void> _submitEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Enter your email and password.');
      return;
    }
    await _runGuarded(
      () async {
        if (_isRegister) {
          await _actions.registerEmail(
            name: _nameController.text.trim(),
            email: email,
            password: password,
          );
        } else {
          await _actions.signInEmail(email, password);
        }
        _goHome();
      },
      onError: (e) {
        if (mounted) setState(() => _error = _messageFor(e));
      },
    );
  }

  Future<void> _social(Future<bool> Function() signIn) async {
    await _runGuarded(
      () async {
        final ok = await signIn();
        if (ok) {
          _goHome();
        }
        // ok == false with no exception = user cancelled the provider
        // flow: just stop loading, no error banner.
      },
      onError: (e) {
        if (mounted) setState(() => _error = _messageFor(e));
      },
    );
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showSnack('Enter your email first, then tap Forgot password.',
          isError: true);
      return;
    }
    await _runGuarded(
      () async {
        final sent = await _actions.sendPasswordReset(email);
        if (sent) {
          _showSnack('Password reset email sent — check your inbox.');
        } else {
          _showSnack('Could not send the reset email. Check the address '
              'and try again.', isError: true);
        }
      },
      onError: (e) => _showSnack(_messageFor(e), isError: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Center(
                child: Image.asset(
                  'assets/images/app_icon.png',
                  width: 88,
                  height: 88,
                  fit: BoxFit.contain,
                  // Missing asset (e.g. widget tests) must not break
                  // the screen.
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.play_circle_fill,
                    size: 88,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'HERO DRAMA',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isRegister ? 'Create your account' : 'Welcome back',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 32),
              if (_error != null) ...[
                Container(
                  key: const Key('auth_error_banner'),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.error.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    _error!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (_isRegister) ...[
                TextField(
                  key: const Key('auth_name_field'),
                  controller: _nameController,
                  enabled: !_busy,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'Your name',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                key: const Key('auth_email_field'),
                controller: _emailController,
                enabled: !_busy,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'you@example.com',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('auth_password_field'),
                controller: _passwordController,
                enabled: !_busy,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) {
                  if (!_busy && (!_isRegister || _registerReady)) {
                    _submitEmail();
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () => setState(
                      () => _obscurePassword = !_obscurePassword,
                    ),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (!_isRegister)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _busy ? null : _forgotPassword,
                    child: const Text('Forgot password?'),
                  ),
                ),
              if (_isRegister) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      key: const Key('auth_terms_checkbox'),
                      value: _termsAccepted,
                      onChanged: _busy
                          ? null
                          : (v) =>
                              setState(() => _termsAccepted = v ?? false),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: RichText(
                          text: TextSpan(
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                            children: [
                              const TextSpan(text: 'I agree to the '),
                              TextSpan(
                                text: 'Terms of Service',
                                style: TextStyle(
                                  color: AppTheme.primary,
                                  decoration: TextDecoration.underline,
                                ),
                                recognizer: _termsRecognizer,
                              ),
                              const TextSpan(text: ' and '),
                              TextSpan(
                                text: 'Privacy Policy',
                                style: TextStyle(
                                  color: AppTheme.primary,
                                  decoration: TextDecoration.underline,
                                ),
                                recognizer: _privacyRecognizer,
                              ),
                              const TextSpan(
                                text:
                                    ' and confirm I am 13 or older.',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                key: Key(
                  _isRegister ? 'auth_register_button' : 'auth_sign_in_button',
                ),
                onPressed: _busy || (_isRegister && !_registerReady)
                    ? null
                    : _submitEmail,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isRegister ? 'Register' : 'Sign In'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => _switchMode(
                          _isRegister ? _AuthMode.signIn : _AuthMode.register,
                        ),
                child: Text(
                  _isRegister
                      ? 'Already have an account? Sign in'
                      : "Don't have an account? Create one",
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'or',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                key: const Key('auth_google_button'),
                onPressed: _busy ? null : () => _social(_actions.signInGoogle),
                child: const Text('Continue with Google'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                key: const Key('auth_apple_button'),
                onPressed: _busy ? null : () => _social(_actions.signInApple),
                child: const Text('Continue with Apple'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                key: const Key('auth_guest_button'),
                onPressed: _busy ? null : () => _social(_actions.signInGuest),
                child: const Text('Continue as Guest'),
              ),
              const SizedBox(height: 8),
              Text(
                'Guest progress is saved on this device — link an account '
                'later to keep it.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/legal/privacy'),
                    child: const Text('Privacy Policy'),
                  ),
                  Text(
                    '·',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  TextButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/legal/terms'),
                    child: const Text('Terms of Service'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
