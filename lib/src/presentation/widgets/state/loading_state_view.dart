part of 'async_result_view.dart';

/// Standard full-content loading state.
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
