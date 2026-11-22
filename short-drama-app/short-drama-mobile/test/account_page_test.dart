import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drama_now/models/user/coin_transaction.dart';
import 'package:drama_now/models/user/user_model.dart';
import 'package:drama_now/presentation/account/account_helpers.dart';
import 'package:drama_now/presentation/account/coin_history_screen.dart';
import 'package:drama_now/presentation/account/delete_account_dialog.dart';
import 'package:drama_now/presentation/account/edit_profile_screen.dart';
import 'package:drama_now/services/account_service.dart';

class FakeAccountService extends AccountServiceBase {
  String? lastName;
  String? lastImage;
  List<CoinTransaction> txItems = const [];
  int txTotal = 0;
  Object? txError;

  @override
  Future<UserModel> updateProfile({
    String? name,
    String? image,
    bool? autoplayNext,
    String? videoQuality,
    String? locale,
    bool? notificationsEnabled,
  }) async {
    lastName = name;
    lastImage = image;
    return _user(name: name ?? 'Tester', image: image);
  }

  @override
  Future<({List<CoinTransaction> items, int total})> fetchTransactions({
    int limit = 50,
    int offset = 0,
  }) async {
    if (txError != null) throw txError!;
    final slice = txItems.skip(offset).take(limit).toList();
    return (items: slice, total: txTotal == 0 ? txItems.length : txTotal);
  }
}

UserModel _user({String name = 'Tester', String? image}) => UserModel(
      id: 'u1',
      uid: 'f1',
      email: 'tester@example.com',
      displayName: name,
      photoUrl: image,
      isAnonymous: false,
      isPro: false,
      coinBalance: 120,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  group('CoinTransaction', () {
    test('parses API json and humanizes the type', () {
      final tx = CoinTransaction.fromJson({
        'id': 't1',
        'amount': 25,
        'type': 'watch_reward',
        'refId': 'ep9',
        'balanceAfter': 145,
        'createdAt': '2026-11-22T10:00:00.000Z',
      });
      expect(tx.amount, 25);
      expect(tx.balanceAfter, 145);
      expect(tx.typeLabel, 'Watch reward');
      expect(tx.isCredit, isTrue);
    });
  });

  group('providerLabel (no Firebase in tests)', () {
    test('guest user → Guest', () {
      final guest = _user().copyWith(isAnonymous: true, email: null);
      expect(providerLabel(guest), 'Guest');
    });
    test('email user falls back to Email', () {
      expect(providerLabel(_user()), 'Email');
    });
  });

  group('EditProfileScreen', () {
    testWidgets('saving persists name + selected avatar via the service',
        (tester) async {
      final fake = FakeAccountService();
      await tester.pumpWidget(_wrap(EditProfileScreen(
        user: _user(),
        service: fake,
        provider: 'Email',
      )));
      await tester.pump();

      await tester.enterText(
          find.byKey(const ValueKey('edit_name_field')), 'New Name');
      await tester.tap(find.byKey(const ValueKey('avatar_option_2')));
      await tester.pump();
      // The save button sits at the bottom of the screen's lazy ListView;
      // scroll that specific scrollable (the avatar grid is a second one).
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('edit_save_button')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('edit_save_button')));
      await tester.pump();
      await tester.pump();

      expect(fake.lastName, 'New Name');
      expect(fake.lastImage, kAvatarAssets[2]);

      // Drain any late platform-channel messages (system-fonts relayout
      // callbacks) so no transient frame callback outlives the test.
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
    });
  });

  group('CoinHistoryScreen', () {
    testWidgets('renders transactions with signed amounts', (tester) async {
      final fake = FakeAccountService()
        ..txItems = [
          CoinTransaction(
            id: 'a',
            amount: 50,
            type: 'daily_chest',
            balanceAfter: 170,
            createdAt: DateTime.utc(2026, 11, 22),
          ),
          CoinTransaction(
            id: 'b',
            amount: -30,
            type: 'episode_unlock',
            balanceAfter: 120,
            createdAt: DateTime.utc(2026, 11, 21),
          ),
        ];
      await tester.pumpWidget(
          _wrap(CoinHistoryScreen(balance: 120, service: fake)));
      await tester.pump();
      await tester.pump();

      expect(find.text('Daily chest'), findsOneWidget);
      expect(find.text('Episode unlock'), findsOneWidget);
      expect(find.text('+50'), findsOneWidget);
      expect(find.text('-30'), findsOneWidget);
      expect(find.text('120'), findsWidgets);
    });

    testWidgets('empty state when there are no transactions', (tester) async {
      final fake = FakeAccountService();
      await tester.pumpWidget(
          _wrap(CoinHistoryScreen(balance: 0, service: fake)));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('No transactions yet'), findsOneWidget);
    });

    testWidgets('error state offers retry', (tester) async {
      final fake = FakeAccountService()..txError = Exception('boom');
      await tester.pumpWidget(
          _wrap(CoinHistoryScreen(balance: 0, service: fake)));
      await tester.pump();
      await tester.pump();
      expect(find.text('Retry'), findsOneWidget);
    });
  });

  group('DeleteAccountDialog', () {
    testWidgets('confirm stays disabled until DELETE is typed, then fires',
        (tester) async {
      String? receivedPassword = 'unset';
      var calls = 0;
      await tester.pumpWidget(_wrap(Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => DeleteAccountDialog.show(
              context,
              showPasswordField: true,
              onConfirm: (password) async {
                calls++;
                receivedPassword = password;
              },
            ),
            child: const Text('open'),
          ),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final confirmBtn = find.byKey(const ValueKey('delete_confirm_button'));
      expect(confirmBtn, findsOneWidget);
      expect(tester.widget<ElevatedButton>(confirmBtn).onPressed, isNull);

      await tester.enterText(
          find.byKey(const ValueKey('delete_confirm_field')), 'DEL');
      await tester.pump();
      expect(tester.widget<ElevatedButton>(confirmBtn).onPressed, isNull);

      await tester.enterText(
          find.byKey(const ValueKey('delete_confirm_field')), 'DELETE');
      await tester.enterText(
          find.byKey(const ValueKey('delete_password_field')), 'secret1');
      await tester.pump();
      expect(tester.widget<ElevatedButton>(confirmBtn).onPressed, isNotNull);

      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(receivedPassword, 'secret1');
    });
  });
}
