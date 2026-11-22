import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import '../../models/drama/genre_model.dart';
import '../../providers/drama/drama_providers.dart';
import '../../widgets/async_refresh_builder.dart';
import 'drama_navigation.dart';
import 'widgets/series_poster_card.dart';

class CategorySeriesScreen extends ConsumerWidget {
  const CategorySeriesScreen({super.key, required this.genre});

  final GenreModel genre;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final async = ref.watch(categorySeriesProvider(genre.id));

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(isDark),
      appBar: AppBar(
        title: Text(genre.name),
        backgroundColor: Colors.transparent,
      ),
      body: AsyncRefreshBuilder(
        asyncValue: async,
        onRefresh: () => ref.refresh(categorySeriesProvider(genre.id).future),
        builder: (context, series) {
          if (series.isEmpty) {
            return const Center(child: Text('No dramas here yet'));
          }
          final cardWidth = 28.5.w;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(4.w, 2.h, 4.w, 4.h),
            child: Wrap(
              spacing: 2.w,
              runSpacing: 2.h,
              children: [
                for (final s in series)
                  SeriesPosterCard(
                    series: s,
                    width: cardWidth,
                    onTap: () => DramaNav.openSeries(context, s),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
