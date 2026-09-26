part of 'async_result_view.dart';

/// Standard blocking loading state.
///
/// Use this view when no usable content is currently available.
///
/// Refreshing already-visible data is handled separately by [AsyncResultView]
/// and must not replace existing content with this loading state.
///
/// ## Semantics
///
/// [semanticLabel] is exposed as a live accessibility announcement.
///
/// The progress indicator itself is excluded from semantics to avoid duplicate
/// announcements.
///
/// ## Contract
///
/// This widget communicates loading only. It does not own asynchronous state
/// or initiate operations.
final class LoadingStateView extends StatelessWidget {
  final String semanticLabel;

  /// Creates a loading state.
  const LoadingStateView({this.semanticLabel = 'Loading', super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        liveRegion: true,
        label: semanticLabel,
        child: const ExcludeSemantics(child: CircularProgressIndicator()),
      ),
    );
  }
}
