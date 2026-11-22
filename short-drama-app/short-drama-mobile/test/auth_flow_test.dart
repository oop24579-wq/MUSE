import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drama_now/presentation/auth/login_screen.dart';

/// In-memory [AuthActions] fake — no Firebase, no network.
class FakeAuthActions implements AuthActions {
  bool guestCalled = false;
  bool googleCalled = false;
  bool appleCalled = false;
  String? lastResetEmail;
  Object? signInError;

  @override
  Future<void> signInEmail(String email, String password) async {
    final error = signInError;
    if (error != null) throw error;
  }

  @override
  Future<void> registerEmail({
    required String name,
    required String email,
    required String password,
  }) async {}

  @override
  Future<bool> signInGoogle() async {
    googleCalled = true;
    return true;
  }

  @override
  Future<bool> signInApple() async {
    appleCalled = true;
    return true;
  }

  @override
  Future<bool> signInGuest() async {
    guestCalled = true;
    return true;
  }

  @override
  Future<bool> sendPasswordReset(String email) async {
    lastResetEmail = email;
    return true;
  }
}

Widget _harness(FakeAuthActions fake) {
  return MaterialApp(
    theme: ThemeData.dark(useMaterial3: true),
    home: LoginScreen(actions: fake),
    routes: {
      '/home': (_) => const Scaffold(body: Text('HOME_MARKER')),
      '/legal/terms': (_) => const Scaffold(body: Text('TERMS_MARKER')),
      '/legal/privacy': (_) => const Scaffold(body: Text('PRIVACY_MARKER')),
    },
  );
}

void main() {
  testWidgets('(a) login renders all four entry methods + footer legal links',
      (tester) async {
    await tester.pumpWidget(_harness(FakeAuthActions()));
    await tester.pump();

    // Email entry
    expect(find.byKey(const Key('auth_email_field')), findsOneWidget);
    expect(find.byKey(const Key('auth_password_field')), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    // Social + guest entry
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with Apple'), findsOneWidget);
    expect(find.text('Continue as Guest'), findsOneWidget);
    expect(
      find.textContaining('Guest progress is saved on this device'),
      findsOneWidget,
    );
    // Footer legal links
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('Terms of Service'), findsOneWidget);
  });

  testWidgets('(b) register button disabled until terms checkbox tapped',
      (tester) async {
    await tester.pumpWidget(_harness(FakeAuthActions()));
    await tester.pump();

    // Switch to register mode.
    await tester.tap(find.textContaining('Create one'));
    await tester.pump();

    // Fill the fields so only the checkbox gates the button.
    await tester.enterText(
        find.byKey(const Key('auth_name_field')), 'Test User');
    await tester.enterText(
        find.byKey(const Key('auth_email_field')), 'test@example.com');
    await tester.enterText(
        find.byKey(const Key('auth_password_field')), 'secret123');
    await tester.pump();

    ElevatedButton registerButton() => tester.widget<ElevatedButton>(
          find.byKey(const Key('auth_register_button')),
        );
    expect(registerButton().onPressed, isNull,
        reason: 'Register must be disabled before terms are accepted');

    await tester.ensureVisible(find.byKey(const Key('auth_terms_checkbox')));
    await tester.tap(find.byKey(const Key('auth_terms_checkbox')));
    await tester.pump();

    expect(registerButton().onPressed, isNotNull,
        reason: 'Register must enable once terms are accepted');
  });

  testWidgets('(c) tapping Guest calls signInGuest and navigates home',
      (tester) async {
    final fake = FakeAuthActions();
    await tester.pumpWidget(_harness(fake));
    await tester.pump();

    await tester.ensureVisible(find.byKey(const Key('auth_guest_button')));
    await tester.tap(find.byKey(const Key('auth_guest_button')));
    await tester.pumpAndSettle();

    expect(fake.guestCalled, isTrue);
    expect(find.text('HOME_MARKER'), findsOneWidget);
  });

  testWidgets('(d) sign-in error from fake shows the error text',
      (tester) async {
    final fake = FakeAuthActions()
      ..signInError = AuthActionException('Incorrect email or password.');
    await tester.pumpWidget(_harness(fake));
    await tester.pump();

    await tester.enterText(
        find.byKey(const Key('auth_email_field')), 'test@example.com');
    await tester.enterText(
        find.byKey(const Key('auth_password_field')), 'wrongpass');
    await tester.pump();
    await tester.tap(find.byKey(const Key('auth_sign_in_button')));
    await tester.pumpAndSettle();

    expect(find.text('Incorrect email or password.'), findsOneWidget);
    expect(find.byKey(const Key('auth_error_banner')), findsOneWidget);
    // Still on the login screen — no navigation happened.
    expect(find.text('HOME_MARKER'), findsNothing);
  });
}
