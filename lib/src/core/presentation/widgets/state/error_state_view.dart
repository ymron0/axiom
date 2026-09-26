part of 'async_result_view.dart';

/// Standard presentation for a safe user-facing failure.
///
/// ## Semantics
///
/// Error state is exposed as a live accessibility region so a newly occurring
/// failure can be announced.
///
/// ## Contract
///
/// [error] must already be a presentation-safe [PresentationFailure].
///
/// Domain, application, persistence, and infrastructure failures must be
/// translated through [PresentationFailureMapper] before they are rendered.
///
/// Retry behavior is owned by the caller.
final class ErrorStateView extends StatelessWidget {
  final PresentationFailure error;
  final VoidCallback? onRetry;
  final String retryLabel;

  /// Creates an error state.
  const ErrorStateView({
    required this.error,
    this.onRetry,
    this.retryLabel = 'Try again',
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppStateView(
      icon: Icons.error_outline_rounded,
      iconColor: theme.colorScheme.error,
      title: error.title,
      message: error.message,
      liveRegion: true,
      action: onRetry == null
          ? null
          : FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(retryLabel),
            ),
    );
  }
}
