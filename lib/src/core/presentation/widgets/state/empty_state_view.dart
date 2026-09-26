part of 'async_result_view.dart';

/// Standard presentation for successfully loaded content that contains no data.
///
/// Empty state is distinct from both loading and failure: the operation
/// completed successfully, but there is currently nothing to display.
///
/// ## Semantics
///
/// Empty state is not a live accessibility region because it represents stable
/// successfully loaded content.
///
/// The optional action uses normal Material button semantics.
///
/// ## Contract
///
/// [actionLabel] and [onAction] must either both be supplied or both be absent.
///
/// This widget does not determine whether data is empty. That decision belongs
/// to [AsyncResultView] or the owning feature.
final class EmptyStateView extends StatelessWidget {
  final String title;
  final String? message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Creates an empty state.
  const EmptyStateView({
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
    super.key,
  }) : assert(
         (actionLabel == null && onAction == null) ||
             (actionLabel != null && onAction != null),
         'actionLabel and onAction must either both be supplied or both be null.',
       );

  @override
  Widget build(BuildContext context) {
    return AppStateView(
      icon: icon,
      title: title,
      message: message,
      action: onAction == null
          ? null
          : FilledButton(onPressed: onAction, child: Text(actionLabel!)),
    );
  }
}
