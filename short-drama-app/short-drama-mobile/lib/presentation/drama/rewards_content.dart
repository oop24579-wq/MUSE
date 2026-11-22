import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' show ReadContext, WatchContext;
import 'package:sizer/sizer.dart';

import '../../core/test_flags.dart';
import '../../models/drama/reward_models.dart';
import '../../providers/drama/drama_providers.dart';
import '../../services/admob_service.dart';
import '../../services/drama/drama_service.dart';
import '../../services/firebase/remote_config_service.dart';
import '../../services/user_provider.dart';
import '../../widgets/ad_banner_widget.dart';
import '../../widgets/async_refresh_builder.dart';
import '../../widgets/top_toast.dart';
import 'widgets/coin_balance_header.dart';
import 'widgets/daily_checkin_strip.dart';
import 'widgets/drama_section.dart';
import 'widgets/reward_task_tile.dart';
import 'widgets/rewards_premium_banner.dart';
import 'widgets/series_reward_tile.dart';

class RewardsContent extends ConsumerWidget {
  const RewardsContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(rewardsProvider);
    final isPro = TestFlags.forceProForTest || context.watch<UserProvider>().isPro;

    Future<void> refresh() async {
      ref.invalidate(rewardsProvider);
      await ref.read(rewardsProvider.future);
    }

    return AsyncRefreshBuilder(
      asyncValue: async,
      onRefresh: () => ref.refresh(rewardsProvider.future),
      builder: (context, state) {
        // Split on the shape of the task, not on an action type. The API
        // never sends 'series_milestone' — its action types are the concrete
        // verbs (`watch_episodes`, `connect_email`, …) — so the old filter put
        // every task in the starter list and left Series Rewards permanently
        // empty. A target above 1 is what actually makes a task goal-shaped.
        final seriesTasks = state.tasks.where((t) => t.isMilestone).toList();
        final starterTasks = state.tasks.where((t) => !t.isMilestone).toList();
        return ListView(
          padding: EdgeInsets.only(top: 1.h, bottom: 4.h),
          children: [
          CoinBalanceHeader(balance: state.coinBalance),
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
        ],
        );
      },
    );
  }
}
