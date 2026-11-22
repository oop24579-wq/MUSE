import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_export.dart';

/// Builds async Riverpod content with pull-to-refresh that keeps previous data
/// visible while reloading (no full-screen spinner flash).
class AsyncRefreshBuilder<T> extends StatelessWidget {
  const AsyncRefreshBuilder({
    super.key,
    required this.asyncValue,
    required this.onRefresh,
    required this.builder,
    this.onRetry,
    this.loading,
    this.error,
    this.scrollable = true,
  });

  final AsyncValue<T> asyncValue;
  final Future<void> Function() onRefresh;
  final VoidCallback? onRetry;
  final Widget Function(BuildContext context, T data) builder;
  final Widget Function()? loading;
  final Widget Function(Object error, StackTrace stack)? error;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    return asyncValue.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () =>
          loading?.call() ??
          Center(child: CircularProgressIndicator(color: AppTheme.accentBlue)),
      error: (e, st) =>
          error?.call(e, st) ??
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Something went wrong', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: onRetry ?? () => onRefresh(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
      data: (data) {
        final content = builder(context, data);
        if (!scrollable) return content;
        return RefreshIndicator(
          color: AppTheme.accentBlue,
          onRefresh: onRefresh,
          child: content,
        );
      },
    );
  }
}

/// Optional top progress bar while [asyncValue.isRefreshing] is true.
class AsyncRefreshIndicator extends StatelessWidget {
  const AsyncRefreshIndicator({
    super.key,
    required this.asyncValue,
    required this.child,
  });

  final AsyncValue<dynamic> asyncValue;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (asyncValue.isRefreshing)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(minHeight: 2),
          ),
      ],
    );
  }
}

/// Refreshes a Riverpod [FutureProvider] and waits for the new value.
Future<void> refreshFutureProvider<T>(
  WidgetRef ref,
  FutureProvider<T> provider,
) {
  return ref.refresh(provider.future);
}
