/// Full English legal texts for HERO DRAMA.
///
/// These constants are the single source of truth for the in-app legal
/// screens. The same texts are published as standalone documents in
/// `docs/PRIVACY_POLICY.md` and `docs/TERMS_OF_SERVICE.md` for use as the
/// store-listing URLs.
///
/// Placeholders that the owner MUST replace before store submission:
/// - `support@herodrama.app` — placeholder support email.
/// - `[Your Jurisdiction]` — governing-law jurisdiction in the Terms.
library;

/// Privacy Policy — last updated November 22, 2026.
const String privacyPolicy = r'''
HERO DRAMA — PRIVACY POLICY

Last updated: November 22, 2026

1. INTRODUCTION

Welcome to HERO DRAMA ("HERO DRAMA", "we", "us", or "our"). HERO DRAMA is a short-drama streaming application that lets you discover, watch, and follow short-form drama series, save your progress, earn and spend virtual coins, and subscribe to VIP benefits.

This Privacy Policy explains what information we collect when you use the HERO DRAMA mobile application and related services (together, the "Service"), how we use that information, with whom we share it, how long we keep it, and the rights and choices available to you. By creating an account or otherwise using the Service, you acknowledge that you have read this Privacy Policy.

If you do not agree with this Privacy Policy, please do not use the Service. If you have questions about this policy or about your information, contact us at support@herodrama.app (placeholder — replace with your monitored support address before publication).

2. DATA WE COLLECT

We collect only the information needed to operate, secure, and improve the Service. The categories below describe what we collect and where it comes from.

2.1 Account identifiers and contact information
When you create an account, we receive and store an account identifier for your account. Depending on how you sign in, this includes:
- Email address, when you register with email and password or sign in with Google or Apple.
- A unique user identifier issued by Firebase Authentication and, where applicable, an identifier issued by your sign-in provider (Google or Apple).
- Your sign-in provider (email/password, Google, Apple, or guest/anonymous).
Guest accounts are created with an anonymous identifier and no email address unless and until you link the guest account to an email, Google, or Apple credential.

2.2 Profile information
We store the display name and profile avatar you provide or that your sign-in provider shares with us with your permission (for example, the name and profile photo associated with your Google account, or the name you choose to share through Sign in with Apple). You can change your display name and avatar in the app at any time.

2.3 Watch history and episode progress
To provide Continue Watching, watch-history checkmarks, recommendations, and resume playback, we store:
- The series and episodes you watch.
- Your playback position and completion status for each episode.
- Your watch history, favourites, and My List entries.
- Episode progress records that show which episodes of a series you have started or completed.

2.4 Virtual coins and transaction records
HERO DRAMA includes a virtual coin economy. We store:
- Your current coin balance.
- A ledger of coin transactions, including coins earned (for example through rewards, missions, streaks, referrals, and rewarded advertisements), coins spent (for example to unlock episodes), bonuses, and adjustments.
- Records needed to prevent fraud and duplicate claims, such as reward-claim identifiers and timestamps.
Coin records contain no payment-card information. Coins are virtual items with no cash value, as described in our Terms of Service.

2.5 Subscription and purchase status
If you subscribe to VIP or make another in-app purchase, the purchase itself is processed by the Apple App Store or Google Play. We receive and store subscription status information from RevenueCat, our subscription-management provider — such as the product purchased, subscription status (active, cancelled, expired, in trial, or in a billing grace period), and renewal or expiry dates — so we can grant or remove VIP access. We do not receive or store your full payment-card number or other payment credentials.

2.6 Device and app information
We and our service providers collect limited technical information about the device and app installation you use, including:
- Device model, operating system and version, and app version.
- A device or installation identifier used for security, analytics, push notifications, and advertising.
- Language, region or country settings, and time zone.
- App performance and diagnostic information.

2.7 Usage analytics
We collect information about how you interact with the Service, such as screens viewed, features used, episodes started and completed, searches performed in the app, session duration, and taps on recommendations. We use this information in aggregate and pseudonymous form to understand which content and features are popular and to improve the Service.

2.8 Crash reports and diagnostics
If the app crashes or encounters an error, we receive a crash report that may include the device model, operating system version, app version, a stack trace, and the state of the app at the time of the error. Crash reports are used only to diagnose and fix defects and to improve stability.

2.9 Push notification data
If you enable push notifications, we store a push token associated with your device so that OneSignal, our push-notification provider, can deliver notifications you have opted in to receive, such as new-episode alerts and reminders. You can disable push notifications at any time in your device settings or in the app.

2.10 Information you send to us
If you contact support, we keep the contents of your message, your email address, and our replies so that we can respond to you and maintain a record of the request.

We do not collect precise location data, contacts, photos, microphone recordings, or health data, and the Service does not ask for access to them to provide its core features.

3. HOW WE USE YOUR DATA

We use the information described above for the following purposes:
- To create and maintain your account and to authenticate you when you sign in, including linking a guest account to a permanent sign-in method.
- To stream content and to remember your watch history, episode progress, favourites, and preferences across sessions and devices signed in to the same account.
- To operate the virtual coin economy: to credit coins you earn, debit coins you spend, maintain your transaction ledger, enforce earning limits, and detect and prevent fraud, abuse, and duplicate claims.
- To manage VIP subscriptions and purchases: to verify subscription status with RevenueCat and the app stores, grant VIP benefits while a subscription is active, and restore purchases on a new device.
- To send push notifications you have enabled, such as new-episode and continue-watching reminders.
- To show advertisements, including rewarded advertisements that you choose to watch in exchange for coins or other in-app rewards, and to measure ad performance.
- To analyse usage, fix crashes and defects, test new features, and improve content recommendations, performance, and reliability.
- To protect the security and integrity of the Service, enforce our Terms of Service, and prevent cheating, unauthorised access, and other misuse.
- To respond to your support requests and communicate with you about your account, subscriptions, and important changes to the Service or to this policy.
- To comply with legal obligations and to respond to lawful requests from public authorities where we are required to do so.

We do not sell your personal information. We do not use your watch history or account information to build advertising profiles for third parties outside the advertising described in Section 5.

4. LEGAL BASES AND PURPOSES

Where data-protection law requires a legal basis for processing (for example in the European Economic Area and the United Kingdom), we rely on the following bases:
- Performance of a contract: processing needed to provide the Service you requested, including account creation, streaming, progress sync, the coin economy, and subscription access.
- Legitimate interests: processing needed to secure the Service, prevent fraud, measure and improve performance and content, and understand aggregate usage, where those interests are not overridden by your rights.
- Consent: processing that depends on your choice, such as push notifications and, where required by law or platform rules, personalised advertising and certain analytics. You may withdraw consent at any time through your device or app settings; withdrawal does not affect processing already carried out.
- Legal obligation: processing needed to comply with applicable law, tax and accounting requirements, and lawful orders.

If you are located in a jurisdiction that grants you specific rights (such as California under the CCPA/CPRA), Section 8 describes how to exercise them. We honour verified requests as required by applicable law regardless of where you live.

5. THIRD-PARTY PROCESSORS AND SHARING

We share information only with the service providers listed below, only for the purposes described, and only to the extent needed for them to perform their services for us. Each provider processes data under its own privacy policy and contractual terms.

5.1 Firebase and Google (Google LLC)
We use Firebase services provided by Google for:
- Firebase Authentication — account creation and sign-in (email/password, Google, Apple, and guest). Firebase receives your email address, provider identifier, and authentication tokens.
- Firebase Analytics (Google Analytics for Firebase) — pseudonymous usage analytics, device and app information, and event data.
- Firebase Crashlytics — crash reports and diagnostics described in Section 2.8.
- Firebase Remote Config and related infrastructure — app configuration and service delivery.
Google's privacy policy is available at https://policies.google.com/privacy.

5.2 Apple (Apple Inc.)
If you choose Sign in with Apple, Apple provides us with your name (if you choose to share it), your email address or an Apple private relay email address, and a stable Apple user identifier. If you subscribe or purchase through the App Store, Apple also processes your payment and provides subscription status through RevenueCat. Apple's privacy policy is available at https://www.apple.com/legal/privacy/.

5.3 RevenueCat (RevenueCat, Inc.)
We use RevenueCat to manage subscriptions and in-app purchases across the App Store and Google Play. RevenueCat receives a pseudonymous app user identifier, purchase receipts and subscription status from Apple and Google, product identifiers, and country/storefront information. RevenueCat does not receive your payment-card details from us. RevenueCat's privacy policy is available at https://www.revenuecat.com/privacy.

5.4 Google AdMob (Google LLC)
We use Google AdMob to display advertisements, including rewarded advertisements. AdMob may collect and use device and advertising identifiers, approximate (coarse) location derived from IP address, device and app information, and ad-interaction data to deliver and measure ads and to prevent invalid activity. Where required, ads may be non-personalised. You can reset or limit use of your advertising identifier in your device settings. Google's advertising practices are described at https://policies.google.com/technologies/ads.

5.5 OneSignal (OneSignal, Inc.)
We use OneSignal to deliver push notifications. OneSignal receives your device push token, device and app information, language and time zone, and notification delivery and open events. OneSignal's privacy policy is available at https://onesignal.com/privacy_policy.

5.6 Other sharing
We may also disclose information:
- If required by law, court order, or lawful governmental request.
- To protect the rights, property, or safety of HERO DRAMA, our users, or the public, and to detect, prevent, or address fraud, security, or technical issues.
- In connection with a merger, acquisition, financing, or sale of all or part of our business, subject to confidentiality and to notice where required by law.
We do not share your personal information with data brokers, and we do not sell personal information as that term is defined under applicable privacy laws.

6. DATA RETENTION

We keep personal information only for as long as it is needed for the purposes in this policy:
- Account, profile, watch-history, progress, and coin-ledger data are kept while your account is active.
- When you delete your account using the in-app deletion flow (Account → Delete Account), your account and associated personal data — including profile, watch history, progress, and coin balance and ledger — are deleted from our active systems, except for records we must retain for legal, tax, accounting, security, or fraud-prevention purposes. Backup copies are removed in the ordinary backup cycle, normally within 90 days.
- Subscription records may be retained after deletion to the extent required for accounting, chargeback, and legal compliance; these records are not used for marketing.
- Analytics data is retained by Firebase Analytics in accordance with its retention settings and Google's policies, in pseudonymous or aggregated form.
- Crash reports are retained only as long as needed to diagnose and resolve defects.
- Support correspondence is retained for up to 24 months after the request is closed, unless a longer period is required by law.
When data is no longer needed, we delete it or anonymise it so that it can no longer identify you.

7. SECURITY

We use administrative, technical, and organisational measures designed to protect your information, including encrypted connections (HTTPS/TLS) between the app and our servers, access controls that limit employee and provider access to data needed for their role, signed and expiring playback URLs for protected content, and authentication provided by Firebase Authentication. No method of transmission or storage is completely secure, and we cannot guarantee absolute security. You are responsible for keeping your account credentials confidential and for signing out of shared devices.

8. YOUR RIGHTS AND CHOICES

Subject to applicable law, you have the following rights regarding your personal information:
- Access: request a copy of the personal information we hold about you.
- Correction: ask us to correct inaccurate or incomplete information. You can update your display name and avatar directly in the app.
- Export: request an export of your account data, including your profile, watch history, and coin transaction history, in a commonly used format.
- Deletion: delete your account and associated personal data at any time in the app via Account → Delete Account. This action is permanent: it wipes your profile, watch history and progress, favourites, and coin balance and ledger, and it cannot be undone. Deleting your account does not cancel an active VIP subscription — subscriptions must be cancelled separately in your App Store or Google Play account settings (see the Subscription & Purchases terms). If you cannot access the app, you may request deletion by emailing support@herodrama.app from the email address associated with your account.
- Objection and restriction: object to, or ask us to restrict, certain processing based on legitimate interests.
- Withdraw consent: disable push notifications in your device or app settings, and reset or limit your advertising identifier in your device settings.
- Complaint: lodge a complaint with your local data-protection authority.

To exercise access, correction, export, objection, or restriction rights, email support@herodrama.app (placeholder — replace before publication). For your protection, we may verify your identity — for example by asking you to write from the email address associated with the account — before fulfilling a request. We respond to verified requests within the time required by applicable law, normally within 30 days. We will not discriminate against you for exercising your rights.

9. CHILDREN'S PRIVACY

HERO DRAMA is not directed to children under the age of 13, and use of the Service requires that you be at least 13 years old (or the minimum age of digital consent in your jurisdiction, if higher). We do not knowingly collect personal information from children under 13. If we learn that a child under 13 has provided us with personal information or created an account, we will delete the account and the associated information promptly. If you are a parent or guardian and believe that your child under 13 has used the Service, please contact us at support@herodrama.app so that we can take action.

10. INTERNATIONAL TRANSFERS

We and our processors (including Google/Firebase, RevenueCat, OneSignal, Apple, and Google AdMob) may process and store information in countries other than the one in which you live, including the United States. Those countries may have data-protection laws that differ from the laws of your jurisdiction. Where required, we rely on appropriate safeguards for international transfers, such as standard contractual clauses or the recipient country's adequacy status, and our processors maintain their own transfer safeguards described in their privacy policies. By using the Service, you understand that your information may be transferred as described in this section.

11. CHANGES TO THIS POLICY

We may update this Privacy Policy from time to time, for example when we add features or change processors. When we make a material change, we will update the "Last updated" date above and, where appropriate, notify you in the app or by email before the change takes effect. Your continued use of the Service after an updated policy takes effect constitutes acknowledgement of the updated policy. Earlier versions are available on request at support@herodrama.app.

12. CONTACT US

If you have questions, concerns, or requests regarding this Privacy Policy or your personal information, contact us at:

HERO DRAMA — Privacy
Email: support@herodrama.app (placeholder — replace with your monitored support address before publication)
''';

/// Terms of Service — last updated November 22, 2026.
const String termsOfService = r'''
HERO DRAMA — TERMS OF SERVICE

Last updated: November 22, 2026

1. AGREEMENT TO THESE TERMS

These Terms of Service ("Terms") are a binding agreement between you and the operator of HERO DRAMA ("HERO DRAMA", "we", "us", or "our") governing your use of the HERO DRAMA mobile application and related services (together, the "Service"). By downloading, installing, creating an account for, or otherwise using the Service, you agree to these Terms and to our Privacy Policy. If you do not agree, do not use the Service.

The governing-law jurisdiction and operator details marked [Your Jurisdiction] in Section 15 must be completed by the operator before publication.

2. ELIGIBILITY

You must be at least 13 years old to use the Service. If you are under the age of majority in your jurisdiction, you may use the Service only with the permission and supervision of a parent or legal guardian, who agrees to be bound by these Terms on your behalf. By using the Service, you represent that you meet these requirements and that the information you provide is accurate. The Service is not directed to children under 13, and accounts found to belong to a child under 13 will be terminated and deleted.

3. ACCOUNTS

3.1 Account creation. You may create an account using email and password, Google, Apple, or as a guest. You are responsible for all activity under your account.

3.2 Guest accounts. A guest account is created automatically with an anonymous identifier so that you can try the Service without registering. Guest accounts may have limited features, and guest data (including watch progress and coins) is stored against the anonymous identifier. If the app is uninstalled, the device is lost, or the anonymous credential is otherwise lost before linking, a guest account and its contents may be unrecoverable.

3.3 Linking accounts. You may link a guest account to an email, Google, or Apple credential in the app's account settings. Linking preserves your watch history, progress, and coin balance under the linked credential and lets you sign in on other devices. If you link to a credential that already belongs to another existing account, the accounts cannot be merged automatically; contact support for assistance, and note that coins and progress from separate accounts are not combined except where we confirm a manual resolution.

3.4 Account security. Keep your credentials confidential and notify us promptly at support@herodrama.app if you suspect unauthorised use. We may require re-authentication for sensitive actions such as changing your email address or deleting your account.

3.5 Accuracy. You agree to provide accurate information and to keep it up to date. You may not impersonate another person, create an account for someone else without permission, or create multiple accounts to abuse promotions, rewards, referrals, or the coin economy.

4. THE SERVICE AND CONTENT

4.1 The Service. HERO DRAMA provides streaming access to short-form drama series and episodes, together with features such as watch history, episode progress, favourites, rewards, virtual coins, and VIP subscriptions. Features may vary by region, device, and app version.

4.2 Content ownership. All content made available through the Service — including series, episodes, video, audio, images, posters, artwork, text, subtitles, and metadata (collectively, "Content") — is owned by HERO DRAMA or its licensors and is protected by copyright and other intellectual-property laws. These Terms grant you no ownership interest in any Content.

4.3 Your licence. Subject to your compliance with these Terms and, where applicable, payment of subscription or unlock fees, we grant you a limited, personal, non-exclusive, non-transferable, non-sublicensable, revocable licence to stream and view Content through the app for your private, non-commercial use only, on devices you own or control, for as long as the Content is made available on the Service.

4.4 Restrictions. Except through features expressly provided by the app (such as in-app offline caching, where offered), you may not: download, copy, record, capture, reproduce, redistribute, publish, broadcast, publicly perform, sell, rent, or otherwise exploit any Content; circumvent digital rights management, paywalls, signed playback URLs, or other access controls; remove or alter copyright or proprietary notices; or use Content to train machine-learning models or to build a competing service. Any unauthorised use terminates the licence in Section 4.3 automatically.

4.5 App ownership. The Service, including the app, software, design, logos, and the HERO DRAMA name and marks, is owned by us or our licensors. You may not copy, modify, reverse-engineer (except where that restriction is prohibited by law), or create derivative works from the app, and you may not use our trademarks without prior written permission.

4.6 User submissions. If the Service lets you submit a display name, avatar, comments, or other material, you retain ownership of what you submit, and you grant us a worldwide, royalty-free licence to host, store, display, and use it as needed to operate the Service. You are responsible for your submissions and must not submit material that is unlawful, infringing, or abusive. We may remove submissions that violate these Terms.

5. VIRTUAL COINS

5.1 Nature of coins. "Coins" are virtual items used only inside HERO DRAMA to unlock episodes and access other in-app benefits. Coins have no cash or monetary value, are not currency, are not a payment instrument, and cannot be redeemed for cash, goods, or services outside the Service.

5.2 Earning and spending. Coins may be earned through in-app activities (for example daily rewards, missions, streaks, referrals, and watching rewarded advertisements), granted as bonuses, or obtained through offers presented in the app. Coins are spent when you unlock content or redeem an in-app benefit; the applicable price is shown before you confirm the spend.

5.3 No transfer. Coins are tied to your account. They are non-transferable: you may not sell, trade, gift, assign, or otherwise transfer coins or your account to another person, and any attempted transfer is void.

5.4 No refunds for coins. Coin earnings, bonuses, and spends are final and non-refundable, except where a refund is required by applicable law or by the applicable app store's policies. If a technical error causes a confirmed coin spend to fail to deliver the unlocked content, contact support and we will restore the content or re-credit the coins.

5.5 Adjustments. We may adjust, correct, or revoke coin balances where we reasonably determine that coins were credited or spent due to fraud, abuse, exploitation of a bug, duplicate or forged claims, chargebacks, or manifest error. Where practical, we will note the reason for a material adjustment in your transaction history.

5.6 Expiry and forfeiture. Bonus or promotional coins may carry an expiry date shown in the app. On account deletion, coins are permanently forfeited with the account. On termination of your account for cause under Section 12, any remaining coin balance is forfeited. Coins have no value on forfeiture and no compensation is payable.

6. VIP SUBSCRIPTIONS AND PURCHASES

6.1 VIP benefits. A VIP subscription provides the benefits described on the paywall at the time of purchase (for example, access to VIP episodes without per-episode coin spends) for the duration of the subscription period. The catalogue and benefits available to VIP members may change as content is added or removed.

6.2 Auto-renewal. VIP subscriptions are auto-renewing. Unless you cancel, your subscription renews automatically at the end of each period (for example weekly, monthly, or yearly, as selected) and your App Store or Google Play account is charged the then-current price for the next period.

6.3 Price and currency. Prices are shown on the paywall and on the store's confirmation screen in your store account's currency, inclusive of taxes where the store displays them that way. The store's price and confirmation prevail if they differ from any other display.

6.4 Managing and cancelling. Subscriptions are managed entirely through your Apple App Store or Google Play account settings — not in the app and not by emailing us. Cancelling stops future renewals; you keep VIP access until the end of the current paid period, after which access ends. Deleting the app or deleting your HERO DRAMA account does not cancel a subscription. Step-by-step cancellation, renewal-timing, restore, price-change, and refund terms are set out in the separate Subscription & Purchases terms, which form part of these Terms.

6.5 Free trials and offers. If a free trial or introductory offer is offered, its duration and terms are shown on the paywall and the store's confirmation screen. Unless you cancel before the trial ends, it converts to a paid auto-renewing subscription at the price shown. Eligibility for trials is determined by Apple or Google, and a trial generally cannot be repeated for the same store account.

6.6 Other purchases. Any other in-app purchases (where offered) are likewise processed by the App Store or Google Play and are subject to the Subscription & Purchases terms and the store's own terms.

7. ACCEPTABLE USE

You agree not to:
- Violate any applicable law or regulation, or infringe the rights of others.
- Access, or attempt to access, content, accounts, coins, or benefits that you are not entitled to, including by circumventing paywalls, coin checks, signed playback URLs, or subscription verification.
- Forge, falsify, or automate watch time, episode progress, ad views, referrals, or reward claims, or use bots, scripts, emulators, or modified clients to earn coins or other benefits.
- Interfere with, disrupt, overload, or attempt to probe, scan, or test the vulnerability of the Service, our servers, or connected networks.
- Upload or transmit malware, or attempt to gain unauthorised access to accounts, systems, or data.
- Harass, abuse, or harm other users, or submit unlawful, infringing, defamatory, or obscene material.
- Resell access to the Service, or use the Service for any commercial purpose not expressly authorised in writing by us.
- Misrepresent your identity or affiliation, or use the Service in a way that could damage the reputation of HERO DRAMA or its licensors.
We may investigate suspected violations and cooperate with law-enforcement requests as required by law.

8. AVAILABILITY AND CHANGES

The Service and its catalogue change over time. We may add, remove, or modify series, episodes, features, coin earning rates and prices, and VIP benefits; we may also release updates that you may need to install to continue using the Service. Content availability may vary by territory due to licensing. We do not guarantee that any particular series, episode, or feature will remain available, and we are not liable for the removal of content or changes to the coin economy made in accordance with this section. Where a change materially reduces a paid VIP benefit during a current paid period, your remedy is limited to cancellation taking effect at the next renewal.

9. THIRD-PARTY SERVICES AND ADVERTISING

The Service relies on third-party services including Firebase/Google, Apple, RevenueCat, Google AdMob, and OneSignal, and contains advertising, including rewarded advertisements. Your use of those services is also subject to their terms and privacy policies. We are not responsible for third-party services, content, or advertisements, and an advertisement is not an endorsement of the advertised product or service.

10. DISCLAIMERS

TO THE MAXIMUM EXTENT PERMITTED BY LAW, THE SERVICE AND ALL CONTENT ARE PROVIDED "AS IS" AND "AS AVAILABLE", WITHOUT WARRANTIES OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, TITLE, NON-INFRINGEMENT, AND ANY WARRANTY THAT THE SERVICE WILL BE UNINTERRUPTED, ERROR-FREE, SECURE, OR FREE OF HARMFUL COMPONENTS, OR THAT CONTENT WILL BE ACCURATE OR AVAILABLE IN ANY PARTICULAR TERRITORY. Some jurisdictions do not allow the exclusion of certain warranties, so some of the above exclusions may not apply to you; in that case our liability is limited as set out in Section 11.

11. LIMITATION OF LIABILITY

TO THE MAXIMUM EXTENT PERMITTED BY LAW, IN NO EVENT WILL HERO DRAMA, ITS OPERATOR, LICENSORS, OR SERVICE PROVIDERS BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, EXEMPLARY, OR PUNITIVE DAMAGES, OR FOR LOSS OF PROFITS, REVENUE, DATA, COINS, GOODWILL, OR OTHER INTANGIBLE LOSSES, ARISING OUT OF OR RELATING TO YOUR USE OF OR INABILITY TO USE THE SERVICE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGES. TO THE MAXIMUM EXTENT PERMITTED BY LAW, OUR TOTAL AGGREGATE LIABILITY FOR ALL CLAIMS RELATING TO THE SERVICE WILL NOT EXCEED THE GREATER OF (A) THE AMOUNT YOU PAID TO US THROUGH THE APP STORES FOR THE SERVICE IN THE SIX MONTHS BEFORE THE CLAIM AROSE, OR (B) USD 50. Nothing in these Terms limits liability that cannot be limited under applicable law, including liability for death or personal injury caused by negligence or for fraud.

12. TERMINATION

12.1 By you. You may stop using the Service at any time and may delete your account in the app via Account → Delete Account. Deletion is permanent and forfeits your coin balance as described in Section 5.6. Deletion does not cancel an active store subscription (see Section 6.4).

12.2 By us. We may suspend or terminate your account or access to the Service, with or without notice, if you materially breach these Terms, engage in fraud or abuse of the coin economy or referral or rewards systems, infringe intellectual-property rights, or use the Service unlawfully; or if we are required to do so by law or by a store or licensor requirement. Where the breach is reasonably capable of remedy and does not involve fraud or infringement, we will give you reasonable notice and an opportunity to remedy it where practical.

12.3 Effect of termination. On termination, your licence to use the Service and Content ends immediately. Sections that by their nature should survive termination — including Sections 4.2, 4.5, 5, 10, 11, 13, and 15 — survive. Termination for cause forfeits any remaining coin balance.

13. INDEMNITY

To the extent permitted by law, you agree to indemnify and hold harmless HERO DRAMA, its operator, and its licensors and service providers from claims, damages, liabilities, and reasonable legal costs arising from your misuse of the Service, your submissions, or your breach of these Terms. This section does not apply to the extent a claim arises from our own negligence or breach.

14. PRIVACY

Our collection and use of personal information is described in the Privacy Policy, which forms part of these Terms. Account deletion, your privacy rights, and our third-party processors are described there.

15. GOVERNING LAW AND DISPUTES

These Terms are governed by the laws of [Your Jurisdiction], without regard to its conflict-of-laws rules. The courts located in [Your Jurisdiction] will have exclusive jurisdiction over disputes arising under these Terms, except that nothing in this section deprives you of the protection of mandatory consumer-protection laws of the country in which you habitually reside, or of your right to bring proceedings in the courts of that country where those laws so provide. If any provision of these Terms is held unenforceable, the remaining provisions remain in full effect. Our failure to enforce a provision is not a waiver of it. You may not assign these Terms or your account without our consent; we may assign these Terms in connection with a merger, acquisition, or sale of assets.

16. CHANGES TO THESE TERMS

We may update these Terms from time to time. When we make a material change, we will update the "Last updated" date and, where appropriate, notify you in the app or by email. Your continued use of the Service after updated Terms take effect constitutes acceptance of them. If you do not agree to updated Terms, stop using the Service and, if you wish, delete your account.

17. CONTACT

Questions about these Terms may be sent to:

HERO DRAMA — Support
Email: support@herodrama.app (placeholder — replace with your monitored support address before publication)
''';

/// Subscription & Purchases terms — last updated November 22, 2026.
const String subscriptionTerms = r'''
HERO DRAMA — SUBSCRIPTION & PURCHASES TERMS

Last updated: November 22, 2026

These Subscription & Purchases terms explain how billing for HERO DRAMA VIP subscriptions and other in-app purchases works. They form part of the HERO DRAMA Terms of Service. All purchases are processed by the Apple App Store (for iOS) or Google Play (for Android). HERO DRAMA never receives or stores your payment-card details. Subscription status is managed for us by RevenueCat.

1. WHAT YOU ARE BUYING

A VIP subscription provides the benefits shown on the paywall at the time of purchase — such as access to VIP episodes without per-episode coin spends — for the subscription period you select (for example weekly, monthly, or yearly). The subscription is tied to the HERO DRAMA account that made the purchase and to the store account used to pay.

2. HOW BILLING WORKS — APPLE APP STORE (iOS)

- When you confirm a purchase, payment is charged to your Apple ID account by Apple at confirmation.
- Subscriptions renew automatically unless auto-renew is turned off at least 24 hours before the end of the current period.
- Your Apple ID account is charged for renewal within 24 hours before the end of the current period, at the price shown for the next period.
- Any free trial or introductory offer converts to a paid subscription automatically at the end of the trial unless you cancel before the trial ends.
- Apple sends receipts and manages payment methods, taxes charged by the store, and billing questions for iOS purchases.

3. HOW BILLING WORKS — GOOGLE PLAY (ANDROID)

- When you confirm a purchase, payment is charged by Google to the payment method on your Google Play account at confirmation.
- Subscriptions renew automatically on the renewal date shown in Google Play unless you cancel before that date.
- Your Google Play account is charged for each renewal at the price shown for the next period. Google Play may retry a failed payment during a grace period and may place the subscription on hold if payment cannot be collected; VIP access may pause during an account hold.
- Any free trial or introductory offer converts to a paid subscription automatically at the end of the trial unless you cancel before the trial ends.
- Google sends receipts and manages payment methods and billing questions for Android purchases.

4. RENEWAL TIMING

Subscriptions renew at the end of each billing period. Renewal charges are processed by the store within the 24 hours before the current period ends (Apple) or on the renewal date (Google Play), at the then-current price for your plan, in your store account's currency. To avoid being charged for the next period, cancel before the renewal charge is processed — for Apple, at least 24 hours before the period ends.

5. HOW TO CANCEL — iOS (APPLE APP STORE)

1. Open the Settings app on your iPhone or iPad.
2. Tap your name (Apple ID) at the top.
3. Tap "Subscriptions".
4. Tap your HERO DRAMA subscription.
5. Tap "Cancel Subscription" and confirm.
Alternatively, open the App Store, tap your profile picture, tap "Subscriptions", select HERO DRAMA, and cancel there. After cancelling, you keep VIP access until the end of the current paid period; no further renewals are charged.

6. HOW TO CANCEL — ANDROID (GOOGLE PLAY)

1. Open the Google Play Store app.
2. Tap your profile icon, then "Payments & subscriptions".
3. Tap "Subscriptions".
4. Tap your HERO DRAMA subscription.
5. Tap "Cancel subscription" and follow the on-screen steps.
After cancelling, you keep VIP access until the end of the current paid period; no further renewals are charged. Uninstalling the app, or deleting your HERO DRAMA account, does not cancel a subscription — you must cancel in the store as described above.

7. RESTORE PURCHASES

If you reinstall the app, switch devices, or your VIP status does not appear:
- Sign in to HERO DRAMA with the same account you used when you purchased.
- Use the same Apple ID or Google Play account that made the purchase.
- Open the paywall or VIP screen in the app and tap "Restore Purchases". The app asks RevenueCat and the store to re-validate your receipts and restores active subscription access.
Restores grant access to subscriptions that are still active; they do not revive expired subscriptions and do not restore coins, which are account-based and are forfeited on account deletion.

8. PRICE CHANGES

Subscription prices may change. Apple and Google notify you of price increases as required by their policies and applicable law; where the store requires your consent to a price increase, the increase applies only if you agree, and otherwise the subscription may not renew. The price in effect at each renewal is the price charged for that period. Current prices are always shown on the paywall and on the store's confirmation screen before you are charged.

9. REFUNDS

Refunds for purchases made through the App Store or Google Play are handled exclusively by Apple or Google under their own policies — HERO DRAMA cannot issue refunds for store purchases and does not receive your payment funds directly.
- Apple: request a refund at https://reportaproblem.apple.com or through Apple Support.
- Google Play: request a refund through Google Play order history or Google Play support.
If a store refunds a subscription period, VIP access for the refunded period may be revoked, and coins or unlocks obtained through the refunded purchase may be reversed. Nothing in this section limits any non-waivable consumer refund rights you have under applicable law.

10. TRIALS AND INTRODUCTORY OFFERS

Where a free trial or introductory price is offered, its length, price after the trial, and eligibility are shown on the paywall and confirmed by the store before the trial starts. Trials are generally limited to one per store account and per user, as determined by Apple or Google. Cancel before the trial ends to avoid being charged (see Sections 5 and 6).

11. QUESTIONS

For questions about what a subscription includes or about your HERO DRAMA account, contact support@herodrama.app (placeholder — replace before publication). For questions about a charge, payment method, or refund, contact Apple Support or Google Play support, as they process all payments.
''';

/// Convenience holder mirroring the top-level constants.
class LegalTexts {
  const LegalTexts._();

  static const String privacyPolicyText = privacyPolicy;
  static const String termsOfServiceText = termsOfService;
  static const String subscriptionTermsText = subscriptionTerms;

  /// Date shown on every legal screen.
  static const String lastUpdatedLabel = 'Last updated: November 22, 2026';
}
