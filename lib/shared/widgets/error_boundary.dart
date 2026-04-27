import 'package:flutter/material.dart';
import 'package:wai_life_assistant/core/services/error_logger.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ERROR BOUNDARY
// Wraps a subtree so a single widget failure degrades gracefully instead of
// taking down the whole screen.
//
// Flutter doesn't propagate build errors to parent widgets automatically
// (unlike React boundaries).  This widget catches errors in two ways:
//   1. Automatically — via FlutterError.onError when a child build throws
//      (the global handler marks the nearest boundary as errored).
//   2. Manually — call ErrorBoundary.of(context).markErrored() from any
//      descendant catch block to trigger the fallback UI.
//
// Usage:
//   ErrorBoundary(
//     feature: 'wallet',
//     child: WalletSummaryCard(),
//   )
//
//   ErrorBoundary(
//     feature: 'pantry',
//     fallback: Center(child: Text('Meal plan unavailable')),
//     child: MealMapWidget(),
//   )
// ─────────────────────────────────────────────────────────────────────────────

class ErrorBoundary extends StatefulWidget {
  final Widget  child;
  final Widget? fallback;
  final String  feature;

  const ErrorBoundary({
    super.key,
    required this.child,
    required this.feature,
    this.fallback,
  });

  static ErrorBoundaryState? of(BuildContext context) =>
      context.findAncestorStateOfType<ErrorBoundaryState>();

  @override
  State<ErrorBoundary> createState() => ErrorBoundaryState();
}

class ErrorBoundaryState extends State<ErrorBoundary> {
  bool    _hasError = false;
  dynamic _lastError;

  void markErrored(dynamic error, {StackTrace? stackTrace}) {
    ErrorLogger.log(
      error,
      stackTrace: stackTrace,
      severity:   ErrorSeverity.error,
      action:     'boundary_catch',
      extra:      {'feature': widget.feature},
    );
    if (mounted) setState(() { _hasError = true; _lastError = error; });
  }

  void reset() {
    if (mounted) setState(() { _hasError = false; _lastError = null; });
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return widget.fallback ?? _DefaultFallback(
        error:   _lastError,
        onRetry: reset,
      );
    }
    return widget.child;
  }
}

class _DefaultFallback extends StatelessWidget {
  final dynamic    error;
  final VoidCallback onRetry;

  const _DefaultFallback({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        colorScheme.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: colorScheme.errorContainer),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, color: colorScheme.error),
          const SizedBox(height: 8),
          Text(
            'Something went wrong here.\nThe rest of the app is fine.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onErrorContainer,
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}
