import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import 'package:drama_now/models/drama/short_item.dart';
import 'package:drama_now/models/user/order_history_item.dart';
import 'package:drama_now/presentation/drama/episode_player_screen.dart';
import 'package:drama_now/presentation/drama/shorts_content.dart';
import 'package:drama_now/presentation/purchase_history/purchase_history_screen.dart';
import 'package:drama_now/services/api/api_exception.dart';
import 'package:drama_now/services/drama/drama_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // No runtime font fetching in tests (see round4_test for why).
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('SIM-B F2: order periodEnd is used verbatim, never fabricated', () {
    final now = DateTime.utc(2026, 6, 1);

    Map<String, dynamic> vipOrder({
      required String createdAt,
      String? periodEnd,
      String productId = 'vip_yearly',
      String status = 'paid',
      int amountCents = 4999,
    }) =>
        {
          'id': 'ord-1',
          'userId': 'u1',
          'kind': 'vip',
          'productId': productId,
          'subscriptionPlanId': productId,
          'amountCents': amountCents,
          'currency': 'USD',
          'status': status,
          'createdAt': createdAt,
          if (periodEnd != null) 'periodEnd': periodEnd,
        };

    test(
        'annual order (periodEnd ~365d out) is active at day 200 — the '
        'old createdAt+30d fabrication showed it Expired', () {
      final item = parseOrderHistoryItem(
        vipOrder(
          createdAt: '2026-01-01T00:00:00.000Z',
          periodEnd: '2027-01-01T00:00:00.000Z',
        ),
        userId: 'u1',
        now: now,
      );
      expect(item.periodEnd, DateTime.utc(2027, 1, 1));
      expect(item.subscription.currentPeriodEnd, DateTime.utc(2027, 1, 1),
          reason: 'period end must be the API value, not createdAt+30d');
      expect(item.badgeState(at: DateTime.utc(2026, 7, 20)),
          OrderBadgeState.active);
      expect(item.isActiveAt(DateTime.utc(2026, 7, 20)), isTrue);
      expect(
          item.expiryText(at: DateTime.utc(2026, 7, 20)), 'Expires 1/1/2027');
    });

    test('weekly order expires at its real periodEnd (+7d), not +30d', () {
      final item = parseOrderHistoryItem(
        vipOrder(
          createdAt: '2026-01-01T00:00:00.000Z',
          periodEnd: '2026-01-08T00:00:00.000Z',
          productId: 'vip_weekly',
        ),
        userId: 'u1',
        now: now,
      );
      expect(item.badgeState(at: DateTime.utc(2026, 1, 5)),
          OrderBadgeState.active);
      expect(item.badgeState(at: DateTime.utc(2026, 1, 20)),
          OrderBadgeState.expired);
    });

    test('expired periodEnd renders expired', () {
      final item = parseOrderHistoryItem(
        vipOrder(
          createdAt: '2026-01-01T00:00:00.000Z',
          periodEnd: '2026-02-01T00:00:00.000Z',
        ),
        userId: 'u1',
        now: now,
      );
      expect(item.badgeState(at: now), OrderBadgeState.expired);
      expect(item.badgeLabel(at: now), 'Expired');
      expect(item.expiryText(at: now), 'Expired 1/2/2026');
    });

    test('missing periodEnd: no fabricated date is shown anywhere', () {
      final item = parseOrderHistoryItem(
        vipOrder(createdAt: '2026-01-01T00:00:00.000Z'),
        userId: 'u1',
        now: now,
      );
      expect(item.periodEnd, isNull);
      expect(item.expiryText(at: now), isNull,
          reason: 'honest display: no periodEnd -> no Expires line');
      expect(item.subscription.currentPeriodEnd, DateTime.utc(2026, 1, 1),
          reason: 'anchored at createdAt, NOT createdAt + 30 days');
      // The paid status is still reported; only the date is withheld.
      expect(item.badgeState(at: now), OrderBadgeState.active);
    });
  });

  group('SIM-B F3: history rows show price, product and kind', () {
    final now = DateTime.utc(2026, 6, 1);

    test('coin order: Coins badge, no expiry, product + price labels', () {
      final item = parseOrderHistoryItem(
        const {
          'id': 'ord-2',
          'userId': 'u1',
          'kind': 'coins',
          'productId': 'coins_500',
          'coinPackageId': 'coins_500',
          'amountCents': 499,
          'currency': 'USD',
          'status': 'paid',
          'createdAt': '2026-05-01T00:00:00.000Z',
        },
        userId: 'u1',
        now: now,
      );
      expect(item.isCoinOrder, isTrue);
      expect(item.badgeState(at: now), OrderBadgeState.coins);
      expect(item.badgeLabel(at: now), 'Coins');
      expect(item.expiryText(at: now), isNull,
          reason: 'coin orders never show an Expires line');
      expect(item.productLabel, '500 Coins');
      expect(item.priceLabel, '\$4.99');
    });

    test('cancelled VIP order still inside its period is NOT Expired', () {
      final item = parseOrderHistoryItem(
        const {
          'id': 'ord-3',
          'userId': 'u1',
          'kind': 'vip',
          'productId': 'vip_monthly',
          'subscriptionPlanId': 'vip_monthly',
          'amountCents': 999,
          'currency': 'USD',
          'status': 'cancelled',
          'createdAt': '2026-05-15T00:00:00.000Z',
          'periodEnd': '2026-12-01T00:00:00.000Z',
        },
        userId: 'u1',
        now: now,
      );
      expect(item.badgeState(at: now), OrderBadgeState.cancelledActiveUntil);
      expect(item.badgeLabel(at: now), 'Cancelled');
      expect(item.expiryText(at: now), 'Cancelled — active until 1/12/2026');
      expect(item.subscription.cancelAtPeriodEnd, isTrue);
      expect(item.productLabel, 'VIP Monthly');
    });

    test('cancelled VIP order past its periodEnd is Expired', () {
      final item = parseOrderHistoryItem(
        const {
          'id': 'ord-4',
          'userId': 'u1',
          'kind': 'vip',
          'productId': 'vip_monthly',
          'amountCents': 999,
          'currency': 'USD',
          'status': 'cancelled',
          'createdAt': '2026-01-15T00:00:00.000Z',
          'periodEnd': '2026-02-15T00:00:00.000Z',
        },
        userId: 'u1',
        now: now,
      );
      expect(item.badgeState(at: now), OrderBadgeState.expired);
    });

    test('price label: whole amounts, symbols, unknown currency fallback', () {
      OrderHistoryItem priced(int cents, String currency) =>
          parseOrderHistoryItem(
            {
              'id': 'o',
              'kind': 'vip',
              'productId': 'vip_monthly',
              'amountCents': cents,
              'currency': currency,
              'status': 'paid',
              'createdAt': '2026-01-01T00:00:00.000Z',
            },
            userId: 'u1',
            now: now,
          );
      expect(priced(500, 'USD').priceLabel, '\$5');
      expect(priced(499, 'EUR').priceLabel, '€4.99');
      expect(priced(150, 'XYZ').priceLabel, 'XYZ 1.50');
      expect(priced(0, 'USD').priceLabel, isNull);
    });
  });

  group('SIM-B F2/F3: PurchaseHistoryCard rendering', () {
    Widget harness(OrderHistoryItem item) => Sizer(
          builder: (context, orientation, screenType) => MaterialApp(
            home: Scaffold(body: PurchaseHistoryCard(item: item)),
          ),
        );

    String fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';

    // google_fonts' async load leaves a system-fonts relayout transient
    // callback pending at teardown (same settle round4_test uses).
    Future<void> settleFonts(WidgetTester tester) async {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('annual VIP order renders Active + real expiry + price',
        (tester) async {
      final nowUtc = DateTime.now().toUtc();
      final end = nowUtc.add(const Duration(days: 365));
      final item = parseOrderHistoryItem(
        {
          'id': 'ord-a',
          'kind': 'vip',
          'productId': 'vip_yearly',
          'subscriptionPlanId': 'vip_yearly',
          'amountCents': 4999,
          'currency': 'USD',
          'status': 'paid',
          'createdAt': nowUtc.toIso8601String(),
          'periodEnd': end.toIso8601String(),
        },
        userId: 'u1',
      );
      await tester.pumpWidget(harness(item));
      await tester.pump();
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Expired'), findsNothing);
      expect(find.text('Expires ${fmt(end)}'), findsOneWidget);
      expect(find.text('VIP Yearly'), findsOneWidget);
      expect(find.text('\$49.99'), findsOneWidget);
      await settleFonts(tester);
    });

    testWidgets('coin order renders Coins state, no Active/Expired/Expires',
        (tester) async {
      final item = parseOrderHistoryItem(
        const {
          'id': 'ord-c',
          'kind': 'coins',
          'productId': 'coins_500',
          'coinPackageId': 'coins_500',
          'amountCents': 499,
          'currency': 'USD',
          'status': 'paid',
          'createdAt': '2026-05-01T00:00:00.000Z',
        },
        userId: 'u1',
      );
      await tester.pumpWidget(harness(item));
      await tester.pump();
      expect(find.text('Coins'), findsOneWidget);
      expect(find.text('500 Coins'), findsOneWidget);
      expect(find.text('Active'), findsNothing);
      expect(find.text('Expired'), findsNothing);
      expect(find.textContaining('Expires'), findsNothing);
      await settleFonts(tester);
    });

    testWidgets(
        'cancelled-but-running VIP order renders '
        '"Cancelled — active until", not Expired', (tester) async {
      final nowUtc = DateTime.now().toUtc();
      final end = nowUtc.add(const Duration(days: 30));
      final item = parseOrderHistoryItem(
        {
          'id': 'ord-x',
          'kind': 'vip',
          'productId': 'vip_monthly',
          'subscriptionPlanId': 'vip_monthly',
          'amountCents': 999,
          'currency': 'USD',
          'status': 'cancelled',
          'createdAt': nowUtc.toIso8601String(),
          'periodEnd': end.toIso8601String(),
        },
        userId: 'u1',
      );
      await tester.pumpWidget(harness(item));
      await tester.pump();
      expect(find.text('Cancelled — active until ${fmt(end)}'), findsOneWidget);
      expect(find.text('Expired'), findsNothing);
      await settleFonts(tester);
    });
  });

  group('SIM-A F2: locked Shorts carry cost + player CTA', () {
    test('ShortItem.fromJson parses coinCost from the /shorts payload', () {
      final item = ShortItem.fromJson(const {
        'id': 'e3',
        'seriesId': 's1',
        'seriesTitle': 'Series X',
        'episodeNumber': 3,
        'coinCost': 30,
        'isUnlocked': false,
      });
      expect(item.coinCost, 30);
      expect(item.isUnlocked, isFalse);
    });

    testWidgets(
        'locked short renders EP label, unlock cost and the CTA '
        'routes out (tap fires)', (tester) async {
      var taps = 0;
      const item = ShortItem(
        episodeId: 's1-ep3',
        seriesId: 's1',
        seriesTitle: 'Married to the CEO',
        episodeNumber: 3,
        title: 'The Reveal',
        coinCost: 30,
        isFree: false,
        isUnlocked: false,
      );
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: LockedShortOverlay(item: item, onOpenFull: () => taps++),
        ),
      ));
      expect(find.text('Locked episode'), findsOneWidget);
      expect(find.text('EP 3 · Married to the CEO'), findsOneWidget);
      expect(find.text('Unlock for 30 coins'), findsOneWidget);
      expect(find.text('Watch full episode'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('short-locked-cta')));
      expect(taps, 1);
    });

    testWidgets('locked VIP short shows VIP label and no coin cost',
        (tester) async {
      const item = ShortItem(
        episodeId: 's1-ep5',
        seriesId: 's1',
        seriesTitle: 'Married to the CEO',
        episodeNumber: 5,
        title: 'The Gala',
        coinCost: 30,
        isFree: false,
        isVipOnly: true,
        isUnlocked: false,
      );
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: LockedShortOverlay(item: item, onOpenFull: _noop),
        ),
      ));
      expect(find.text('VIP episode'), findsOneWidget);
      expect(find.text('EP 5 · Married to the CEO'), findsOneWidget);
      expect(find.textContaining('Unlock for'), findsNothing);
    });
  });

  group('SIM-A F3: playback 401 maps to a sign-in prompt', () {
    test('playbackFailureForError distinguishes 401/UNAUTHORIZED', () {
      expect(
        playbackFailureForError(
            ApiException('UNAUTHORIZED', 'no session', statusCode: 401)),
        PlaybackFailure.unauthorized,
      );
      expect(
        playbackFailureForError(ApiException('UNAUTHORIZED', 'no session')),
        PlaybackFailure.unauthorized,
        reason: 'the code alone suffices (envelope errors carry no status)',
      );
      expect(
        playbackFailureForError(
            ApiException('HTTP_ERROR', 'teapot', statusCode: 401)),
        PlaybackFailure.unauthorized,
        reason: 'the status alone suffices',
      );
      expect(
        playbackFailureForError(
            ApiException('VIP_REQUIRED', 'vip only', statusCode: 403)),
        PlaybackFailure.other,
        reason: 'entitlement failures are not sign-in prompts',
      );
      expect(playbackFailureForError(Exception('boom')), PlaybackFailure.other);
    });

    Widget overlayHarness({
      required bool needsSignIn,
      required VoidCallback onRetry,
      required VoidCallback onSignIn,
    }) =>
        Sizer(
          builder: (context, orientation, screenType) => MaterialApp(
            home: Scaffold(
              backgroundColor: Colors.black,
              body: PlaybackErrorOverlay(
                needsSignIn: needsSignIn,
                onRetry: onRetry,
                onSignIn: onSignIn,
                onBack: _noop,
              ),
            ),
          ),
        );

    testWidgets('401 state: "Sign in to watch" + Sign in action, no Retry',
        (tester) async {
      var signIns = 0, retries = 0;
      await tester.pumpWidget(overlayHarness(
        needsSignIn: true,
        onRetry: () => retries++,
        onSignIn: () => signIns++,
      ));
      await tester.pump();
      expect(find.text('Sign in to watch'), findsOneWidget);
      expect(find.text("Couldn't load this episode"), findsNothing);
      await tester.tap(find.byKey(const ValueKey('player-signin-cta')));
      expect(signIns, 1);
      expect(retries, 0);
    });

    testWidgets('generic state unchanged: load failure + Retry',
        (tester) async {
      var signIns = 0, retries = 0;
      await tester.pumpWidget(overlayHarness(
        needsSignIn: false,
        onRetry: () => retries++,
        onSignIn: () => signIns++,
      ));
      await tester.pump();
      expect(find.text("Couldn't load this episode"), findsOneWidget);
      expect(find.text('Sign in to watch'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('player-retry')));
      expect(retries, 1);
      expect(signIns, 0);
    });
  });
}

void _noop() {}
