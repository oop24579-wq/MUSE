// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'HERO DRAMA';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String languageChanged(String languageName) {
    return 'Language changed to $languageName';
  }

  @override
  String failedToChangeLanguage(String error) {
    return 'Failed to change language: $error';
  }

  @override
  String get selectFromGallery => 'Select from gallery';

  @override
  String get uploadAndEdit => 'Upload and Edit';

  @override
  String get pleaseSelectImageFirst => 'Please select an image first';

  @override
  String get featured => 'Featured Stations';

  @override
  String get pro => 'Pro';

  @override
  String get darkMode => 'Dark mode';

  @override
  String get lightMode => 'Light mode';

  @override
  String get rewardDailyCheckIn => 'Daily Check-in';

  @override
  String rewardDailyCheckInToday(int amount) {
    return '✦ $amount today';
  }

  @override
  String rewardDailyCheckInTomorrowHint(int amount) {
    return 'Check in tomorrow for ✦ $amount';
  }

  @override
  String get rewardClaimed => 'Claimed';

  @override
  String get rewardClaim => 'Claim';

  @override
  String get rewardShare => 'Share';

  @override
  String rewardCreditsEarned(int count) {
    return '+$count perk';
  }

  @override
  String rewardCreditsEarnedPlural(int count) {
    return '+$count perks';
  }

  @override
  String get rewardAlreadyClaimedToday => 'Already claimed today';

  @override
  String get rewardLimitReached => 'Limit reached for today';

  @override
  String get rewardActionFailed => 'Could not complete reward. Try again.';

  @override
  String get rewardDailyShareCreation => 'Daily Share Creation';

  @override
  String rewardPerShareSuffix(int maxShares) {
    return ' / share, max $maxShares';
  }

  @override
  String rewardShareEarnedFooter(int maxPerDay, int earnedSoFar) {
    return 'You can earn up to ✦ $maxPerDay per day from sharing; you\'ve earned ✦ $earnedSoFar so far.';
  }

  @override
  String get rewardView => 'View';

  @override
  String get rewardInviteNewFriend => 'Invite New Friend';

  @override
  String get rewardPerFriendSuffix => ' / friend';

  @override
  String rewardInviteFriendsFooter(int maxFriends, int invitedCount) {
    return 'You can invite up to $maxFriends friends to earn Pro perks and have invited $invitedCount so far.';
  }

  @override
  String get rewardInvite => 'Invite';

  @override
  String settingsProfileFriendsPlaceholder(int count) {
    return '$count friends';
  }

  @override
  String get settingsProfileUpgradeSubtitle =>
      'Episódios ilimitados, sem anúncios e séries exclusivas';

  @override
  String get settingsProfileProSubtitle =>
      'Unlimited radio & podcasts unlocked';

  @override
  String get settingsProfileUpgrade => 'Upgrade';

  @override
  String get settingsPromoBannerTitle => 'Go Pro';

  @override
  String get settingsProBannerTitle => 'VIP Member';

  @override
  String get settingsContactUs => 'Contact us';

  @override
  String get settingsProfileSignIn => 'Sign in';

  @override
  String get settingsProfileInvite => 'Invite';

  @override
  String get weeklyStreakSectionTitle => 'Weekly streak';

  @override
  String get weeklyStreakClaimGift => 'Claim';

  @override
  String get weeklyStreakClaimed => 'Claimed';

  @override
  String get weeklyStreakDayMon => 'Mon';

  @override
  String get weeklyStreakDayTue => 'Tue';

  @override
  String get weeklyStreakDayWed => 'Wed';

  @override
  String get weeklyStreakDayThu => 'Thu';

  @override
  String get weeklyStreakDayFri => 'Fri';

  @override
  String get weeklyStreakDaySat => 'Sat';

  @override
  String get weeklyStreakDaySun => 'Sun';

  @override
  String get weeklyStreakModalTitle => 'Weekly gift';

  @override
  String get weeklyStreakModalBody => 'You visited every day this week!';

  @override
  String weeklyStreakModalReward(int count) {
    return '+$count free perks';
  }

  @override
  String get weeklyStreakModalFootnote => 'Added to your Pro perk balance.';

  @override
  String get weeklyStreakCollect => 'Collect perks';

  @override
  String get weeklyStreakCollecting => 'Collecting…';

  @override
  String weeklyStreakSuccess(int count) {
    return '$count free perks added!';
  }

  @override
  String get weeklyStreakClaimFailed =>
      'Could not claim reward. Try again later.';

  @override
  String get weeklyStreakUnavailable => 'Weekly reward unavailable.';

  @override
  String get reminder => 'Reminder';

  @override
  String get notifications => 'Notifications';

  @override
  String get notificationsEnabled => 'Notifications enabled';

  @override
  String get notificationsDisabled =>
      'Notifications are disabled. You can enable them in your device settings.';

  @override
  String get notificationsDisabledShort => 'Disabled';

  @override
  String get notificationSettingsDescription =>
      'Manage your push notification preferences';

  @override
  String get pushNotifications => 'Push Notifications';

  @override
  String get redeemCode => 'Redeem Code';

  @override
  String get rateUs => 'Rate Us';

  @override
  String get support => 'Support';

  @override
  String get restorePurchase => 'Restore Purchase';

  @override
  String get chatHistory => 'Chat History';

  @override
  String get termsOfUse => 'Terms of Use';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get followUsOnInstagram => 'Follow us on Instagram';

  @override
  String get followUsOnFacebook => 'Follow us on Facebook';

  @override
  String get followUsOnX => 'Follow us on X';

  @override
  String get followUsOnTiktok => 'Follow us on TikTok';

  @override
  String get initializingServices => 'Initializing services...';

  @override
  String get loadingConfiguration => 'Loading configuration...';

  @override
  String get ready => 'Ready!';

  @override
  String get retry => 'Retry';

  @override
  String get selectPhoto => 'Select Photo';

  @override
  String get takeAPicture => 'Take a picture';

  @override
  String get recentlyUsed => 'Recently Used';

  @override
  String get uploadFromGallery => 'Upload from Gallery';

  @override
  String get continueButton => 'Continue';

  @override
  String get describeWhatYouWant => 'Describe what you want';

  @override
  String get inputPromptHintExample =>
      'e.g., \"Make it brighter\" or \"Remove the background\"';

  @override
  String get writeYourPromptToEditThisImage =>
      'Write your prompt to edit this image';

  @override
  String get uploadedImage => 'Uploaded Image';

  @override
  String errorLoadingChat(String error) {
    return 'Error loading chat: $error';
  }

  @override
  String get chatDeleted => 'Chat deleted';

  @override
  String errorDeletingChat(String error) {
    return 'Error deleting chat: $error';
  }

  @override
  String get noChatHistory => 'No chat history';

  @override
  String get yourChatConversationsWillAppearHere =>
      'Your chat conversations will appear here';

  @override
  String messages(num count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString messages',
      one: '1 message',
      zero: 'no messages',
    );
    return '$_temp0';
  }

  @override
  String get justNow => 'Just now';

  @override
  String minutesAgo(int minutes) {
    return '${minutes}m ago';
  }

  @override
  String hoursAgo(int hours) {
    return '${hours}h ago';
  }

  @override
  String get yesterday => 'Yesterday';

  @override
  String daysAgo(int days) {
    return '${days}d ago';
  }

  @override
  String get signInSignUp => 'Sign In / Sign Up';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get continueWithApple => 'Continue with Apple';

  @override
  String get continueWithEmail => 'Continue with Email';

  @override
  String get saveYourEditsAndSyncAcrossDevices =>
      'Save your edits and sync across devices';

  @override
  String get userIdCopiedToClipboard => 'User ID copied to clipboard';

  @override
  String get deleteAccount => 'Delete Account';

  @override
  String get deleteAccountTitle => 'Delete Account?';

  @override
  String get deleteAccountWarning =>
      'This will permanently delete your account and all associated data, including saved stations, playlists, downloads, and subscriptions. This action cannot be undone.';

  @override
  String get deleteAccountConfirm => 'Delete My Account';

  @override
  String get deleteAccountCancel => 'Cancel';

  @override
  String get deleteAccountSuccess =>
      'Your account deletion request has been submitted';

  @override
  String get deleteAccountFailed =>
      'Could not submit account deletion. Please try again.';

  @override
  String get deleteAccountProcessing => 'Submitting deletion request…';

  @override
  String get signedOutSuccessfully => 'Signed out successfully';

  @override
  String get successfullySignedInWithGoogle =>
      'Successfully signed in with Google';

  @override
  String get googleSignInCancelledOrFailed =>
      'Google sign-in was cancelled or failed';

  @override
  String errorSigningInWithGoogle(String error) {
    return 'Error signing in with Google: $error';
  }

  @override
  String get appleSignInOnlyAvailableOnIOS =>
      'Apple Sign-In is only available on iOS and macOS';

  @override
  String get successfullySignedInWithApple =>
      'Successfully signed in with Apple';

  @override
  String get appleSignInCancelledOrFailed =>
      'Apple sign-in was cancelled or failed';

  @override
  String errorSigningInWithApple(String error) {
    return 'Error signing in with Apple: $error';
  }

  @override
  String get emailAuthentication => 'Email Authentication';

  @override
  String get signInOrCreateNewAccount => 'Sign in or create a new account';

  @override
  String get signIn => 'Sign In';

  @override
  String get register => 'Register';

  @override
  String get email => 'Email';

  @override
  String get enterYourEmail => 'Enter your email';

  @override
  String get pleaseEnterYourEmail => 'Please enter your email';

  @override
  String get pleaseEnterValidEmail => 'Please enter a valid email';

  @override
  String get password => 'Password';

  @override
  String get enterYourPassword => 'Enter your password';

  @override
  String get pleaseEnterYourPassword => 'Please enter your password';

  @override
  String get passwordMustBeAtLeast6Characters =>
      'Password must be at least 6 characters';

  @override
  String get confirmPassword => 'Confirm Password';

  @override
  String get enterPasswordAgain => 'Enter password again';

  @override
  String get createAPassword => 'Create a password';

  @override
  String get reEnterYourPassword => 'Re-enter your password';

  @override
  String get pleaseEnterAPassword => 'Please enter a password';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get forgotPassword => 'Forgot Password?';

  @override
  String get successfullySignedIn => 'Successfully signed in';

  @override
  String get signInFailed =>
      'Sign in failed. Please check your email and password.';

  @override
  String error(String error) {
    return 'Error: $error';
  }

  @override
  String get accountCreatedSuccessfully =>
      'Account created successfully! Please check your email for verification.';

  @override
  String get registrationFailed => 'Registration failed. Please try again.';

  @override
  String get pleaseEnterValidEmailAddress =>
      'Please enter a valid email address';

  @override
  String get passwordResetEmailSent =>
      'Password reset email sent! Please check your inbox.';

  @override
  String get failedToSendPasswordResetEmail =>
      'Failed to send password reset email. Please try again.';

  @override
  String get getStarted => 'Get Started';

  @override
  String get byContinuingYouAcceptOur => 'By continuing, you accept our ';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get andAcknowledgeReceiptOfOur => ' and acknowledge\nreceipt of our ';

  @override
  String get welcomeToAiMusicMaker => 'Welcome to HERO DRAMA!';

  @override
  String get customizeYourExperience => 'Customize your experience';

  @override
  String get privacyConsentDescription =>
      'We use tracking technologies that either are essential for the app to function correctly or are used to produce aggregated statistics. With your consent, we and our third-party partners will also use tracking technologies to improve the in-app experience, and to provide you with personalized services and targeted advertising. To give your consent, tap Accept All and Continue.';

  @override
  String get privacyConsentAlternative =>
      'Alternatively, you can customize your privacy settings by tapping Customize Preferences, or by going to Privacy Settings at any time. If you don\'t want us to use non-technical tracking technologies, tap Refuse.';

  @override
  String get forMoreInformationAboutHowWeProcess =>
      'For more information about how we process your personal data through tracking technologies, take a look at our ';

  @override
  String get acceptAllAndContinue => 'Accept All and Continue';

  @override
  String get refuse => 'Refuse';

  @override
  String get customizePreferences => 'Customize Preferences';

  @override
  String get processingSubscription => 'Processing subscription...';

  @override
  String get userNotAuthenticated => 'User not authenticated';

  @override
  String errorLoadingChatHistory(String error) {
    return 'Error loading chat history: $error';
  }

  @override
  String get notSignedIn => 'Not signed in';

  @override
  String get user => 'User';

  @override
  String get userId => 'User ID';

  @override
  String get signOut => 'Sign Out';

  @override
  String get selectGenre => 'Select Genre';

  @override
  String get selectMood => 'Select Mood';

  @override
  String get moodHappy => 'Happy';

  @override
  String get moodSad => 'Sad';

  @override
  String get moodEnergetic => 'Energetic';

  @override
  String get moodRomantic => 'Romantic';

  @override
  String get moodChill => 'Chill';

  @override
  String get moodMelancholic => 'Melancholic';

  @override
  String get moodUplifting => 'Uplifting';

  @override
  String get moodDark => 'Dark';

  @override
  String get moodPeaceful => 'Peaceful';

  @override
  String get moodIntense => 'Intense';

  @override
  String get moodDreamy => 'Dreamy';

  @override
  String get moodNostalgic => 'Nostalgic';

  @override
  String get tabHome => 'Home';

  @override
  String get tabSearch => 'Search';

  @override
  String get tabPlaylist => 'Playlist';

  @override
  String get settingsStreamingQuality => 'Streaming quality';

  @override
  String get settingsQualityStandard => 'Standard';

  @override
  String get settingsQualityHigh => 'High';

  @override
  String get settingsCarModeDefault => 'Car mode by default';

  @override
  String get tabCreate => 'Create';

  @override
  String get tabExplore => 'Explore';

  @override
  String get tabLibrary => 'Library';

  @override
  String get pressAgainToExit => 'Press back again to exit';

  @override
  String get exploreRecentPublicTitle => 'New Shows';

  @override
  String get hotPlaylists => 'Hot Playlists';

  @override
  String get topArtists => 'Top Podcasters';

  @override
  String get newReleases => 'New Episodes';

  @override
  String explorePlaysCount(int count) {
    return '$count plays';
  }

  @override
  String get readyToStartHeadline => 'Live radio & podcasts worldwide';

  @override
  String readyToStartLegalText(String appName) {
    return 'By tapping next, you are agreeing to $appName Terms of Use & Privacy Policy.';
  }

  @override
  String get communityCollections => 'Community Collections';

  @override
  String get communityCollectionsDesc => 'Created by our community';

  @override
  String get trending => 'Trending';

  @override
  String get popularThisWeek => 'Popular This Week';

  @override
  String get paywallUnlockLine1 => 'Unlock Premium';

  @override
  String get paywallUnlockLine2 => 'Listening';

  @override
  String paywallHeadline(String appName) {
    return 'Watch without limits with $appName';
  }

  @override
  String get paywallSocialProof => 'Over 80% of viewers choose this plan';

  @override
  String get paywallContinue => 'Continue';

  @override
  String paywallPerWeek(String price) {
    return '$price per week';
  }

  @override
  String get paywallPerWeekLabel => 'per week';

  @override
  String get paywallFeatureCreateMusic => 'Ad-free listening';

  @override
  String get paywallFeatureIdeasToSongs => 'Offline podcast downloads';

  @override
  String get paywallFeatureYourLyrics => 'Premium radio stations';

  @override
  String get paywallFeatureNoAds => 'High-quality streams';

  @override
  String get paywallWhatAreSongs => 'Help?';

  @override
  String get paywallHelpTitle => 'What\'s in VIP';

  @override
  String get paywallHelpFeature1 => 'Watch every episode, no coins needed';

  @override
  String get paywallHelpFeature2 => 'Exclusive VIP-only series and premieres';

  @override
  String get paywallHelpFeature3 => 'Ad-free, HD streaming';

  @override
  String get paywallHelpFeature4 => 'Ad-free streaming in HD quality';

  @override
  String get paywallHelpGotIt => 'Got it';

  @override
  String get paywallPlanYearly => 'Yearly';

  @override
  String get paywallPlanMonthly => 'Monthly';

  @override
  String get paywallPlanWeekly => 'Weekly';

  @override
  String paywallBillingYear(String price) {
    return '$price/Year';
  }

  @override
  String paywallBillingJustYear(String price) {
    return 'just $price/year';
  }

  @override
  String paywallBillingJustMonth(String price) {
    return 'just $price/month';
  }

  @override
  String paywallBillingWeek(String price) {
    return '$price/Week';
  }

  @override
  String paywallSavePercent(int percent) {
    return 'Save $percent%';
  }

  @override
  String get paywallCancelAnytime => 'Cancel Anytime, Auto Renewable';

  @override
  String get paywallSubscribe => 'Subscribe';

  @override
  String get paywallTerms => 'Terms of Use';

  @override
  String get paywallPrivacy => 'Privacy Policy';

  @override
  String get paywallRestore => 'Restore Purchase';

  @override
  String get paywallGotIt => 'OK';

  @override
  String get paywallNoPackages => 'No subscription packages available.';

  @override
  String get paywallPurchaseFailed => 'Purchase failed';

  @override
  String get paywallRestoreSuccess => 'Purchases restored. Pro is active.';

  @override
  String get paywallRestoreNone => 'No active subscription found to restore.';

  @override
  String get paywallRestoreFailed => 'Restore failed';

  @override
  String get paywallClose => 'Close';

  @override
  String get topUpBuy => 'Buy';

  @override
  String get paywallRetry => 'Retry';

  @override
  String get addCoverNameLabel => 'Preset name';

  @override
  String get addCoverNameHint => 'My morning news';

  @override
  String get addCoverUploadAudio => 'Paste stream URL';

  @override
  String get addCoverUploadImage => 'Upload logo';

  @override
  String get addCoverSave => 'Save preset';

  @override
  String get addCoverTermsLink => 'Terms of Use';

  @override
  String get cancel => 'Cancel';

  @override
  String get tabMyVideos => 'My Episodes';

  @override
  String get tabMyVoices => 'My Presets';

  @override
  String get noGeneratedVideos => 'Your downloaded episodes will appear here';

  @override
  String get createYourOwnVoice => 'Create Your Preset';

  @override
  String get noSavedVoices => 'Your saved presets will appear here';

  @override
  String get settingsFaqDialogTitle => 'Frequently asked questions';

  @override
  String get playerTutorialRow => 'Player tutorial';

  @override
  String get playerTutorialReplayHint =>
      'The gesture tutorial will play next time you open the player.';

  @override
  String get settingsFaqQ1 => 'What\'s included in the Free plan?';

  @override
  String get settingsFaqA1 =>
      'O plano gratuito permite explorar dramas curtos, salvar favoritos e assistir em qualidade padrão. Faça upgrade para Pro para assistir sem anúncios, baixar episódios e acessar séries exclusivas VIP.';

  @override
  String get settingsFaqQ2 => 'What does Pro include?';

  @override
  String get settingsFaqA2 =>
      'O Pro desbloqueia visualização sem anúncios, downloads de episódios offline, séries exclusivas VIP, transmissões em alta qualidade e espaço ilimitado na lista.';

  @override
  String get settingsFaqQ3 => 'Can I download podcasts for offline listening?';

  @override
  String get settingsFaqA3 =>
      'Yes. Pro subscribers can download podcast episodes for offline listening on Wi‑Fi or mobile data, depending on your settings.';

  @override
  String get settingsFaqQ4 => 'Can I listen to live radio worldwide?';

  @override
  String get settingsFaqA4 =>
      'Yes. Browse 100,000+ live radio stations by genre, country, and language. Save presets and jump back to your favorites anytime.';

  @override
  String get settingsFaqQ5 => 'What audio quality is available?';

  @override
  String get settingsFaqA5 =>
      'Free users get standard streaming quality. Pro includes high-quality streams for supported stations and podcasts.';

  @override
  String get settingsFaqQ6 => 'Can I cancel anytime?';

  @override
  String get settingsFaqA6 =>
      'Yes. You can cancel your subscription whenever you want. You\'ll keep Pro access until the end of your current billing period.';

  @override
  String get settingsFaqQ7 => 'Do you offer refunds?';

  @override
  String get settingsFaqA7 =>
      'If you run into an issue, contact us and we\'ll help. Refund eligibility can vary depending on usage and billing; we\'ll review requests case-by-case.';

  @override
  String get settingsFaqQ8 => 'Can I switch plans later?';

  @override
  String get settingsFaqA8 =>
      'Yes. You can upgrade or downgrade at any time. Changes take effect immediately or at the next billing cycle depending on the plan change.';

  @override
  String get settingsFaqQ9 => 'How do podcast subscriptions work?';

  @override
  String get settingsFaqA9 =>
      'Subscribe to any podcast in one tap. New episodes appear in your library, and you can resume playback exactly where you left off.';

  @override
  String get settingsFaqQ10 => 'How do playlists and presets work?';

  @override
  String get settingsFaqA10 =>
      'Save radio stations as presets, build playlists, and keep your listening history synced across sessions so you can continue where you stopped.';

  @override
  String get settingsFaqQ11 => 'Which content is Pro-only?';

  @override
  String get settingsFaqA11 =>
      'Algumas séries exclusivas VIP, downloads offline, visualização sem anúncios e transmissões em alta qualidade exigem Pro. Usuários gratuitos ainda podem explorar a maioria dos dramas e episódios.';

  @override
  String get proBudgetHelpTitle => 'Como funciona o Pro';

  @override
  String get proBudgetHelpBullet1 =>
      'O Pro remove os anúncios da reprodução de episódios e desbloqueia recursos premium de dramas.';

  @override
  String get proBudgetHelpBullet2 =>
      'Sua lista, favoritos e histórico ficam sincronizados no app.';

  @override
  String get proBudgetHelpBullet3 =>
      'Os downloads offline permitem salvar episódios e assistir sem conexão.';

  @override
  String get proBudgetHelpBullet4 =>
      'Tap the Pro badge anytime to view plans or restore your subscription.';

  @override
  String get proBudgetHelpGotIt => 'Got it';

  @override
  String get headerHelpChip => 'Help?';

  @override
  String get splashTagline => 'Live radio & podcasts worldwide';

  @override
  String get splashInitErrorTitle => 'Initialization Error';

  @override
  String get splashInitErrorMessage =>
      'Failed to initialize the app. Please check your permissions and try again.';

  @override
  String get searchVoicesHint => 'Search presets…';

  @override
  String get yourVoices => 'Your presets';

  @override
  String get noVoicesYet => 'No presets yet';

  @override
  String get categoryOther => 'Other';

  @override
  String get signInToAddCoverVoice => 'Please sign in to save a preset';

  @override
  String get noVideoCreditsRemaining =>
      'No download credits remaining. Upgrade to Pro to continue.';

  @override
  String get notAuthenticated => 'Not authenticated';

  @override
  String get noPreviewForVoice => 'No preview available for this preset';

  @override
  String get genderMale => 'Male';

  @override
  String get genderFemale => 'Female';

  @override
  String get videoStatusCompleted => 'Completed';

  @override
  String get videoStatusGenerating => 'Downloading';

  @override
  String get videoStatusFailed => 'Failed';

  @override
  String get recordVoiceTitle => 'Name Preset';

  @override
  String get recordVoiceRerecord => 'Re-record';

  @override
  String get recordVoiceUseThis => 'Use This';

  @override
  String get recordVoiceMicRequired => 'Microphone access required';

  @override
  String get recordVoiceMicSettingsHint =>
      'Please enable microphone access\nin your device settings.';

  @override
  String get recordVoiceOpenSettings => 'Open Settings';

  @override
  String get recordVoiceRecording => 'Recording...';

  @override
  String get recordVoiceComplete => 'Recording complete';

  @override
  String get recordVoiceTapToStart => 'Tap to name your preset';

  @override
  String get recordVoicePlaying => 'Playing...';

  @override
  String get recordVoiceTapPreview => 'Tap to preview';

  @override
  String get recordVoiceTip1 => 'Speak clearly when naming';

  @override
  String get recordVoiceTip2 => 'Keep it short and memorable';

  @override
  String get recordVoiceTip3 => 'Use a quiet environment';

  @override
  String get uploadFile => 'Upload File';

  @override
  String get recordVoiceButton => 'Record Name';

  @override
  String get coverVoiceAdded => 'Preset saved';

  @override
  String audioFileMaxSize(int size) {
    return 'Audio file must be less than ${size}MB';
  }

  @override
  String imageFileMaxSize(int size) {
    return 'Image file must be less than ${size}MB';
  }

  @override
  String get addYourOwnVoice => 'Add your\nown preset';

  @override
  String maxFileSizeHint(int size) {
    return 'Max ${size}MB';
  }

  @override
  String get manageSubscriptions => 'Manage Subscriptions';

  @override
  String get settingsPurchasesRestoredSuccess =>
      'Purchases restored successfully';

  @override
  String settingsRestorePurchasesError(String error) {
    return 'Error restoring purchases: $error';
  }

  @override
  String get couldNotOpenSubscriptionPage =>
      'Could not open subscription page. Please visit your device\'s app store settings.';

  @override
  String get couldNotOpenLink => 'Could not open link';

  @override
  String get topUpSheetTitle => 'Top-ups';

  @override
  String topUpBalanceHint(int count) {
    return 'Saldo: $count moedas';
  }

  @override
  String topUpPerCredit(String price) {
    return '$price / credit';
  }

  @override
  String get topUpTierSmall => 'Small';

  @override
  String get topUpTierMedium => 'Medium';

  @override
  String get topUpTierLarge => 'Large';

  @override
  String get topUpRecommended => 'RECOMMENDED';

  @override
  String get topUpBestValue => 'BEST VALUE';

  @override
  String get topUpCreditsLabel => 'credits';

  @override
  String topUpExtraCredits(int count) {
    return '$count credits';
  }

  @override
  String get topUpSelectPack => 'Select a pack';

  @override
  String get topUpNoPacksInSize => 'No packs in this size';

  @override
  String get topUpProductsNotConfigured =>
      'Top-up products are not configured. Add topup_product_ids in Remote Config.';

  @override
  String get topUpProductsLoadFailed =>
      'Could not load top-up products. Check RevenueCat + store IDs match Remote Config.';

  @override
  String get topUpPurchaseSetupFailed =>
      'Purchase setup failed. Please try again.';

  @override
  String topUpPurchaseSuccess(int count) {
    return 'Top-up added! You now have $count credits.';
  }

  @override
  String topUpPurchaseFailed(String error) {
    return 'Purchase failed: $error';
  }

  @override
  String get topUpSignInRequired => 'Please sign in to purchase top-ups.';

  @override
  String proBudgetLongPressToast(int dailyLeft, int topUpLeft) {
    String _temp0 = intl.Intl.pluralLogic(
      dailyLeft,
      locale: localeName,
      other: '$dailyLeft free listens',
      one: '1 free listen',
    );
    String _temp1 = intl.Intl.pluralLogic(
      topUpLeft,
      locale: localeName,
      other: '$topUpLeft bonus listens',
      one: '1 bonus listen',
    );
    return 'You still have $_temp0 left today, and $_temp1 ready when you need them.';
  }

  @override
  String get forceUpdateTitle => 'Update Required';

  @override
  String get forceUpdateMessage =>
      'A new version of the app is available. Please update to continue using the app.';

  @override
  String get optionalUpdateTitle => 'Update Available';

  @override
  String get optionalUpdateMessage =>
      'A new version is available with improvements and bug fixes. Would you like to update?';

  @override
  String get updateNow => 'Update Now';

  @override
  String get maybeLater => 'Maybe Later';
}
