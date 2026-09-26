import 'package:axiom/src/core/presentation/failures/presentation_failure.dart';
import 'package:axiom/src/core/presentation/failures/presentation_failure_kind.dart';
import 'package:axiom/src/core/presentation/widgets/state/async_result_view.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

/// Fallback page for an unknown navigation target.
///
/// ## Semantics
///
/// The error is announced as a live region by [ErrorStateView].
///
/// ## Contract
///
/// Invalid external paths do not expose router internals and always offer a
/// safe path back to the application's primary navigation.
@RoutePage()
final class NavigationNotFoundPage extends StatelessWidget {
  static const _failure = PresentationFailure(
    kind: PresentationFailureKind.notFound,
    title: 'Page not found',
    message: 'The requested page does not exist.',
  );

  /// Creates the unknown-route page.
  const NavigationNotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ErrorStateView(
        error: _failure,
        retryLabel: 'Go home',
        onRetry: () {
          context.router.replacePath('/');
        },
      ),
    );
  }
}
