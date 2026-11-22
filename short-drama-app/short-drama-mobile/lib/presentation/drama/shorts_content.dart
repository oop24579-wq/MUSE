import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sizer/sizer.dart';

import '../../providers/drama/drama_providers.dart';
import '../../widgets/async_refresh_builder.dart';
import 'drama_navigation.dart';
import 'widgets/featured_hero_card.dart';

/// "For You" browse feed — a vertical stream of spotlight cards.
class ShortsContent extends ConsumerWidget {
  const ShortsContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(forYouProvider);
    return AsyncRefreshBuilder(
      asyncValue: async,
      onRefresh: () => ref.refresh(forYouProvider.future),
      builder: (context, series) {
        if (series.isEmpty) {
          return const Center(child: Text('Nothing to recommend yet'));
        }
        return ListView.separated(
          padding: EdgeInsets.fromLTRB(4.w, 1.h, 4.w, 3.h),
          itemCount: series.length,
          separatorBuilder: (_, __) => SizedBox(height: 2.h),
          itemBuilder: (_, i) => FeaturedHeroCard(
            series: series[i],
            height: 30.h,
            onTap: () => DramaNav.openSeries(context, series[i]),
          ),
        );
      },
    );
  }
}
