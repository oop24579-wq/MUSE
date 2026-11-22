import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_it.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_tr.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('it'),
    Locale('ja'),
    Locale('ko'),
    Locale('pt'),
    Locale('ru'),
    Locale('tr'),
    Locale('zh')
  ];

  /// The title of the application
  ///
  /// In en, this message translates to:
  /// **'HERO DRAMA'**
  String get appTitle;

  /// Settings screen title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Language selection label
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Language selection dialog title
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// Success message when language is changed
  ///
  /// In en, this message translates to:
  /// **'Language changed to {languageName}'**
  String languageChanged(String languageName);

  /// Error message when language change fails
  ///
  /// In en, this message translates to:
  /// **'Failed to change language: {error}'**
  String failedToChangeLanguage(String error);

  /// Browse stations category title
  ///
  /// In en, this message translates to:
  /// **'Browse Stations'**
  String get pickToEdit;

  /// Browse stations category subtitle
  ///
  /// In en, this message translates to:
  /// **'Find stations by genre, country, or language'**
  String get selectPhotoFromGallery;

  /// Gallery selection label
  ///
  /// In en, this message translates to:
  /// **'Select from gallery'**
  String get selectFromGallery;

  /// Upload and edit button text
  ///
  /// In en, this message translates to:
  /// **'Upload and Edit'**
  String get uploadAndEdit;

  /// Error message when no image is selected
  ///
  /// In en, this message translates to:
  /// **'Please select an image first'**
  String get pleaseSelectImageFirst;

  /// Featured stations category title
  ///
  /// In en, this message translates to:
  /// **'Featured Stations'**
  String get featured;

  /// Featured stations category subtitle
  ///
  /// In en, this message translates to:
  /// **'Explore curated radio picks'**
  String get exploreFeaturedEdits;

  /// Pro subscription label
  ///
  /// In en, this message translates to:
  /// **'Pro'**
  String get pro;

  /// Switch to dark appearance; settings row label
  ///
  /// In en, this message translates to:
  /// **'Dark mode'**
  String get darkMode;

  /// Switch to light appearance; settings row label
  ///
  /// In en, this message translates to:
  /// **'Light mode'**
  String get lightMode;

  /// Settings row and sheet title for earning free songs
  ///
  /// In en, this message translates to:
  /// **'Get Pro perks'**
  String get getFreeSongs;

  /// Reward task title: daily check-in
  ///
  /// In en, this message translates to:
  /// **'Daily Check-in'**
  String get rewardDailyCheckIn;

  /// Daily check-in reward amount line
  ///
  /// In en, this message translates to:
  /// **'✦ {amount} today'**
  String rewardDailyCheckInToday(int amount);

  /// Hint for next check-in reward
  ///
  /// In en, this message translates to:
  /// **'Check in tomorrow for ✦ {amount}'**
  String rewardDailyCheckInTomorrowHint(int amount);

  /// Reward task already completed state
  ///
  /// In en, this message translates to:
  /// **'Claimed'**
  String get rewardClaimed;

  /// Button to claim a daily check-in reward
  ///
  /// In en, this message translates to:
  /// **'Claim'**
  String get rewardClaim;

  /// Button to open the share sheet for share rewards
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get rewardShare;

  /// Toast when free song credits are granted
  ///
  /// In en, this message translates to:
  /// **'+{count} perk'**
  String rewardCreditsEarned(int count);

  /// Toast when multiple free song credits are granted
  ///
  /// In en, this message translates to:
  /// **'+{count} perks'**
  String rewardCreditsEarnedPlural(int count);

  /// Daily check-in already completed
  ///
  /// In en, this message translates to:
  /// **'Already claimed today'**
  String get rewardAlreadyClaimedToday;

  /// Share or invite reward limit reached
  ///
  /// In en, this message translates to:
  /// **'Limit reached for today'**
  String get rewardLimitReached;

  /// Generic free songs reward failure
  ///
  /// In en, this message translates to:
  /// **'Could not complete reward. Try again.'**
  String get rewardActionFailed;

  /// Reward task title: share to earn
  ///
  /// In en, this message translates to:
  /// **'Daily Share Creation'**
  String get rewardDailyShareCreation;

  /// Suffix for per-share reward line after gold amount
  ///
  /// In en, this message translates to:
  /// **' / share, max {maxShares}'**
  String rewardPerShareSuffix(int maxShares);

  /// Footer explaining share rewards progress
  ///
  /// In en, this message translates to:
  /// **'You can earn up to ✦ {maxPerDay} per day from sharing; you\'ve earned ✦ {earnedSoFar} so far.'**
  String rewardShareEarnedFooter(int maxPerDay, int earnedSoFar);

  /// Reward sheet button to open share flow
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get rewardView;

  /// Reward task title: invite friends
  ///
  /// In en, this message translates to:
  /// **'Invite New Friend'**
  String get rewardInviteNewFriend;

  /// Suffix after gold amount for invite rewards
  ///
  /// In en, this message translates to:
  /// **' / friend'**
  String get rewardPerFriendSuffix;

  /// Footer explaining invite limits and progress
  ///
  /// In en, this message translates to:
  /// **'You can invite up to {maxFriends} friends to earn Pro perks and have invited {invitedCount} so far.'**
  String rewardInviteFriendsFooter(int maxFriends, int invitedCount);

  /// Reward sheet button to invite friends
  ///
  /// In en, this message translates to:
  /// **'Invite'**
  String get rewardInvite;

  /// Profile card friends line until invites exist
  ///
  /// In en, this message translates to:
  /// **'{count} friends'**
  String settingsProfileFriendsPlaceholder(int count);

  /// Profile card subtitle encouraging upgrade
  ///
  /// In en, this message translates to:
  /// **'Unlimited episodes, ad-free & exclusive dramas'**
  String get settingsProfileUpgradeSubtitle;

  /// Profile card subtitle for Pro users
  ///
  /// In en, this message translates to:
  /// **'Unlimited episodes & ad-free unlocked'**
  String get settingsProfileProSubtitle;

  /// Profile card upgrade button
  ///
  /// In en, this message translates to:
  /// **'Upgrade'**
  String get settingsProfileUpgrade;

  /// Settings promo banner headline for free users
  ///
  /// In en, this message translates to:
  /// **'Go Pro'**
  String get settingsPromoBannerTitle;

  /// Settings promo banner headline for Pro users
  ///
  /// In en, this message translates to:
  /// **'VIP Member'**
  String get settingsProBannerTitle;

  /// Settings social links card header
  ///
  /// In en, this message translates to:
  /// **'Contact us'**
  String get settingsContactUs;

  /// Profile card sign-in CTA for guests
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get settingsProfileSignIn;

  /// Profile card invite button placeholder
  ///
  /// In en, this message translates to:
  /// **'Invite'**
  String get settingsProfileInvite;

  /// Semantics label for balance info icon
  ///
  /// In en, this message translates to:
  /// **'Pro listening perks available on your account.'**
  String get settingsProfileSongBalanceHint;

  /// Tappable row opening rewards sheet
  ///
  /// In en, this message translates to:
  /// **'Get Pro perks'**
  String get settingsGetFreeSongsRow;

  /// Label above weekly visit dots
  ///
  /// In en, this message translates to:
  /// **'Weekly streak'**
  String get weeklyStreakSectionTitle;

  /// Weekly streak gift button when week is complete
  ///
  /// In en, this message translates to:
  /// **'Claim'**
  String get weeklyStreakClaimGift;

  /// Weekly streak after gift collected
  ///
  /// In en, this message translates to:
  /// **'Claimed'**
  String get weeklyStreakClaimed;

  /// No description provided for @weeklyStreakDayMon.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get weeklyStreakDayMon;

  /// No description provided for @weeklyStreakDayTue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get weeklyStreakDayTue;

  /// No description provided for @weeklyStreakDayWed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get weeklyStreakDayWed;

  /// No description provided for @weeklyStreakDayThu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get weeklyStreakDayThu;

  /// No description provided for @weeklyStreakDayFri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get weeklyStreakDayFri;

  /// No description provided for @weeklyStreakDaySat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get weeklyStreakDaySat;

  /// No description provided for @weeklyStreakDaySun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get weeklyStreakDaySun;

  /// Dialog title for 7-day reward
  ///
  /// In en, this message translates to:
  /// **'Weekly gift'**
  String get weeklyStreakModalTitle;

  /// Dialog body when streak complete
  ///
  /// In en, this message translates to:
  /// **'You visited every day this week!'**
  String get weeklyStreakModalBody;

  /// Dialog reward line
  ///
  /// In en, this message translates to:
  /// **'+{count} free perks'**
  String weeklyStreakModalReward(int count);

  /// Dialog footnote for weekly gift
  ///
  /// In en, this message translates to:
  /// **'Added to your Pro perk balance.'**
  String get weeklyStreakModalFootnote;

  /// Confirm claim button
  ///
  /// In en, this message translates to:
  /// **'Collect perks'**
  String get weeklyStreakCollect;

  /// Claim in progress
  ///
  /// In en, this message translates to:
  /// **'Collecting…'**
  String get weeklyStreakCollecting;

  /// Toast after successful claim
  ///
  /// In en, this message translates to:
  /// **'{count} free perks added!'**
  String weeklyStreakSuccess(int count);

  /// Claim error toast
  ///
  /// In en, this message translates to:
  /// **'Could not claim reward. Try again later.'**
  String get weeklyStreakClaimFailed;

  /// When RPC fails or is not deployed
  ///
  /// In en, this message translates to:
  /// **'Weekly reward unavailable.'**
  String get weeklyStreakUnavailable;

  /// Notification reminder label
  ///
  /// In en, this message translates to:
  /// **'Reminder'**
  String get reminder;

  /// Notifications toggle label
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// Toast when notifications are enabled
  ///
  /// In en, this message translates to:
  /// **'Notifications enabled'**
  String get notificationsEnabled;

  /// Toast when notifications are disabled
  ///
  /// In en, this message translates to:
  /// **'Notifications are disabled. You can enable them in your device settings.'**
  String get notificationsDisabled;

  /// Short label when notifications are disabled
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get notificationsDisabledShort;

  /// Subtitle in notification settings bottom sheet
  ///
  /// In en, this message translates to:
  /// **'Manage your push notification preferences'**
  String get notificationSettingsDescription;

  /// Label for push notifications toggle
  ///
  /// In en, this message translates to:
  /// **'Push Notifications'**
  String get pushNotifications;

  /// Redeem code menu item
  ///
  /// In en, this message translates to:
  /// **'Redeem Code'**
  String get redeemCode;

  /// Rate us menu item
  ///
  /// In en, this message translates to:
  /// **'Rate Us'**
  String get rateUs;

  /// Support menu item
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get support;

  /// Restore purchase menu item
  ///
  /// In en, this message translates to:
  /// **'Restore Purchase'**
  String get restorePurchase;

  /// Chat history menu item
  ///
  /// In en, this message translates to:
  /// **'Chat History'**
  String get chatHistory;

  /// Terms of use menu item
  ///
  /// In en, this message translates to:
  /// **'Terms of Use'**
  String get termsOfUse;

  /// Privacy policy menu item
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// Settings link label for Instagram
  ///
  /// In en, this message translates to:
  /// **'Follow us on Instagram'**
  String get followUsOnInstagram;

  /// Settings link label for Facebook
  ///
  /// In en, this message translates to:
  /// **'Follow us on Facebook'**
  String get followUsOnFacebook;

  /// Settings link label for X (Twitter)
  ///
  /// In en, this message translates to:
  /// **'Follow us on X'**
  String get followUsOnX;

  /// Settings link label for TikTok
  ///
  /// In en, this message translates to:
  /// **'Follow us on TikTok'**
  String get followUsOnTiktok;

  /// Splash screen initialization message
  ///
  /// In en, this message translates to:
  /// **'Initializing services...'**
  String get initializingServices;

  /// Splash screen configuration loading message
  ///
  /// In en, this message translates to:
  /// **'Loading configuration...'**
  String get loadingConfiguration;

  /// Splash screen ready message
  ///
  /// In en, this message translates to:
  /// **'Ready!'**
  String get ready;

  /// Retry button text
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Photo selection screen title
  ///
  /// In en, this message translates to:
  /// **'Select Photo'**
  String get selectPhoto;

  /// Take photo button label
  ///
  /// In en, this message translates to:
  /// **'Take a picture'**
  String get takeAPicture;

  /// Recently used photos section title
  ///
  /// In en, this message translates to:
  /// **'Recently Used'**
  String get recentlyUsed;

  /// Upload from gallery section title
  ///
  /// In en, this message translates to:
  /// **'Upload from Gallery'**
  String get uploadFromGallery;

  /// Continue button text
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// Input prompt hint text
  ///
  /// In en, this message translates to:
  /// **'Describe what you want'**
  String get describeWhatYouWant;

  /// Example hint text for input prompt field
  ///
  /// In en, this message translates to:
  /// **'e.g., \"Make it brighter\" or \"Remove the background\"'**
  String get inputPromptHintExample;

  /// Help message for manual prompt mode
  ///
  /// In en, this message translates to:
  /// **'Write your prompt to edit this image'**
  String get writeYourPromptToEditThisImage;

  /// User message text when image is uploaded
  ///
  /// In en, this message translates to:
  /// **'Uploaded Image'**
  String get uploadedImage;

  /// Error message when loading chat fails
  ///
  /// In en, this message translates to:
  /// **'Error loading chat: {error}'**
  String errorLoadingChat(String error);

  /// Success message when chat is deleted
  ///
  /// In en, this message translates to:
  /// **'Chat deleted'**
  String get chatDeleted;

  /// Error message when deleting chat fails
  ///
  /// In en, this message translates to:
  /// **'Error deleting chat: {error}'**
  String errorDeletingChat(String error);

  /// Empty state message when no chat history
  ///
  /// In en, this message translates to:
  /// **'No chat history'**
  String get noChatHistory;

  /// Empty state subtitle for chat history
  ///
  /// In en, this message translates to:
  /// **'Your chat conversations will appear here'**
  String get yourChatConversationsWillAppearHere;

  /// Message count text
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{no messages} =1{1 message} other{{count} messages}}'**
  String messages(num count);

  /// Time ago text for just now
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get justNow;

  /// Time ago text for minutes
  ///
  /// In en, this message translates to:
  /// **'{minutes}m ago'**
  String minutesAgo(int minutes);

  /// Time ago text for hours
  ///
  /// In en, this message translates to:
  /// **'{hours}h ago'**
  String hoursAgo(int hours);

  /// Time ago text for yesterday
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// Time ago text for days
  ///
  /// In en, this message translates to:
  /// **'{days}d ago'**
  String daysAgo(int days);

  /// Auth card title
  ///
  /// In en, this message translates to:
  /// **'Sign In / Sign Up'**
  String get signInSignUp;

  /// Settings sign-in bottom sheet primary button
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// Settings sign-in bottom sheet Apple button
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get continueWithApple;

  /// Settings sign-in bottom sheet email button
  ///
  /// In en, this message translates to:
  /// **'Continue with Email'**
  String get continueWithEmail;

  /// Auth card subtitle
  ///
  /// In en, this message translates to:
  /// **'Save your edits and sync across devices'**
  String get saveYourEditsAndSyncAcrossDevices;

  /// Success message when user ID is copied
  ///
  /// In en, this message translates to:
  /// **'User ID copied to clipboard'**
  String get userIdCopiedToClipboard;

  /// Delete account button label
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// Delete account confirmation dialog title
  ///
  /// In en, this message translates to:
  /// **'Delete Account?'**
  String get deleteAccountTitle;

  /// Delete account confirmation warning message
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete your account and all associated data, including saved stations, playlists, downloads, and subscriptions. This action cannot be undone.'**
  String get deleteAccountWarning;

  /// Confirm delete account button
  ///
  /// In en, this message translates to:
  /// **'Delete My Account'**
  String get deleteAccountConfirm;

  /// Cancel delete account button
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get deleteAccountCancel;

  /// Success message after account deletion request
  ///
  /// In en, this message translates to:
  /// **'Your account deletion request has been submitted'**
  String get deleteAccountSuccess;

  /// Error message when account deletion fails
  ///
  /// In en, this message translates to:
  /// **'Could not submit account deletion. Please try again.'**
  String get deleteAccountFailed;

  /// Loading message while deleting account
  ///
  /// In en, this message translates to:
  /// **'Submitting deletion request…'**
  String get deleteAccountProcessing;

  /// Success message when user signs out
  ///
  /// In en, this message translates to:
  /// **'Signed out successfully'**
  String get signedOutSuccessfully;

  /// Success message for Google sign in
  ///
  /// In en, this message translates to:
  /// **'Successfully signed in with Google'**
  String get successfullySignedInWithGoogle;

  /// Error message for Google sign in failure
  ///
  /// In en, this message translates to:
  /// **'Google sign-in was cancelled or failed'**
  String get googleSignInCancelledOrFailed;

  /// Error message for Google sign in error
  ///
  /// In en, this message translates to:
  /// **'Error signing in with Google: {error}'**
  String errorSigningInWithGoogle(String error);

  /// Error message when Apple sign in is not available
  ///
  /// In en, this message translates to:
  /// **'Apple Sign-In is only available on iOS and macOS'**
  String get appleSignInOnlyAvailableOnIOS;

  /// Success message for Apple sign in
  ///
  /// In en, this message translates to:
  /// **'Successfully signed in with Apple'**
  String get successfullySignedInWithApple;

  /// Error message for Apple sign in failure
  ///
  /// In en, this message translates to:
  /// **'Apple sign-in was cancelled or failed'**
  String get appleSignInCancelledOrFailed;

  /// Error message for Apple sign in error
  ///
  /// In en, this message translates to:
  /// **'Error signing in with Apple: {error}'**
  String errorSigningInWithApple(String error);

  /// Email auth bottom sheet title
  ///
  /// In en, this message translates to:
  /// **'Email Authentication'**
  String get emailAuthentication;

  /// Email auth bottom sheet subtitle
  ///
  /// In en, this message translates to:
  /// **'Sign in or create a new account'**
  String get signInOrCreateNewAccount;

  /// Sign in tab label
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// Register tab label
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// Email field label
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// Email field hint
  ///
  /// In en, this message translates to:
  /// **'Enter your email'**
  String get enterYourEmail;

  /// Email validation error
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get pleaseEnterYourEmail;

  /// Email format validation error
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email'**
  String get pleaseEnterValidEmail;

  /// Password field label
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// Password field hint
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get enterYourPassword;

  /// Password validation error
  ///
  /// In en, this message translates to:
  /// **'Please enter your password'**
  String get pleaseEnterYourPassword;

  /// Password length validation error
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get passwordMustBeAtLeast6Characters;

  /// Confirm password field label
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// Confirm password field hint
  ///
  /// In en, this message translates to:
  /// **'Enter password again'**
  String get enterPasswordAgain;

  /// Password field hint for registration
  ///
  /// In en, this message translates to:
  /// **'Create a password'**
  String get createAPassword;

  /// Confirm password field hint for registration
  ///
  /// In en, this message translates to:
  /// **'Re-enter your password'**
  String get reEnterYourPassword;

  /// Password validation error for registration
  ///
  /// In en, this message translates to:
  /// **'Please enter a password'**
  String get pleaseEnterAPassword;

  /// Password mismatch validation error
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

  /// Forgot password link text
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// Success message for email sign in
  ///
  /// In en, this message translates to:
  /// **'Successfully signed in'**
  String get successfullySignedIn;

  /// Error message for sign in failure
  ///
  /// In en, this message translates to:
  /// **'Sign in failed. Please check your email and password.'**
  String get signInFailed;

  /// Generic error message
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String error(String error);

  /// Success message for account creation
  ///
  /// In en, this message translates to:
  /// **'Account created successfully! Please check your email for verification.'**
  String get accountCreatedSuccessfully;

  /// Error message for registration failure
  ///
  /// In en, this message translates to:
  /// **'Registration failed. Please try again.'**
  String get registrationFailed;

  /// Email validation error for password reset
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address'**
  String get pleaseEnterValidEmailAddress;

  /// Success message for password reset email
  ///
  /// In en, this message translates to:
  /// **'Password reset email sent! Please check your inbox.'**
  String get passwordResetEmailSent;

  /// Error message for password reset email failure
  ///
  /// In en, this message translates to:
  /// **'Failed to send password reset email. Please try again.'**
  String get failedToSendPasswordResetEmail;

  /// Getting started screen headline
  ///
  /// In en, this message translates to:
  /// **'Live radio & podcasts\nworldwide'**
  String get takeYourPhotosToNewHeights;

  /// Get started button text
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// Terms acceptance text prefix
  ///
  /// In en, this message translates to:
  /// **'By continuing, you accept our '**
  String get byContinuingYouAcceptOur;

  /// Terms of service link text
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// Terms acceptance text middle
  ///
  /// In en, this message translates to:
  /// **' and acknowledge\nreceipt of our '**
  String get andAcknowledgeReceiptOfOur;

  /// Privacy consent screen welcome message
  ///
  /// In en, this message translates to:
  /// **'Welcome to HERO DRAMA!'**
  String get welcomeToAiMusicMaker;

  /// Privacy consent screen title
  ///
  /// In en, this message translates to:
  /// **'Customize your experience'**
  String get customizeYourExperience;

  /// Privacy consent screen main description
  ///
  /// In en, this message translates to:
  /// **'We use tracking technologies that either are essential for the app to function correctly or are used to produce aggregated statistics. With your consent, we and our third-party partners will also use tracking technologies to improve the in-app experience, and to provide you with personalized services and targeted advertising. To give your consent, tap Accept All and Continue.'**
  String get privacyConsentDescription;

  /// Privacy consent screen alternative description
  ///
  /// In en, this message translates to:
  /// **'Alternatively, you can customize your privacy settings by tapping Customize Preferences, or by going to Privacy Settings at any time. If you don\'t want us to use non-technical tracking technologies, tap Refuse.'**
  String get privacyConsentAlternative;

  /// Privacy policy link prefix
  ///
  /// In en, this message translates to:
  /// **'For more information about how we process your personal data through tracking technologies, take a look at our '**
  String get forMoreInformationAboutHowWeProcess;

  /// Accept all button text
  ///
  /// In en, this message translates to:
  /// **'Accept All and Continue'**
  String get acceptAllAndContinue;

  /// Refuse button text
  ///
  /// In en, this message translates to:
  /// **'Refuse'**
  String get refuse;

  /// Customize preferences link text
  ///
  /// In en, this message translates to:
  /// **'Customize Preferences'**
  String get customizePreferences;

  /// Subscription processing message
  ///
  /// In en, this message translates to:
  /// **'Processing subscription...'**
  String get processingSubscription;

  /// Error message when user is not authenticated
  ///
  /// In en, this message translates to:
  /// **'User not authenticated'**
  String get userNotAuthenticated;

  /// Error message when loading chat history fails
  ///
  /// In en, this message translates to:
  /// **'Error loading chat history: {error}'**
  String errorLoadingChatHistory(String error);

  /// Text shown when user is not signed in
  ///
  /// In en, this message translates to:
  /// **'Not signed in'**
  String get notSignedIn;

  /// Default user display name
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get user;

  /// User ID label
  ///
  /// In en, this message translates to:
  /// **'User ID'**
  String get userId;

  /// Sign out button text
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// Tab label for song description input
  ///
  /// In en, this message translates to:
  /// **'Station search'**
  String get songDescription;

  /// Tab label for lyrics input
  ///
  /// In en, this message translates to:
  /// **'Podcasts'**
  String get lyrics;

  /// Tab label for image to song conversion
  ///
  /// In en, this message translates to:
  /// **'By mood'**
  String get imageToSong;

  /// Label for genre selection section
  ///
  /// In en, this message translates to:
  /// **'Select Genre'**
  String get selectGenre;

  /// Label for mood selection section
  ///
  /// In en, this message translates to:
  /// **'Select Mood'**
  String get selectMood;

  /// Happy mood label
  ///
  /// In en, this message translates to:
  /// **'Happy'**
  String get moodHappy;

  /// Sad mood label
  ///
  /// In en, this message translates to:
  /// **'Sad'**
  String get moodSad;

  /// Energetic mood label
  ///
  /// In en, this message translates to:
  /// **'Energetic'**
  String get moodEnergetic;

  /// Romantic mood label
  ///
  /// In en, this message translates to:
  /// **'Romantic'**
  String get moodRomantic;

  /// Chill mood label
  ///
  /// In en, this message translates to:
  /// **'Chill'**
  String get moodChill;

  /// Melancholic mood label
  ///
  /// In en, this message translates to:
  /// **'Melancholic'**
  String get moodMelancholic;

  /// Uplifting mood label
  ///
  /// In en, this message translates to:
  /// **'Uplifting'**
  String get moodUplifting;

  /// Dark mood label
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get moodDark;

  /// Peaceful mood label
  ///
  /// In en, this message translates to:
  /// **'Peaceful'**
  String get moodPeaceful;

  /// Intense mood label
  ///
  /// In en, this message translates to:
  /// **'Intense'**
  String get moodIntense;

  /// Dreamy mood label
  ///
  /// In en, this message translates to:
  /// **'Dreamy'**
  String get moodDreamy;

  /// Nostalgic mood label
  ///
  /// In en, this message translates to:
  /// **'Nostalgic'**
  String get moodNostalgic;

  /// Home tab label
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get tabHome;

  /// Search tab label
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get tabSearch;

  /// Radio tab label
  ///
  /// In en, this message translates to:
  /// **'Radio'**
  String get tabRadio;

  /// Podcasts tab label
  ///
  /// In en, this message translates to:
  /// **'Podcasts'**
  String get tabPodcasts;

  /// Playlist tab label
  ///
  /// In en, this message translates to:
  /// **'Playlist'**
  String get tabPlaylist;

  /// Settings toggle for automatic podcast downloads
  ///
  /// In en, this message translates to:
  /// **'Auto-download new episodes'**
  String get settingsPodcastAutoDownload;

  /// Subtitle for auto-download toggle
  ///
  /// In en, this message translates to:
  /// **'Pro feature — download new episodes on Wi‑Fi'**
  String get settingsPodcastAutoDownloadHint;

  /// Settings toggle for podcast inbox notifications
  ///
  /// In en, this message translates to:
  /// **'New episode alerts'**
  String get settingsPodcastInbox;

  /// Settings row for audio stream quality
  ///
  /// In en, this message translates to:
  /// **'Streaming quality'**
  String get settingsStreamingQuality;

  /// Standard streaming quality label
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get settingsQualityStandard;

  /// High streaming quality label (Pro)
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get settingsQualityHigh;

  /// Settings toggle for default car mode
  ///
  /// In en, this message translates to:
  /// **'Car mode by default'**
  String get settingsCarModeDefault;

  /// Main tab label for Create
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get tabCreate;

  /// Main tab label for Explore
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get tabExplore;

  /// Main tab label for Library
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get tabLibrary;

  /// Android back hint on Create tab before closing the app
  ///
  /// In en, this message translates to:
  /// **'Press back again to exit'**
  String get pressAgainToExit;

  /// Section title above public recent songs on Explore
  ///
  /// In en, this message translates to:
  /// **'New Shows'**
  String get exploreRecentPublicTitle;

  /// Section title for explore category carousel
  ///
  /// In en, this message translates to:
  /// **'Hot Playlists'**
  String get hotPlaylists;

  /// Section title for top creators on Explore
  ///
  /// In en, this message translates to:
  /// **'Top Podcasters'**
  String get topArtists;

  /// Section title for trending songs on Explore
  ///
  /// In en, this message translates to:
  /// **'Top Stations'**
  String get topSongs;

  /// Section title for newest public songs on Explore
  ///
  /// In en, this message translates to:
  /// **'New Episodes'**
  String get newReleases;

  /// Play count label on Explore lists
  ///
  /// In en, this message translates to:
  /// **'{count} plays'**
  String explorePlaysCount(int count);

  /// Placeholder text for song description input
  ///
  /// In en, this message translates to:
  /// **'Search jazz, news, rock, or talk radio...'**
  String get placeholderSongDescription;

  /// Placeholder text for lyrics input
  ///
  /// In en, this message translates to:
  /// **'Search podcasts or episodes...'**
  String get placeholderLyrics;

  /// Placeholder text for image to song input
  ///
  /// In en, this message translates to:
  /// **'Describe the station or show mood...'**
  String get placeholderImageToSong;

  /// Ready to Start screen headline
  ///
  /// In en, this message translates to:
  /// **'Live radio & podcasts worldwide'**
  String get readyToStartHeadline;

  /// Legal disclaimer on Ready to Start screen
  ///
  /// In en, this message translates to:
  /// **'By tapping next, you are agreeing to {appName} Terms of Use & Privacy Policy.'**
  String readyToStartLegalText(String appName);

  /// Section title above default song prompt chips
  ///
  /// In en, this message translates to:
  /// **'Station ideas'**
  String get songIdeasHeading;

  /// Section title above music video prompt chips
  ///
  /// In en, this message translates to:
  /// **'Podcast ideas'**
  String get musicVideoIdeasHeading;

  /// Subtitle chip category for generic song prompts
  ///
  /// In en, this message translates to:
  /// **'All genres / trending stations'**
  String get songIdeasCategoryAllGenres;

  /// Subtitle chip category for music video prompts
  ///
  /// In en, this message translates to:
  /// **'Trending shows'**
  String get songIdeasCategoryTrending;

  /// Section title for community playlist cards
  ///
  /// In en, this message translates to:
  /// **'Community Collections'**
  String get communityCollections;

  /// Subtitle for community playlist section
  ///
  /// In en, this message translates to:
  /// **'Created by our community'**
  String get communityCollectionsDesc;

  /// Section title for trending songs
  ///
  /// In en, this message translates to:
  /// **'Trending'**
  String get trending;

  /// Section title for popular songs column
  ///
  /// In en, this message translates to:
  /// **'Popular This Week'**
  String get popularThisWeek;

  /// Paywall headline first line
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get paywallUnlockLine1;

  /// Paywall headline second line
  ///
  /// In en, this message translates to:
  /// **'VIP Access'**
  String get paywallUnlockLine2;

  /// Paywall main headline with app name
  ///
  /// In en, this message translates to:
  /// **'Watch without limits with {appName}'**
  String paywallHeadline(String appName);

  /// Social proof pill above annual plan on paywall
  ///
  /// In en, this message translates to:
  /// **'Over 80% of viewers choose this plan'**
  String get paywallSocialProof;

  /// Primary paywall CTA button label
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get paywallContinue;

  /// Annual plan per-week price breakdown
  ///
  /// In en, this message translates to:
  /// **'{price} per week'**
  String paywallPerWeek(String price);

  /// Second line under weekly price on plan cards
  ///
  /// In en, this message translates to:
  /// **'per week'**
  String get paywallPerWeekLabel;

  /// No description provided for @paywallFeatureCreateMusic.
  ///
  /// In en, this message translates to:
  /// **'Unlimited episodes'**
  String get paywallFeatureCreateMusic;

  /// No description provided for @paywallFeatureIdeasToSongs.
  ///
  /// In en, this message translates to:
  /// **'Ad-free watching'**
  String get paywallFeatureIdeasToSongs;

  /// No description provided for @paywallFeatureYourLyrics.
  ///
  /// In en, this message translates to:
  /// **'VIP-only dramas'**
  String get paywallFeatureYourLyrics;

  /// No description provided for @paywallFeatureNoAds.
  ///
  /// In en, this message translates to:
  /// **'HD streaming'**
  String get paywallFeatureNoAds;

  /// Chip that opens Pro help dialog on paywall
  ///
  /// In en, this message translates to:
  /// **'Help?'**
  String get paywallWhatAreSongs;

  /// Title for Pro help dialog on paywall
  ///
  /// In en, this message translates to:
  /// **'What\'s in VIP'**
  String get paywallHelpTitle;

  /// No description provided for @paywallHelpFeature1.
  ///
  /// In en, this message translates to:
  /// **'Watch every episode, no coins needed'**
  String get paywallHelpFeature1;

  /// No description provided for @paywallHelpFeature2.
  ///
  /// In en, this message translates to:
  /// **'Exclusive VIP-only series and premieres'**
  String get paywallHelpFeature2;

  /// No description provided for @paywallHelpFeature3.
  ///
  /// In en, this message translates to:
  /// **'Ad-free, HD streaming'**
  String get paywallHelpFeature3;

  /// No description provided for @paywallHelpFeature4.
  ///
  /// In en, this message translates to:
  /// **'Download episodes for offline viewing'**
  String get paywallHelpFeature4;

  /// Dismiss button for Pro help dialog
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get paywallHelpGotIt;

  /// Short bullet explainer for free vs Pro song limits and ads on paywall
  ///
  /// In en, this message translates to:
  /// **'Pro unlocks ad-free listening, offline podcast downloads, premium radio stations, and high-quality streams.'**
  String get paywallSongsExplainerBody;

  /// Dismiss button for What are songs? dialog on paywall
  ///
  /// In en, this message translates to:
  /// **'Thanks 😊'**
  String get paywallSongsExplainerThanks;

  /// No description provided for @paywallPlanYearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get paywallPlanYearly;

  /// No description provided for @paywallPlanMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get paywallPlanMonthly;

  /// No description provided for @paywallPlanWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get paywallPlanWeekly;

  /// No description provided for @paywallBillingYear.
  ///
  /// In en, this message translates to:
  /// **'{price}/Year'**
  String paywallBillingYear(String price);

  /// Annual plan subtitle on left side of plan card
  ///
  /// In en, this message translates to:
  /// **'just {price}/year'**
  String paywallBillingJustYear(String price);

  /// Monthly plan subtitle on left side of plan card
  ///
  /// In en, this message translates to:
  /// **'just {price}/month'**
  String paywallBillingJustMonth(String price);

  /// No description provided for @paywallBillingWeek.
  ///
  /// In en, this message translates to:
  /// **'{price}/Week'**
  String paywallBillingWeek(String price);

  /// No description provided for @paywallSavePercent.
  ///
  /// In en, this message translates to:
  /// **'Save {percent}%'**
  String paywallSavePercent(int percent);

  /// No description provided for @paywallCancelAnytime.
  ///
  /// In en, this message translates to:
  /// **'Cancel Anytime, Auto Renewable'**
  String get paywallCancelAnytime;

  /// No description provided for @paywallSubscribe.
  ///
  /// In en, this message translates to:
  /// **'Subscribe'**
  String get paywallSubscribe;

  /// No description provided for @paywallTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms of Use'**
  String get paywallTerms;

  /// No description provided for @paywallPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get paywallPrivacy;

  /// No description provided for @paywallRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore Purchase'**
  String get paywallRestore;

  /// No description provided for @paywallGotIt.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get paywallGotIt;

  /// No description provided for @paywallNoPackages.
  ///
  /// In en, this message translates to:
  /// **'No subscription packages available.'**
  String get paywallNoPackages;

  /// No description provided for @paywallPurchaseFailed.
  ///
  /// In en, this message translates to:
  /// **'Purchase failed'**
  String get paywallPurchaseFailed;

  /// No description provided for @paywallRestoreSuccess.
  ///
  /// In en, this message translates to:
  /// **'Purchases restored. Pro is active.'**
  String get paywallRestoreSuccess;

  /// No description provided for @paywallRestoreNone.
  ///
  /// In en, this message translates to:
  /// **'No active subscription found to restore.'**
  String get paywallRestoreNone;

  /// No description provided for @paywallRestoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Restore failed'**
  String get paywallRestoreFailed;

  /// No description provided for @paywallClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get paywallClose;

  /// Top-up paywall primary purchase button
  ///
  /// In en, this message translates to:
  /// **'Buy'**
  String get topUpBuy;

  /// No description provided for @paywallRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get paywallRetry;

  /// No description provided for @addCoverTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a station preset'**
  String get addCoverTitle;

  /// No description provided for @addCoverDescription.
  ///
  /// In en, this message translates to:
  /// **'Save a station with a custom name for quick access.'**
  String get addCoverDescription;

  /// No description provided for @addCoverNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Preset name'**
  String get addCoverNameLabel;

  /// No description provided for @addCoverNameHint.
  ///
  /// In en, this message translates to:
  /// **'My morning news'**
  String get addCoverNameHint;

  /// No description provided for @addCoverAudioLabel.
  ///
  /// In en, this message translates to:
  /// **'Station stream'**
  String get addCoverAudioLabel;

  /// No description provided for @addCoverUploadAudio.
  ///
  /// In en, this message translates to:
  /// **'Paste stream URL'**
  String get addCoverUploadAudio;

  /// No description provided for @addCoverImageLabel.
  ///
  /// In en, this message translates to:
  /// **'Station logo (optional)'**
  String get addCoverImageLabel;

  /// No description provided for @addCoverUploadImage.
  ///
  /// In en, this message translates to:
  /// **'Upload logo'**
  String get addCoverUploadImage;

  /// No description provided for @addCoverSave.
  ///
  /// In en, this message translates to:
  /// **'Save preset'**
  String get addCoverSave;

  /// No description provided for @addCoverTermsPrefix.
  ///
  /// In en, this message translates to:
  /// **'I confirm I have rights to use this station stream and agree to the '**
  String get addCoverTermsPrefix;

  /// No description provided for @addCoverTermsLink.
  ///
  /// In en, this message translates to:
  /// **'Terms of Use'**
  String get addCoverTermsLink;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @createYourFirstSong.
  ///
  /// In en, this message translates to:
  /// **'Find Your First Station'**
  String get createYourFirstSong;

  /// No description provided for @noGeneratedSongs.
  ///
  /// In en, this message translates to:
  /// **'Your saved stations will appear here'**
  String get noGeneratedSongs;

  /// No description provided for @tabMySongs.
  ///
  /// In en, this message translates to:
  /// **'My Stations'**
  String get tabMySongs;

  /// No description provided for @tabMyVideos.
  ///
  /// In en, this message translates to:
  /// **'My Episodes'**
  String get tabMyVideos;

  /// No description provided for @tabMyVoices.
  ///
  /// In en, this message translates to:
  /// **'My Presets'**
  String get tabMyVoices;

  /// No description provided for @createYourFirstVideo.
  ///
  /// In en, this message translates to:
  /// **'Subscribe to a Podcast'**
  String get createYourFirstVideo;

  /// No description provided for @noGeneratedVideos.
  ///
  /// In en, this message translates to:
  /// **'Your downloaded episodes will appear here'**
  String get noGeneratedVideos;

  /// No description provided for @createYourOwnVoice.
  ///
  /// In en, this message translates to:
  /// **'Create Your Preset'**
  String get createYourOwnVoice;

  /// No description provided for @noSavedVoices.
  ///
  /// In en, this message translates to:
  /// **'Your saved presets will appear here'**
  String get noSavedVoices;

  /// No description provided for @settingsFaqDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Frequently asked questions'**
  String get settingsFaqDialogTitle;

  /// No description provided for @settingsFaqQ1.
  ///
  /// In en, this message translates to:
  /// **'What\'s included in the Free plan?'**
  String get settingsFaqQ1;

  /// No description provided for @settingsFaqA1.
  ///
  /// In en, this message translates to:
  /// **'The Free plan lets you browse radio stations and podcasts, save favorites, and listen with standard streaming quality. Upgrade to Pro for ad-free listening, offline downloads, and premium stations.'**
  String get settingsFaqA1;

  /// No description provided for @settingsFaqQ2.
  ///
  /// In en, this message translates to:
  /// **'What does Pro include?'**
  String get settingsFaqQ2;

  /// No description provided for @settingsFaqA2.
  ///
  /// In en, this message translates to:
  /// **'Pro unlocks ad-free radio and podcasts, offline episode downloads, premium stations, high-quality streams, and unlimited presets and playlists.'**
  String get settingsFaqA2;

  /// No description provided for @settingsFaqQ3.
  ///
  /// In en, this message translates to:
  /// **'Can I download podcasts for offline listening?'**
  String get settingsFaqQ3;

  /// No description provided for @settingsFaqA3.
  ///
  /// In en, this message translates to:
  /// **'Yes. Pro subscribers can download podcast episodes for offline listening on Wi‑Fi or mobile data, depending on your settings.'**
  String get settingsFaqA3;

  /// No description provided for @settingsFaqQ4.
  ///
  /// In en, this message translates to:
  /// **'Can I listen to live radio worldwide?'**
  String get settingsFaqQ4;

  /// No description provided for @settingsFaqA4.
  ///
  /// In en, this message translates to:
  /// **'Yes. Browse 100,000+ live radio stations by genre, country, and language. Save presets and jump back to your favorites anytime.'**
  String get settingsFaqA4;

  /// No description provided for @settingsFaqQ5.
  ///
  /// In en, this message translates to:
  /// **'What audio quality is available?'**
  String get settingsFaqQ5;

  /// No description provided for @settingsFaqA5.
  ///
  /// In en, this message translates to:
  /// **'Free users get standard streaming quality. Pro includes high-quality streams for supported stations and podcasts.'**
  String get settingsFaqA5;

  /// No description provided for @settingsFaqQ6.
  ///
  /// In en, this message translates to:
  /// **'Can I cancel anytime?'**
  String get settingsFaqQ6;

  /// No description provided for @settingsFaqA6.
  ///
  /// In en, this message translates to:
  /// **'Yes. You can cancel your subscription whenever you want. You\'ll keep Pro access until the end of your current billing period.'**
  String get settingsFaqA6;

  /// No description provided for @settingsFaqQ7.
  ///
  /// In en, this message translates to:
  /// **'Do you offer refunds?'**
  String get settingsFaqQ7;

  /// No description provided for @settingsFaqA7.
  ///
  /// In en, this message translates to:
  /// **'If you run into an issue, contact us and we\'ll help. Refund eligibility can vary depending on usage and billing; we\'ll review requests case-by-case.'**
  String get settingsFaqA7;

  /// No description provided for @settingsFaqQ8.
  ///
  /// In en, this message translates to:
  /// **'Can I switch plans later?'**
  String get settingsFaqQ8;

  /// No description provided for @settingsFaqA8.
  ///
  /// In en, this message translates to:
  /// **'Yes. You can upgrade or downgrade at any time. Changes take effect immediately or at the next billing cycle depending on the plan change.'**
  String get settingsFaqA8;

  /// No description provided for @settingsFaqQ9.
  ///
  /// In en, this message translates to:
  /// **'How do podcast subscriptions work?'**
  String get settingsFaqQ9;

  /// No description provided for @settingsFaqA9.
  ///
  /// In en, this message translates to:
  /// **'Subscribe to any podcast in one tap. New episodes appear in your library, and you can resume playback exactly where you left off.'**
  String get settingsFaqA9;

  /// No description provided for @settingsFaqQ10.
  ///
  /// In en, this message translates to:
  /// **'How do playlists and presets work?'**
  String get settingsFaqQ10;

  /// No description provided for @settingsFaqA10.
  ///
  /// In en, this message translates to:
  /// **'Save radio stations as presets, build playlists, and keep your listening history synced across sessions so you can continue where you stopped.'**
  String get settingsFaqA10;

  /// No description provided for @settingsFaqQ11.
  ///
  /// In en, this message translates to:
  /// **'Which content is Pro-only?'**
  String get settingsFaqQ11;

  /// No description provided for @settingsFaqA11.
  ///
  /// In en, this message translates to:
  /// **'Some premium stations, offline downloads, ad-free listening, and high-quality streams require Pro. Free users can still explore most radio and podcast content.'**
  String get settingsFaqA11;

  /// Title for Pro song credits help dialog
  ///
  /// In en, this message translates to:
  /// **'How Pro listening works'**
  String get proBudgetHelpTitle;

  /// Pro budget help dialog bullet 1
  ///
  /// In en, this message translates to:
  /// **'Pro removes ads from radio and podcast playback and unlocks premium listening features.'**
  String get proBudgetHelpBullet1;

  /// Pro budget help dialog bullet 2
  ///
  /// In en, this message translates to:
  /// **'Your saved stations, presets, and playlists stay synced while you listen across the app.'**
  String get proBudgetHelpBullet2;

  /// Pro budget help dialog bullet 3
  ///
  /// In en, this message translates to:
  /// **'Offline downloads let you save podcast episodes and listen without a connection.'**
  String get proBudgetHelpBullet3;

  /// Pro budget help dialog bullet 4
  ///
  /// In en, this message translates to:
  /// **'Tap the Pro badge anytime to view plans or restore your subscription.'**
  String get proBudgetHelpBullet4;

  /// Dismiss Pro budget help dialog
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get proBudgetHelpGotIt;

  /// Small help chip next to Pro badge
  ///
  /// In en, this message translates to:
  /// **'Help?'**
  String get headerHelpChip;

  /// Splash screen tagline under app name
  ///
  /// In en, this message translates to:
  /// **'Short dramas you cannot stop watching'**
  String get splashTagline;

  /// No description provided for @splashInitErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Initialization Error'**
  String get splashInitErrorTitle;

  /// No description provided for @splashInitErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed to initialize the app. Please check your permissions and try again.'**
  String get splashInitErrorMessage;

  /// Main bottom nav tab for AI cover voices
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get tabAiCovers;

  /// Create tab label for music video mode
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get tabMusicVideo;

  /// Prompt placeholder on music video create tab
  ///
  /// In en, this message translates to:
  /// **'Search podcasts to download...'**
  String get placeholderMusicVideo;

  /// No description provided for @aiCoversPill.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get aiCoversPill;

  /// No description provided for @aiCoversPillCount.
  ///
  /// In en, this message translates to:
  /// **'+{count} premium'**
  String aiCoversPillCount(int count);

  /// No description provided for @aiCoverVoicesSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Premium Stations'**
  String get aiCoverVoicesSheetTitle;

  /// No description provided for @searchVoicesHint.
  ///
  /// In en, this message translates to:
  /// **'Search presets…'**
  String get searchVoicesHint;

  /// No description provided for @yourVoices.
  ///
  /// In en, this message translates to:
  /// **'Your presets'**
  String get yourVoices;

  /// No description provided for @noVoicesYet.
  ///
  /// In en, this message translates to:
  /// **'No presets yet'**
  String get noVoicesYet;

  /// No description provided for @categoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get categoryOther;

  /// No description provided for @aiCoversClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get aiCoversClear;

  /// No description provided for @selectMusicModel.
  ///
  /// In en, this message translates to:
  /// **'Stream quality'**
  String get selectMusicModel;

  /// No description provided for @signInToAddCoverVoice.
  ///
  /// In en, this message translates to:
  /// **'Please sign in to save a preset'**
  String get signInToAddCoverVoice;

  /// No description provided for @musicVideoPromoTitle.
  ///
  /// In en, this message translates to:
  /// **'Offline listening'**
  String get musicVideoPromoTitle;

  /// No description provided for @musicVideoPromoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Download episodes\nfor offline play'**
  String get musicVideoPromoSubtitle;

  /// No description provided for @musicVideoPromoCreate.
  ///
  /// In en, this message translates to:
  /// **'Browse'**
  String get musicVideoPromoCreate;

  /// No description provided for @musicGeneratedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Now playing!'**
  String get musicGeneratedSuccess;

  /// No description provided for @musicVideoGeneratedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Download started!'**
  String get musicVideoGeneratedSuccess;

  /// No description provided for @describeMusicVideoConcept.
  ///
  /// In en, this message translates to:
  /// **'Choose a podcast episode to download'**
  String get describeMusicVideoConcept;

  /// No description provided for @noVideoCreditsRemaining.
  ///
  /// In en, this message translates to:
  /// **'No download credits remaining. Upgrade to Pro to continue.'**
  String get noVideoCreditsRemaining;

  /// No description provided for @musicVideoGeneratingHeadline.
  ///
  /// In en, this message translates to:
  /// **'Preparing your download...'**
  String get musicVideoGeneratingHeadline;

  /// No description provided for @musicVideoReadyHeadline.
  ///
  /// In en, this message translates to:
  /// **'Episode ready offline!'**
  String get musicVideoReadyHeadline;

  /// No description provided for @musicVideoReadyToast.
  ///
  /// In en, this message translates to:
  /// **'Episode downloaded! Open your library to listen offline.'**
  String get musicVideoReadyToast;

  /// No description provided for @musicVideoGenerateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to download episode: {error}'**
  String musicVideoGenerateFailed(String error);

  /// No description provided for @musicReadyToast.
  ///
  /// In en, this message translates to:
  /// **'Station ready! Tap play to listen live.'**
  String get musicReadyToast;

  /// No description provided for @notAuthenticated.
  ///
  /// In en, this message translates to:
  /// **'Not authenticated'**
  String get notAuthenticated;

  /// No description provided for @songDeleted.
  ///
  /// In en, this message translates to:
  /// **'Removed from library'**
  String get songDeleted;

  /// No description provided for @errorDeletingSong.
  ///
  /// In en, this message translates to:
  /// **'Error removing item: {error}'**
  String errorDeletingSong(String error);

  /// No description provided for @noPreviewForVoice.
  ///
  /// In en, this message translates to:
  /// **'No preview available for this preset'**
  String get noPreviewForVoice;

  /// No description provided for @maleVoice.
  ///
  /// In en, this message translates to:
  /// **'Talk radio'**
  String get maleVoice;

  /// No description provided for @femaleVoice.
  ///
  /// In en, this message translates to:
  /// **'Music station'**
  String get femaleVoice;

  /// No description provided for @aiCoverVoiceLabel.
  ///
  /// In en, this message translates to:
  /// **'Station preset'**
  String get aiCoverVoiceLabel;

  /// No description provided for @genderMale.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get genderMale;

  /// No description provided for @genderFemale.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get genderFemale;

  /// No description provided for @videoStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get videoStatusCompleted;

  /// No description provided for @videoStatusGenerating.
  ///
  /// In en, this message translates to:
  /// **'Downloading'**
  String get videoStatusGenerating;

  /// No description provided for @videoStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get videoStatusFailed;

  /// No description provided for @recordVoiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Name Preset'**
  String get recordVoiceTitle;

  /// No description provided for @recordVoiceRerecord.
  ///
  /// In en, this message translates to:
  /// **'Re-record'**
  String get recordVoiceRerecord;

  /// No description provided for @recordVoiceUseThis.
  ///
  /// In en, this message translates to:
  /// **'Use This'**
  String get recordVoiceUseThis;

  /// No description provided for @recordVoiceMicRequired.
  ///
  /// In en, this message translates to:
  /// **'Microphone access required'**
  String get recordVoiceMicRequired;

  /// No description provided for @recordVoiceMicSettingsHint.
  ///
  /// In en, this message translates to:
  /// **'Please enable microphone access\nin your device settings.'**
  String get recordVoiceMicSettingsHint;

  /// No description provided for @recordVoiceOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get recordVoiceOpenSettings;

  /// No description provided for @recordVoiceRecording.
  ///
  /// In en, this message translates to:
  /// **'Recording...'**
  String get recordVoiceRecording;

  /// No description provided for @recordVoiceComplete.
  ///
  /// In en, this message translates to:
  /// **'Recording complete'**
  String get recordVoiceComplete;

  /// No description provided for @recordVoiceTapToStart.
  ///
  /// In en, this message translates to:
  /// **'Tap to name your preset'**
  String get recordVoiceTapToStart;

  /// No description provided for @recordVoicePlaying.
  ///
  /// In en, this message translates to:
  /// **'Playing...'**
  String get recordVoicePlaying;

  /// No description provided for @recordVoiceTapPreview.
  ///
  /// In en, this message translates to:
  /// **'Tap to preview'**
  String get recordVoiceTapPreview;

  /// No description provided for @recordVoiceTip1.
  ///
  /// In en, this message translates to:
  /// **'Speak clearly when naming'**
  String get recordVoiceTip1;

  /// No description provided for @recordVoiceTip2.
  ///
  /// In en, this message translates to:
  /// **'Keep it short and memorable'**
  String get recordVoiceTip2;

  /// No description provided for @recordVoiceTip3.
  ///
  /// In en, this message translates to:
  /// **'Use a quiet environment'**
  String get recordVoiceTip3;

  /// No description provided for @uploadFile.
  ///
  /// In en, this message translates to:
  /// **'Upload File'**
  String get uploadFile;

  /// No description provided for @recordVoiceButton.
  ///
  /// In en, this message translates to:
  /// **'Record Name'**
  String get recordVoiceButton;

  /// No description provided for @coverVoiceAdded.
  ///
  /// In en, this message translates to:
  /// **'Preset saved'**
  String get coverVoiceAdded;

  /// No description provided for @audioFileMaxSize.
  ///
  /// In en, this message translates to:
  /// **'Audio file must be less than {size}MB'**
  String audioFileMaxSize(int size);

  /// No description provided for @imageFileMaxSize.
  ///
  /// In en, this message translates to:
  /// **'Image file must be less than {size}MB'**
  String imageFileMaxSize(int size);

  /// Label on dashed card to create a custom AI cover voice (sheet and AI Covers tab)
  ///
  /// In en, this message translates to:
  /// **'Add your\nown preset'**
  String get addYourOwnVoice;

  /// Title on the AI Cover tab page
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get aiCoverPageTitle;

  /// No description provided for @aiCoverPickSongSection.
  ///
  /// In en, this message translates to:
  /// **'1. Pick a station'**
  String get aiCoverPickSongSection;

  /// No description provided for @aiCoverChooseSongHint.
  ///
  /// In en, this message translates to:
  /// **'Choose a station to save.'**
  String get aiCoverChooseSongHint;

  /// No description provided for @aiCoverChooseVoiceSection.
  ///
  /// In en, this message translates to:
  /// **'2. Choose a preset'**
  String get aiCoverChooseVoiceSection;

  /// No description provided for @aiCoverSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get aiCoverSearchHint;

  /// No description provided for @aiCoverFilterHot.
  ///
  /// In en, this message translates to:
  /// **'Hot 🔥'**
  String get aiCoverFilterHot;

  /// No description provided for @aiCoverFilterMyVoices.
  ///
  /// In en, this message translates to:
  /// **'My Presets'**
  String get aiCoverFilterMyVoices;

  /// No description provided for @aiCoverFilterNew.
  ///
  /// In en, this message translates to:
  /// **'New ✨'**
  String get aiCoverFilterNew;

  /// No description provided for @aiCoverFilterSimilar.
  ///
  /// In en, this message translates to:
  /// **'Similar'**
  String get aiCoverFilterSimilar;

  /// No description provided for @aiCoverCreateVoice.
  ///
  /// In en, this message translates to:
  /// **'Create Preset'**
  String get aiCoverCreateVoice;

  /// No description provided for @aiCoverCreateButton.
  ///
  /// In en, this message translates to:
  /// **'Save station'**
  String get aiCoverCreateButton;

  /// No description provided for @aiCoverSelectSong.
  ///
  /// In en, this message translates to:
  /// **'Please choose a station'**
  String get aiCoverSelectSong;

  /// No description provided for @aiCoverSelectVoice.
  ///
  /// In en, this message translates to:
  /// **'Please choose a preset'**
  String get aiCoverSelectVoice;

  /// No description provided for @aiCoverPickFromLibrary.
  ///
  /// In en, this message translates to:
  /// **'From my library'**
  String get aiCoverPickFromLibrary;

  /// No description provided for @aiCoverUploadAudio.
  ///
  /// In en, this message translates to:
  /// **'Upload audio file'**
  String get aiCoverUploadAudio;

  /// No description provided for @aiCoverPickSongTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a station'**
  String get aiCoverPickSongTitle;

  /// No description provided for @aiCoverGenderFilter.
  ///
  /// In en, this message translates to:
  /// **'Genre filter'**
  String get aiCoverGenderFilter;

  /// No description provided for @aiCoverGenderAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get aiCoverGenderAll;

  /// No description provided for @recordedAudio.
  ///
  /// In en, this message translates to:
  /// **'Recorded audio'**
  String get recordedAudio;

  /// No description provided for @maxFileSizeHint.
  ///
  /// In en, this message translates to:
  /// **'Max {size}MB'**
  String maxFileSizeHint(int size);

  /// Settings row to open App Store / Play subscription management
  ///
  /// In en, this message translates to:
  /// **'Manage Subscriptions'**
  String get manageSubscriptions;

  /// Toast after successful restore from settings
  ///
  /// In en, this message translates to:
  /// **'Purchases restored successfully'**
  String get settingsPurchasesRestoredSuccess;

  /// Toast when restore purchases fails from settings
  ///
  /// In en, this message translates to:
  /// **'Error restoring purchases: {error}'**
  String settingsRestorePurchasesError(String error);

  /// Error when subscription management URL fails to open
  ///
  /// In en, this message translates to:
  /// **'Could not open subscription page. Please visit your device\'s app store settings.'**
  String get couldNotOpenSubscriptionPage;

  /// Generic error when a settings URL fails to open
  ///
  /// In en, this message translates to:
  /// **'Could not open link'**
  String get couldNotOpenLink;

  /// Unified top-up paywall sheet title
  ///
  /// In en, this message translates to:
  /// **'Top-ups'**
  String get topUpSheetTitle;

  /// Pro user unified credit balance on top-up sheet
  ///
  /// In en, this message translates to:
  /// **'Balance: {count} listening credits'**
  String topUpBalanceHint(int count);

  /// Per-credit price line on checkout bar
  ///
  /// In en, this message translates to:
  /// **'{price} / credit'**
  String topUpPerCredit(String price);

  /// No description provided for @topUpTierSmall.
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get topUpTierSmall;

  /// No description provided for @topUpTierMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get topUpTierMedium;

  /// No description provided for @topUpTierLarge.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get topUpTierLarge;

  /// No description provided for @topUpRecommended.
  ///
  /// In en, this message translates to:
  /// **'RECOMMENDED'**
  String get topUpRecommended;

  /// No description provided for @topUpBestValue.
  ///
  /// In en, this message translates to:
  /// **'BEST VALUE'**
  String get topUpBestValue;

  /// No description provided for @topUpCreditsLabel.
  ///
  /// In en, this message translates to:
  /// **'credits'**
  String get topUpCreditsLabel;

  /// No description provided for @topUpExtraCredits.
  ///
  /// In en, this message translates to:
  /// **'{count} credits'**
  String topUpExtraCredits(int count);

  /// No description provided for @topUpSelectPack.
  ///
  /// In en, this message translates to:
  /// **'Select a pack'**
  String get topUpSelectPack;

  /// No description provided for @topUpNoPacksInSize.
  ///
  /// In en, this message translates to:
  /// **'No packs in this size'**
  String get topUpNoPacksInSize;

  /// No description provided for @topUpProductsNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Top-up products are not configured. Add topup_product_ids in Remote Config.'**
  String get topUpProductsNotConfigured;

  /// No description provided for @topUpProductsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load top-up products. Check RevenueCat + store IDs match Remote Config.'**
  String get topUpProductsLoadFailed;

  /// No description provided for @topUpPurchaseSetupFailed.
  ///
  /// In en, this message translates to:
  /// **'Purchase setup failed. Please try again.'**
  String get topUpPurchaseSetupFailed;

  /// No description provided for @topUpPurchaseSuccess.
  ///
  /// In en, this message translates to:
  /// **'Top-up added! You now have {count} credits.'**
  String topUpPurchaseSuccess(int count);

  /// No description provided for @topUpPurchaseFailed.
  ///
  /// In en, this message translates to:
  /// **'Purchase failed: {error}'**
  String topUpPurchaseFailed(String error);

  /// No description provided for @topUpSignInRequired.
  ///
  /// In en, this message translates to:
  /// **'Please sign in to purchase top-ups.'**
  String get topUpSignInRequired;

  /// Toast when long-pressing Pro badge; daily and top-up counts
  ///
  /// In en, this message translates to:
  /// **'You still have {dailyLeft, plural, one{1 free listen} other{{dailyLeft} free listens}} left today, and {topUpLeft, plural, one{1 bonus listen} other{{topUpLeft} bonus listens}} ready when you need them.'**
  String proBudgetLongPressToast(int dailyLeft, int topUpLeft);

  /// Title for mandatory app update dialog
  ///
  /// In en, this message translates to:
  /// **'Update Required'**
  String get forceUpdateTitle;

  /// Message for mandatory app update dialog
  ///
  /// In en, this message translates to:
  /// **'A new version of the app is available. Please update to continue using the app.'**
  String get forceUpdateMessage;

  /// Title for optional app update dialog
  ///
  /// In en, this message translates to:
  /// **'Update Available'**
  String get optionalUpdateTitle;

  /// Message for optional app update dialog
  ///
  /// In en, this message translates to:
  /// **'A new version is available with improvements and bug fixes. Would you like to update?'**
  String get optionalUpdateMessage;

  /// Button to open the app store for an update
  ///
  /// In en, this message translates to:
  /// **'Update Now'**
  String get updateNow;

  /// Dismiss optional update dialog
  ///
  /// In en, this message translates to:
  /// **'Maybe Later'**
  String get maybeLater;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
        'ar',
        'de',
        'en',
        'es',
        'fr',
        'it',
        'ja',
        'ko',
        'pt',
        'ru',
        'tr',
        'zh'
      ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'it':
      return AppLocalizationsIt();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'pt':
      return AppLocalizationsPt();
    case 'ru':
      return AppLocalizationsRu();
    case 'tr':
      return AppLocalizationsTr();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
