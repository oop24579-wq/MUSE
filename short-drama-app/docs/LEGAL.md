# HERO DRAMA — Legal Index & Store Submission Guide

Last updated: November 22, 2026

This file is the owner's index for all HERO DRAMA legal material: where each
document lives, the exact store-console steps to complete before submission,
and the data-disclosure mapping tables for Google Play Data Safety and the
Apple App Privacy "nutrition label".

> **Placeholders to replace before submission**
> - Contact email: `support@herodrama.app` is a **placeholder**. Replace it
>   with a monitored support address in `PRIVACY_POLICY.md`,
>   `TERMS_OF_SERVICE.md`, and
>   `short-drama-mobile/lib/presentation/legal/legal_texts.dart`.
> - Governing law: `[Your Jurisdiction]` in the Terms of Service must be
>   completed with the operator's jurisdiction.

---

## 1. Document index

| Document | In-app source | Standalone file (host for store URL) |
|---|---|---|
| Privacy Policy | `lib/presentation/legal/legal_texts.dart` → `privacyPolicy` | `docs/PRIVACY_POLICY.md` |
| Terms of Service | `lib/presentation/legal/legal_texts.dart` → `termsOfService` | `docs/TERMS_OF_SERVICE.md` |
| Subscription & Purchases terms | `lib/presentation/legal/legal_texts.dart` → `subscriptionTerms` | Included at the end of `docs/TERMS_OF_SERVICE.md` |
| Legal screens (hub, privacy, terms, subscription, licenses/about) | `lib/presentation/legal/legal_screens.dart` | — |

In-app routes (defined in `LegalRoutes`, to be wired into the app router by
the app owner — the legal screens themselves register nothing):

- Hub: `/legal`
- Privacy Policy: `/legal/privacy`
- Terms of Service: `/legal/terms`
- Subscription & Purchases: `/legal/subscription`
- Licenses & About: `/legal/licenses`

The Licenses screen uses Flutter's built-in `showLicensePage`, so open-source
attributions stay automatically in sync with the packages actually bundled.

---

## 2. Store-console steps for the owner

### Step A — Publish the Privacy Policy URL (required by both stores)

1. Host `docs/PRIVACY_POLICY.md` at a public, no-login URL (for example the
   project's GitHub Pages site, a `privacy.html` page on the project website,
   or any static host). The URL must load without authentication and must show
   the final text with the real support email.
2. **Google Play Console:** go to **Play Console → your app → Policy and
   programs → App content → Privacy policy** and paste the privacy-policy URL
   in the Privacy policy field, then Save.
3. **App Store Connect:** go to **App Store Connect → your app → App
   Information** and paste the same URL in the **Privacy Policy URL** field
   (and the Terms/EULA URL if you also host `TERMS_OF_SERVICE.md`). Then
   complete **App Privacy** (Step C below).

### Step B — Google Play: fill the Data Safety form

Play Console → **Policy and programs → App content → Data safety**. Declare
that the app collects and shares data, then use the mapping table in
Section 3 below — it is written in Play's own data-type vocabulary. Also
confirm on the form:

- Data is encrypted in transit: **Yes** (HTTPS/TLS everywhere).
- Users can request data deletion: **Yes** (in-app Account → Delete Account,
  plus the deletion web link in Step D).
- Data collection is required (not optional) for account/progress/coin data;
  push notifications and ad personalisation follow the user's choices.

### Step C — Apple: complete App Privacy ("nutrition label")

App Store Connect → **your app → App Privacy → Get Started / Edit**. Use the
mapping table in Section 4 below. Declare data collection by HERO DRAMA **and**
by the third-party SDKs (Firebase/Google, RevenueCat, AdMob, OneSignal).
For each data type, select the purposes listed and whether it is linked to the
user's identity and/or used for tracking. Note: AdMob advertising identifiers
may count as **tracking** under Apple's definition if used for cross-app
advertising — if personalised ads are enabled, answer "Yes" to tracking for
Identifiers (Device ID) and Usage Data (Advertising Data) and ensure the iOS
App Tracking Transparency prompt is shown; if only non-personalised ads are
served, answer accordingly.

### Step D — Account-deletion URL (Google Play requirement)

Google Play requires a **web link for account deletion** in addition to the
in-app flow (Play Console → App content → **Account deletion** section).

- **In-app flow (already covers deletion):** Account → Delete Account wipes
  the account, profile, watch history/progress, and coin balance/ledger.
- **What to paste as the deletion URL:** host a short public page (it can be a
  section of the privacy-policy page) that states, verbatim in substance:

  > "To delete your HERO DRAMA account and all associated data, open the app
  > and go to Account → Delete Account. If you cannot access the app, email
  > support@herodrama.app from the email address associated with your account
  > with the subject 'Delete my account' and we will delete your account and
  > associated data within 30 days. Deleting your account does not cancel an
  > active VIP subscription; cancel separately in your App Store or Google
  > Play subscription settings."

  Paste that page's URL into Play Console's account-deletion field.
- Apple likewise requires in-app account deletion for apps that support
  account creation — the in-app flow satisfies this; no separate URL is
  required by Apple.

---

## 3. Google Play Data Safety mapping

"Collected" = transmitted off the device to HERO DRAMA / its processors.
"Shared" = transferred to a third party in Play's sense. Service-provider
processing (Firebase, RevenueCat, OneSignal acting on our behalf) is listed
with the third party named, per the Privacy Policy; whether Play counts a
given processor transfer as "sharing" depends on the processor's role —
Firebase Analytics / AdMob advertising use is declared as sharing where
noted.

| Data type (Play category) | Collected | Shared | Purpose (Play purposes) | Third party |
|---|---|---|---|---|
| Email address (Personal info) | Yes | No — processor only | Account management; App functionality | Firebase Authentication (Google); Apple (Sign in with Apple, incl. private relay) |
| Name (Personal info) | Yes | No — processor only | Account management; App functionality | Firebase (Google); sign-in provider (Google/Apple) |
| User IDs — account/Firebase UID, provider ID (Personal info) | Yes | No — processor only | Account management; App functionality; Fraud prevention, security and compliance | Firebase (Google); RevenueCat (pseudonymous app user ID) |
| Purchase history — subscription status, product, renewal/expiry (Financial info → Purchase history) | Yes | No — processor only | Account management; App functionality; Fraud prevention | RevenueCat; Apple App Store / Google Play (processor of the payment) |
| Payment-card details | **No** | No | — (never received; stores process payment) | Apple / Google only, outside the app |
| Watch history & episode progress (App activity) | Yes | No | App functionality; Analytics; Personalisation (recommendations/continue watching) | HERO DRAMA backend; Firebase (Google) |
| In-app search history (App activity) | Yes | No | App functionality; Analytics | Firebase Analytics (Google) |
| Other app activity — screens, features, sessions (App activity) | Yes | Yes (analytics) | Analytics; App functionality | Firebase Analytics / Google Analytics (Google) |
| Coin balance & transaction ledger (App activity / in-app financial record) | Yes | No | App functionality; Fraud prevention, security and compliance | HERO DRAMA backend |
| Device or other IDs — device/installation ID, push token (Device or other IDs) | Yes | Yes (push/ads) | App functionality; Advertising or marketing (push); Analytics | OneSignal (push token); Firebase (Google); AdMob (Google) |
| Advertising ID (Device or other IDs) | Yes | Yes | Advertising or marketing; Analytics; Fraud prevention | Google AdMob (Google) |
| App info & performance — crash logs (App info and performance) | Yes | No — processor only | Analytics; App functionality (stability) | Firebase Crashlytics (Google) |
| App info & performance — diagnostics/performance data | Yes | No — processor only | Analytics | Firebase (Google) |
| Approximate location (derived from IP / storefront country) | Yes (by processors) | Yes (ads) | Advertising or marketing; Analytics; Fraud prevention | Google AdMob; RevenueCat (storefront country) |
| Precise location | **No** | No | — | — |
| Contacts, photos, audio, health, messages | **No** | No | — | — |

Data practices for the form: encrypted in transit — Yes; deletion request
supported — Yes (in-app + web link, Step D); independent security review —
No (unless separately commissioned).

---

## 4. Apple App Privacy ("nutrition label") mapping

Declare each type below for HERO DRAMA and its third-party partners.
"Linked to identity" = linked to the user's account/identity. "Tracking" per
Apple's definition (linking data with third-party data for targeted
advertising or sharing with data brokers).

| Apple data type | Collected | Linked to identity | Used for tracking | Purposes | Source / partner |
|---|---|---|---|---|---|
| Contact Info — Email Address | Yes | Yes | No | App Functionality; Account management | Firebase Auth; Google/Apple sign-in |
| Contact Info — Name | Yes | Yes | No | App Functionality | Profile / sign-in provider |
| Identifiers — User ID (Firebase UID, provider ID, RevenueCat app user ID) | Yes | Yes | No | App Functionality; Analytics; Fraud prevention | Firebase; RevenueCat |
| Identifiers — Device ID (installation/advertising identifier) | Yes | Yes (pseudonymous) | **Yes if personalised AdMob ads are on; otherwise No** | Third-Party Advertising; Analytics; App Functionality | AdMob; Firebase; OneSignal |
| Purchases — Purchase History (subscription status/products) | Yes | Yes | No | App Functionality; Analytics | RevenueCat; Apple/Google stores |
| Usage Data — Product Interaction (watch history, progress, screens, coin activity) | Yes | Yes | No | App Functionality; Analytics; Product Personalisation | Backend; Firebase Analytics |
| Usage Data — Advertising Data | Yes | Yes (pseudonymous) | **Yes if personalised ads are on; otherwise No** | Third-Party Advertising; Analytics | Google AdMob |
| Usage Data — Other Usage Data (push delivery/open events) | Yes | Yes (pseudonymous) | No | App Functionality; Analytics | OneSignal |
| Diagnostics — Crash Data | Yes | No (pseudonymous) | No | App Functionality; Analytics | Firebase Crashlytics |
| Diagnostics — Performance Data | Yes | No (pseudonymous) | No | Analytics; App Functionality | Firebase |
| Location — Coarse Location (IP/storefront-derived, via ads/analytics SDKs) | Yes (via SDKs) | No | Per AdMob configuration | Third-Party Advertising; Analytics; Fraud prevention | AdMob; RevenueCat |
| Location — Precise Location | **No** | — | — | — | — |
| Sensitive Info, Health, Contacts, Photos, Audio, Messages, Browsing History | **No** | — | — | — | — |

If personalised advertising is disabled (non-personalised ads only), set
"Used for tracking" to No throughout and no ATT prompt is required for ads;
keep the declarations for collection and purposes unchanged.

---

## 5. Consistency rule

The in-app texts (`legal_texts.dart`) are the source of truth. When a policy
changes, update `legal_texts.dart` first, regenerate/update
`PRIVACY_POLICY.md` and `TERMS_OF_SERVICE.md` to match, bump the
"Last updated" date in all three places (Dart constants, both Markdown files,
and the screens' last-updated line in `legal_screens.dart`), and re-check the
Data Safety / App Privacy answers above against the new text before the next
store submission.
