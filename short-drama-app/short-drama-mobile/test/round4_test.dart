import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';

import 'package:drama_now/l10n/app_localizations.dart';
import 'package:drama_now/models/drama/content_type.dart';
import 'package:drama_now/models/drama/short_item.dart';
import 'package:drama_now/presentation/drama/shorts_content.dart';
import 'package:drama_now/presentation/maintenance/maintenance_screen.dart';
import 'package:drama_now/presentation/onboarding/getting_started_screen.dart';
import 'package:drama_now/presentation/onboarding/privacy_consent_screen.dart';
import 'package:drama_now/services/consent_gate.dart';
import 'package:drama_now/services/onboarding_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ConsentGate (round 4, item 5: first-launch matrix)', () {
    test('first launch: no onboarding, no consent record, no session -> chain', () {
      expect(
        ConsentGate.shouldShowChain(
          onboardingCompleted: false,
          hasConsentRecord: false,
          hasSession: false,
        ),
        isTrue,
      );
    });

    test('returning user (onboarding completed) skips', () {
      expect(
        ConsentGate.shouldShowChain(
          onboardingCompleted: true,
          hasConsentRecord: false,
          hasSession: false,
        ),
        isFalse,
      );
    });

    test('a stored consent record skips even without onboarding flag', () {
      expect(
        ConsentGate.shouldShowChain(
          onboardingCompleted: false,
          hasConsentRecord: true,
          hasSession: false,
        ),
        isFalse,
      );
    });

    test('a stored session skips', () {
      expect(
        ConsentGate.shouldShowChain(
          onboardingCompleted: false,
          hasConsentRecord: false,
          hasSession: true,
        ),
        isFalse,
      );
    });
  });

  group('OnboardingService consent record (round 4, item 5)', () {
    test('lifecycle: none -> accept-all stamps version+timestamp+choices; '
        'granular save rewrites choices; reset clears', () async {
      SharedPreferences.setMockInitialValues({});
      final svc = OnboardingService.instance;
      await svc.reset(); // normalize regardless of test order

      expect(await svc.hasConsentRecord(), isFalse);
      expect(await svc.consentRecord(), isNull);

      await svc.acceptAllPrivacy();
      final all = await svc.consentRecord();
      expect(all, isNotNull);
      expect(all!.version, OnboardingService.currentConsentVersion);
      expect(all.analyticsEnabled, isTrue);
      expect(all.profilingEnabled, isTrue);
      expect(all.acceptedAt, isNotNull);
      expect(DateTime.tryParse(all.acceptedAt!), isNotNull,
          reason: 'timestamp is ISO-8601');
      // The sync payload matches the backend PATCH /auth/me consent shape.
      expect(all.toSyncJson()['version'], all.version);
      expect(all.toSyncJson()['analytics'], isTrue);
      expect(all.toSyncJson()['profiling'], isTrue);
      expect(all.toSyncJson()['updatedAt'], all.acceptedAt);

      await svc.savePrivacyPreferences(
        accepted: true,
        analyticsEnabled: true,
        profilingEnabled: false,
      );
      final granular = await svc.consentRecord();
      expect(granular!.analyticsEnabled, isTrue);
      expect(granular.profilingEnabled, isFalse);

      await svc.refuseNonEssentialPrivacy();
      final refused = await svc.consentRecord();
      expect(refused!.analyticsEnabled, isFalse);
      expect(refused.profilingEnabled, isFalse);

      await svc.reset();
      expect(await svc.hasConsentRecord(), isFalse);
    });
  });

  group('ShortItem mapping (round 4, item 3)', () {
    test('fromJson maps the full GET /shorts item shape', () {
      final item = ShortItem.fromJson(const {
        'id': 'series-x-ep3',
        'seriesId': 'series-x',
        'seriesTitle': 'Series X',
        'episodeNumber': 3,
        'title': 'The Reveal',
        'posterUrl': 'https://img/poster.jpg',
        'thumbnailUrl': 'https://img/thumb.jpg',
        'videoUrl': 'https://cdn/clip.mp4',
        'durationSeconds': 97,
        'likeCount': 42,
        'isFree': false,
        'isVipOnly': true,
        'isUnlocked': false,
      });
      expect(item.episodeId, 'series-x-ep3');
      expect(item.seriesId, 'series-x');
      expect(item.seriesTitle, 'Series X');
      expect(item.episodeNumber, 3);
      expect(item.captionTitle, 'The Reveal');
      expect(item.durationSeconds, 97);
      expect(item.likeCount, 42);
      expect(item.isFree, isFalse);
      expect(item.isVipOnly, isTrue);
      expect(item.isUnlocked, isFalse);
    });

    test('fromJson defaults: missing title falls back to Episode N, '
        'missing flags default to free/unlocked', () {
      final item = ShortItem.fromJson(const {
        'id': 'e1',
        'seriesId': 's1',
        'seriesTitle': 'S',
        'episodeNumber': 7,
      });
      expect(item.captionTitle, 'Episode 7');
      expect(item.isFree, isTrue);
      expect(item.isUnlocked, isTrue);
      expect(item.likeCount, 0);
      expect(item.posterUrl, isNull);
    });

    test('parseShortsPage: items + cursor; malformed rows skipped; '
        'empty cursor means exhausted', () {
      final page = parseShortsPage({
        'items': [
          {'id': 'e1', 'seriesId': 's1', 'seriesTitle': 'A', 'episodeNumber': 1},
          {'seriesId': 's1'}, // no id -> skipped
          'not-a-map',
          {'id': 'e2', 'seriesId': 's1', 'seriesTitle': 'A', 'episodeNumber': 2},
        ],
        'nextCursor': 'NQ',
      });
      expect(page.items.map((i) => i.episodeId), ['e1', 'e2']);
      expect(page.nextCursor, 'NQ');
      expect(page.hasMore, isTrue);

      final last = parseShortsPage({'items': const [], 'nextCursor': null});
      expect(last.items, isEmpty);
      expect(last.hasMore, isFalse);
    });
  });

  group('SectionType.forYou (round 4, item 4)', () {
    test("fromString('for_you') resolves to the new enum value", () {
      expect(SectionType.fromString('for_you'), SectionType.forYou);
      expect(SectionType.forYou.value, 'for_you');
      expect(SectionType.fromString('nonsense'), SectionType.unknown);
    });
  });

  group('MaintenanceScreen (round 4, item 2)', () {
    Widget harness({Future<bool> Function()? recheck, VoidCallback? cleared}) {
      return MaterialApp(
        home: MaintenanceScreen(
          recheckMaintenance: recheck,
          onCleared: cleared,
        ),
      );
    }

    testWidgets('renders branded screen with default message + Retry',
        (tester) async {
      await tester.pumpWidget(harness());
      expect(find.text("We'll be right back"), findsOneWidget);
      expect(find.text('HERO DRAMA'), findsOneWidget);
      expect(
        find.textContaining('temporarily down for maintenance'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('maintenance-retry')), findsOneWidget);
    });

    testWidgets('retry while still in maintenance stays and says so',
        (tester) async {
      var cleared = false;
      await tester.pumpWidget(harness(
        recheck: () async => true,
        cleared: () => cleared = true,
      ));
      await tester.tap(find.byKey(const ValueKey('maintenance-retry')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('Still under maintenance'), findsOneWidget);
      expect(cleared, isFalse);
      expect(find.byType(MaintenanceScreen), findsOneWidget);
    });

    testWidgets('retry after maintenance clears proceeds (onCleared fires)',
        (tester) async {
      var cleared = false;
      await tester.pumpWidget(harness(
        recheck: () async => false,
        cleared: () => cleared = true,
      ));
      await tester.tap(find.byKey(const ValueKey('maintenance-retry')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(cleared, isTrue);
    });
  });

  group('ShortFeedCard (round 4, item 3)', () {
    testWidgets('renders captions + like count and fires all callbacks',
        (tester) async {
      var likes = 0, mutes = 0, fulls = 0;
      const item = ShortItem(
        episodeId: 's1-ep3',
        seriesId: 's1',
        seriesTitle: 'Married to the CEO',
        episodeNumber: 3,
        title: 'The Reveal',
        likeCount: 42,
      );
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: ShortFeedCard(
            item: item,
            liked: false,
            likeCount: 42,
            muted: false,
            onLike: () => likes++,
            onToggleMute: () => mutes++,
            onWatchFull: () => fulls++,
          ),
        ),
      ));
      expect(find.text('Married to the CEO'), findsOneWidget);
      expect(find.text('The Reveal · Episode 3'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('short-like')));
      await tester.tap(find.byKey(const ValueKey('short-mute')));
      await tester.tap(find.byKey(const ValueKey('short-watch-full')));
      expect(likes, 1);
      expect(mutes, 1);
      expect(fulls, 1);
    });
  });

  group('Consent chain navigation (round 4, item 5)', () {
    Widget chainHarness() {
      return Sizer(
        builder: (context, orientation, screenType) => MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          routes: {
            '/login': (_) => const Scaffold(body: Text('LOGIN_MARKER')),
            '/main-tabs': (_) => const Scaffold(body: Text('TABS_MARKER')),
            '/legal/terms': (_) => const Scaffold(body: Text('TERMS_MARKER')),
            '/legal/privacy': (_) =>
                const Scaffold(body: Text('PRIVACY_MARKER')),
          },
          home: const GettingStartedScreen(),
        ),
      );
    }

    Future<void> pumpFrames(WidgetTester tester, [int n = 6]) async {
      for (var i = 0; i < n; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
    }

    testWidgets(
        'first launch lands on GettingStarted; its Terms span opens the '
        'legal screen; Get Started reaches PrivacyConsent; Accept All '
        'completes to login (no session)', (tester) async {
      // No runtime font fetching in tests: google_fonts' async load leaves
      // a system-fonts relayout callback pending at teardown, which the
      // test binding reports as an exception. Fallback fonts are fine.
      GoogleFonts.config.allowRuntimeFetching = false;
      // Tall phone surface: the onboarding screens are sizer-driven and
      // overflow shorter viewports (their flex columns are tuned for
      // tall phones; the default 800x600 test viewport overflows them).
      tester.view.physicalSize = const Size(430, 1100);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      await OnboardingService.instance.reset();
      await tester.pumpWidget(chainHarness());
      await pumpFrames(tester);

      // First launch lands on the chain head.
      expect(find.byType(GettingStartedScreen), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);

      // The Terms span carries a working recognizer -> legal screen.
      // (Search every RichText: plain Text widgets expose internal
      // RichTexts too, so `.first` is not necessarily the legal one.)
      TapGestureRecognizer? termsRecognizer;
      for (final rt in tester.widgetList<RichText>(find.byType(RichText))) {
        rt.text.visitChildren((span) {
          if (span is TextSpan && span.text == 'Terms of Service') {
            termsRecognizer = span.recognizer as TapGestureRecognizer?;
          }
          return true;
        });
        if (termsRecognizer != null) break;
      }
      expect(termsRecognizer, isNotNull,
          reason: 'Terms span must have a tap recognizer (was dead)');
      termsRecognizer!.onTap!();
      await pumpFrames(tester, 3);
      expect(find.text('TERMS_MARKER'), findsOneWidget);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await pumpFrames(tester, 3);

      // Get Started -> PrivacyConsent.
      await tester.tap(find.text('Get Started'));
      await pumpFrames(tester);
      expect(find.byType(PrivacyConsentScreen), findsOneWidget);

      // Accept All completes the chain; with no session in the test env
      // the session-aware exit lands on /login.
      await tester.tap(find.text('Accept All and Continue'));
      await pumpFrames(tester);
      expect(find.text('LOGIN_MARKER'), findsOneWidget);

      // And the decision was recorded (returning launches skip the chain).
      expect(await OnboardingService.instance.hasConsentRecord(), isTrue);

      // Settle real-async stragglers before teardown: google_fonts' load
      // attempts complete on the real event loop and notify system-fonts
      // listeners, which leaves a relayout transient callback pending;
      // runAsync lets them finish and the pumps consume the callback.
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
