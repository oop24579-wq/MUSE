import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' show ReadContext, WatchContext;
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import '../../core/test_flags.dart';
import '../../models/drama/reward_models.dart';
import '../../providers/drama/drama_providers.dart';
import '../../services/admob_service.dart';
import '../../services/app_config_service.dart';
import '../../services/drama/drama_service.dart';
import '../../services/firebase/remote_config_service.dart';
import '../../services/haptics_service.dart';
import '../../services/user_provider.dart';
import '../../widgets/ad_banner_widget.dart';
import '../../widgets/async_refresh_builder.dart';
import '../../widgets/confetti_burst.dart';
import '../../widgets/top_toast.dart';
import 'widgets/chest_row.dart';
import 'widgets/coin_balance_header.dart';
import 'widgets/daily_checkin_strip.dart';
import 'widgets/drama_section.dart';
import 'widgets/missions_section.dart';
import 'widgets/reward_task_tile.dart';
import 'widgets/rewards_premium_banner.dart';
import 'widgets/series_reward_tile.dart';
import 'widgets/streak_level_header.dart';
import 'widgets/wheel_widget.dart';

class RewardsContent extends ConsumerStatefulWidget {
  const RewardsContent({super.key});

  @override
  ConsumerState<RewardsContent> createState() => _RewardsContentState();
}

class _RewardsContentState extends ConsumerState<RewardsContent> {
  final GlobalKey<ConfettiBurstState> _confettiKey =
      GlobalKey<ConfettiBurstState>();
  final TextEditingController _referralController = TextEditingController();
  bool _referralBusy = false;

  /// Last observed `claimedToday`, so a check-in that lands while this tab
  /// is alive (the claim itself is auto-fired from the splash flow) still
  /// gets its celebration at the refresh point.
  bool? _lastClaimedToday;

  @override
  void dispose() {
    _referralController.dispose();
    super.dispose();
  }

  /// Confetti + success haptic for any successful coin claim on this tab.
  void _celebrate() {
    _confettiKey.currentState?.play();
    HapticsService.instance.success();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(rewardsProvider);
    final isPro = TestFlags.forceProForTest || context.watch<UserProvider>().isPro;
    final config = AppConfigService.instance;

    Future<void> refresh() async {
      ref.invalidate(rewardsProvider);
      await ref.read(rewardsProvider.future);
    }

    return Stack(
      children: [
        AsyncRefreshBuilder(
          asyncValue: async,
          onRefresh: () => ref.refresh(rewardsProvider.future),
          builder: (context, state) {
            // Celebrate a daily check-in that transitions to claimed while
            // this tab is mounted (see _lastClaimedToday).
            if (_lastClaimedToday == false && state.claimedToday) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _celebrate();
              });
            }
            _lastClaimedToday = state.claimedToday;

            // Split on the shape of the task, not on an action type. The API
            // never sends 'series_milestone' — its action types are the concrete
            // verbs (`watch_episodes`, `connect_email`, …) — so the old filter put
            // every task in the starter list and left Series Rewards permanently
            // empty. A target above 1 is what actually makes a task goal-shaped.
            final seriesTasks = state.tasks.where((t) => t.isMilestone).toList();
            final starterTasks = state.tasks.where((t) => !t.isMilestone).toList();
            final event = state.activeEvent;
            return ListView(
              padding: EdgeInsets.only(top: 1.h, bottom: 4.h),
              children: [
              CoinBalanceHeader(balance: state.coinBalance),
              SizedBox(height: 1.6.h),
              StreakLevelHeader(
                streak: state.currentStreak,
                level: state.level,
                xp: state.xp,
                nextLevelXp: state.nextLevelXp,
              ),
              if (event != null) ...[
                SizedBox(height: 1.4.h),
                _EventBanner(event: event),
              ],
              SizedBox(height: 2.h),
              DailyCheckinStrip(
                days: state.days,
                bonusCoins: RemoteConfigService.instance.rewardAdCoins,
                onBonus: () async {
                  final amount = RemoteConfigService.instance.rewardAdCoins;
                  final earned = await AdmobService.instance.showRewardedAd();
                  if (!context.mounted) return;
                  if (!earned) {
                    showTopToastInfo(context, 'Ad not available, try again later');
                    return;
                  }
                  final coins = await DramaService.instance.claimAdReward(amount);
                  if (!context.mounted) return;
                  if (coins != null) {
                    _celebrate();
                    showTopToastSuccess(context, '+$coins bonus coins!');
                    context.read<UserProvider>().refreshUserInBackground();
                  } else {
                    showTopToastInfo(context, 'Daily bonus limit reached');
                  }
                  await refresh();
                },
              ),
              SizedBox(height: 1.h),
              if (!isPro) ...[
                Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.w),
                    child: const AdBannerWidget(),
                  ),
                ),
                SizedBox(height: 1.h),
              ],
              const DramaSectionHeader(
                  title: 'Starter tasks', subtitle: 'Complete once for bonus coins'),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.w),
                child: Column(
                  children: [
                    for (final RewardTaskModel task in starterTasks)
                      RewardTaskTile(
                        task: task,
                        onAction: () async {
                          final coins = await DramaService.instance
                              .completeRewardTask(task.slug);
                          if (!context.mounted) return;
                          if (coins != null) {
                            _celebrate();
                            showTopToastSuccess(context, '+$coins coins!');
                            context.read<UserProvider>().refreshUserInBackground();
                          } else {
                            showTopToastInfo(context, 'Already completed');
                          }
                          await refresh();
                        },
                      ),
                  ],
                ),
              ),
              if (!isPro) ...[
                SizedBox(height: 2.h),
                const RewardsPremiumBanner(),
              ],
              if (seriesTasks.isNotEmpty) ...[
                SizedBox(height: 1.h),
                const DramaSectionHeader(
                    title: 'Series Rewards',
                    subtitle: 'Keep watching to earn more coins'),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.w),
                  child: Column(
                    children: [
                      for (final RewardTaskModel task in seriesTasks)
                        SeriesRewardTile(
                          task: task,
                          target: task.target,
                          progress: task.progress,
                          onClaim: () async {
                            final coins = await DramaService.instance
                                .completeRewardTask(task.slug);
                            if (!context.mounted) return;
                            if (coins != null) {
                              _celebrate();
                              showTopToastSuccess(context, '+$coins coins!');
                              context
                                  .read<UserProvider>()
                                  .refreshUserInBackground();
                            } else {
                              showTopToastInfo(context, 'Already claimed');
                            }
                            await refresh();
                          },
                        ),
                    ],
                  ),
                ),
              ],
              // ── Phase 2 sections ──────────────────────────────────────────
              if (config.feature('wheel') &&
                  state.wheel.enabled &&
                  state.wheel.segments.isNotEmpty) ...[
                SizedBox(height: 1.h),
                const DramaSectionHeader(
                    title: 'Lucky Wheel', subtitle: 'Spin daily for bonus coins'),
                WheelWidget(
                  wheel: state.wheel,
                  onWin: (coins) {
                    _celebrate();
                    showTopToastSuccess(context, '+$coins coins from the wheel!');
                    context.read<UserProvider>().refreshUserInBackground();
                  },
                  onRefresh: refresh,
                ),
              ],
              if (config.feature('chests') && state.chests.isNotEmpty) ...[
                SizedBox(height: 1.h),
                const DramaSectionHeader(
                    title: 'Treasure Chests',
                    subtitle: 'Watch episodes to unlock chests'),
                ChestRow(
                  chests: state.chests,
                  onClaim: (chest) async {
                    final coins =
                        await DramaService.instance.claimChest(chest.id);
                    if (!context.mounted) return;
                    if (coins != null) {
                      _celebrate();
                      showTopToastSuccess(context, '+$coins coins!');
                      context.read<UserProvider>().refreshUserInBackground();
                    } else {
                      showTopToastInfo(context, 'Chest not ready yet');
                    }
                    await refresh();
                  },
                ),
              ],
              if (config.feature('watch_time') && state.watchTime.enabled) ...[
                SizedBox(height: 1.h),
                const DramaSectionHeader(
                    title: 'Watch Time Rewards',
                    subtitle: 'Earn coins just for watching'),
                _WatchTimeCard(
                  watchTime: state.watchTime,
                  onClaim: () async {
                    final coins = await DramaService.instance.claimWatchTime();
                    if (!context.mounted) return;
                    if (coins != null) {
                      _celebrate();
                      showTopToastSuccess(context, '+$coins coins!');
                      context.read<UserProvider>().refreshUserInBackground();
                    } else {
                      showTopToastInfo(context, 'Nothing to claim yet');
                    }
                    await refresh();
                  },
                ),
              ],
              if (config.feature('missions') && state.missions.isNotEmpty) ...[
                SizedBox(height: 1.h),
                const DramaSectionHeader(
                    title: 'Daily Missions',
                    subtitle: 'Finish missions, claim coins'),
                MissionsSection(
                  missions: state.missions,
                  onClaim: (mission) async {
                    final coins =
                        await DramaService.instance.claimMission(mission.slug);
                    if (!context.mounted) return;
                    if (coins != null) {
                      _celebrate();
                      showTopToastSuccess(context, '+$coins coins!');
                      context.read<UserProvider>().refreshUserInBackground();
                    } else {
                      showTopToastInfo(context, 'Mission not completed yet');
                    }
                    await refresh();
                  },
                ),
              ],
              if (config.feature('referrals')) ...[
                SizedBox(height: 1.h),
                const DramaSectionHeader(
                    title: 'Invite Friends',
                    subtitle: 'Share your code, both of you earn coins'),
                _ReferralCard(
                  referralCode: state.referralCode,
                  controller: _referralController,
                  busy: _referralBusy,
                  onApply: () async {
                    final code = _referralController.text.trim();
                    if (code.isEmpty || _referralBusy) return;
                    setState(() => _referralBusy = true);
                    final coins =
                        await DramaService.instance.applyReferral(code);
                    if (!context.mounted) return;
                    setState(() => _referralBusy = false);
                    if (coins != null) {
                      _celebrate();
                      _referralController.clear();
                      showTopToastSuccess(
                          context, '+$coins referral bonus coins!');
                      context.read<UserProvider>().refreshUserInBackground();
                    } else {
                      showTopToastInfo(context, 'Invalid referral code');
                    }
                    await refresh();
                  },
                ),
              ],
            ],
            );
          },
        ),
        // Confetti overlay — ignores pointers, fired via _celebrate().
        Positioned.fill(child: ConfettiBurst(key: _confettiKey)),
      ],
    );
  }
}

/// "Event name — rewards ×N!" banner chip shown while an event is active.
class _EventBanner extends StatelessWidget {
  const _EventBanner({required this.event});

  final ActiveEventState event;

  @override
  Widget build(BuildContext context) {
    final multiplier = event.multiplier;
    final multiplierLabel = multiplier == multiplier.roundToDouble()
        ? '${multiplier.toInt()}'
        : multiplier.toStringAsFixed(1);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 3.5.w, vertical: 1.1.h),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.accentBlue, AppTheme.accentBlueLight],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.celebration, color: Colors.white, size: 18),
            SizedBox(width: 2.w),
            Expanded(
              child: Text(
                '${event.name} — rewards ×$multiplierLabel!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10.5.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Watch-time card: minutes watched today, progress toward the next block,
/// claimable coins and a Claim button.
class _WatchTimeCard extends StatelessWidget {
  const _WatchTimeCard({required this.watchTime, required this.onClaim});

  final WatchTimeState watchTime;
  final Future<void> Function() onClaim;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;
    final subColor = textColor.withValues(alpha: 0.55);
    final canClaim = watchTime.claimableCoins > 0;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w),
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDarkBlue : AppTheme.cardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: textColor.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule, color: AppTheme.accentBlue, size: 5.5.w),
              SizedBox(width: 2.w),
              Text(
                '${watchTime.minutesToday} min watched today',
                style: TextStyle(
                  color: textColor,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${watchTime.claimedCoinsToday}/${watchTime.dailyCapCoins} today',
                style: TextStyle(color: subColor, fontSize: 8.5.sp),
              ),
            ],
          ),
          if (watchTime.blockMinutes > 0) ...[
            SizedBox(height: 1.1.h),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: watchTime.blockProgress,
                minHeight: 6,
                backgroundColor: textColor.withValues(alpha: 0.10),
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppTheme.accentBlue),
              ),
            ),
            SizedBox(height: 0.5.h),
            Text(
              '${watchTime.minutesIntoCurrentBlock}/${watchTime.blockMinutes} min '
              'toward the next +${watchTime.coinsPerBlock} coins',
              style: TextStyle(color: subColor, fontSize: 8.5.sp),
            ),
          ],
          SizedBox(height: 1.2.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: canClaim ? onClaim : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentBlue,
                foregroundColor: Colors.white,
                disabledBackgroundColor: textColor.withValues(alpha: 0.12),
                padding: EdgeInsets.symmetric(vertical: 1.2.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                canClaim
                    ? 'Claim ${watchTime.claimableCoins} coins'
                    : 'No coins to claim yet',
                style:
                    TextStyle(fontSize: 10.5.sp, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Referral card: the user's own copyable code + a field to apply a friend's.
class _ReferralCard extends StatelessWidget {
  const _ReferralCard({
    required this.referralCode,
    required this.controller,
    required this.busy,
    required this.onApply,
  });

  final String referralCode;
  final TextEditingController controller;
  final bool busy;
  final Future<void> Function() onApply;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;
    final subColor = textColor.withValues(alpha: 0.55);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w),
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDarkBlue : AppTheme.cardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: textColor.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your referral code',
            style: TextStyle(color: subColor, fontSize: 9.5.sp),
          ),
          SizedBox(height: 0.7.h),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: referralCode.isEmpty
                ? null
                : () async {
                    await Clipboard.setData(
                        ClipboardData(text: referralCode));
                    if (!context.mounted) return;
                    HapticsService.instance.light();
                    showTopToastSuccess(context, 'Referral code copied');
                  },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.1.h),
              decoration: BoxDecoration(
                color: textColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: textColor.withValues(alpha: 0.10)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      referralCode.isEmpty ? '—' : referralCode,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  Icon(Icons.copy_rounded, color: subColor, size: 18),
                ],
              ),
            ),
          ),
          SizedBox(height: 1.4.h),
          Text(
            'Have a friend\'s code?',
            style: TextStyle(color: subColor, fontSize: 9.5.sp),
          ),
          SizedBox(height: 0.7.h),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  textCapitalization: TextCapitalization.characters,
                  style: TextStyle(color: textColor, fontSize: 11.sp),
                  decoration: InputDecoration(
                    hintText: 'Enter code',
                    hintStyle: TextStyle(color: subColor, fontSize: 11.sp),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 3.w, vertical: 1.2.h),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 2.w),
              ElevatedButton(
                onPressed: busy ? null : onApply,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentBlue,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                      horizontal: 4.w, vertical: 1.2.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Apply',
                        style: TextStyle(
                            fontSize: 10.5.sp, fontWeight: FontWeight.w800),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
