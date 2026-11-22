import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import '../../providers/drama/drama_providers.dart';
import 'drama_navigation.dart';
import 'widgets/series_poster_card.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller.text = ref.read(searchQueryProvider);
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref.read(searchQueryProvider.notifier).state = value.trim();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;
    final query = ref.watch(searchQueryProvider);
    final resultsAsync = ref.watch(searchResultsProvider);

    return Scaffold(
      backgroundColor: AppTheme.pageBackground(isDark),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(4.w, 1.h, 4.w, 1.h),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      onChanged: _onChanged,
                      textInputAction: TextInputAction.search,
                      style: TextStyle(color: textColor, fontSize: 11.sp),
                      decoration: InputDecoration(
                        hintText: 'Search dramas…',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _controller.text.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  _controller.clear();
                                  ref.read(searchQueryProvider.notifier).state = '';
                                  setState(() {});
                                },
                              ),
                        filled: true,
                        fillColor:
                            isDark ? AppTheme.cardDarkBlue : AppTheme.cardLight,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: query.isEmpty
                  ? Center(
                      child: Text(
                        'Find your next binge',
                        style: TextStyle(
                            color: textColor.withValues(alpha: 0.5), fontSize: 11.sp),
                      ),
                    )
                  : resultsAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (_, __) =>
                          const Center(child: Text('Search failed')),
                      data: (results) {
                        if (results.isEmpty) {
                          return Center(
                            child: Text('No results for "$query"',
                                style: TextStyle(
                                    color: textColor.withValues(alpha: 0.6))),
                          );
                        }
                        return SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(4.w, 1.h, 4.w, 4.h),
                          child: Wrap(
                            spacing: 2.w,
                            runSpacing: 2.h,
                            children: [
                              for (final s in results)
                                SeriesPosterCard(
                                  series: s,
                                  width: 28.5.w,
                                  onTap: () => DramaNav.openSeries(context, s),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
