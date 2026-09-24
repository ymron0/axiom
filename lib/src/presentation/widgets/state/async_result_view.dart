import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/presentation/failures/presentation_failure.dart';
import 'package:axiom/src/presentation/failures/presentation_failure_mapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'empty_state_view.dart';
part 'error_state_view.dart';
part 'loading_state_view.dart';

/// Builder for successfully loaded presentation data.
typedef AsyncResultDataBuilder<T> =
    Widget Function(BuildContext context, T value);

/// Determines whether successfully loaded data represents an empty state.
typedef AsyncResultEmptyPredicate<T> = bool Function(T value);

/// Renders `AsyncValue<Result<T, F>>` consistently.
///
/// Riverpod loading and unexpected asynchronous errors are handled separately
/// from expected domain/application failures represented by [Result].
///
/// ## Semantics
///
/// Initial loading displays [LoadingStateView].
///
/// Existing data remains visible during provider refresh or reload. A linear
/// progress indicator is displayed above the existing content.
///
/// Expected failures are mapped with [PresentationErrorMapper].
///
/// Unexpected asynchronous errors receive a generic safe presentation error.
///
/// ## Behavior
///
/// Feature screens should not duplicate loading/error/result branching.
/// Instead they should delegate it to this widget.
final class AsyncResultView<T, F extends BaseFailure> extends StatelessWidget {
  final AsyncValue<Result<T, F>> value;
  final AsyncResultDataBuilder<T> builder;
  final AsyncResultEmptyPredicate<T>? isEmpty;
  final WidgetBuilder? emptyBuilder;
  final VoidCallback? onRetry;
  final PresentationFailureMapper errorMapper;
  final String loadingSemanticLabel;
  final String emptyTitle;
  final String? emptyMessage;

  /// Creates an asynchronous result view.
  const AsyncResultView({
    required this.value,
    required this.builder,
    this.isEmpty,
    this.emptyBuilder,
    this.onRetry,
    this.errorMapper = const PresentationFailureMapper(),
    this.loadingSemanticLabel = 'Loading',
    this.emptyTitle = 'Nothing here yet',
    this.emptyMessage,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      loading: () => LoadingStateView(semanticLabel: loadingSemanticLabel),
      error: (error, stackTrace) => ErrorStateView(
        error: errorMapper.fromObject(error),
        onRetry: onRetry,
      ),
      data: (result) {
        final content = result.when<Widget>(
          success: (loadedValue) {
            if (isEmpty?.call(loadedValue) ?? false) {
              return emptyBuilder?.call(context) ??
                  EmptyStateView(title: emptyTitle, message: emptyMessage);
            }

            return builder(context, loadedValue);
          },
          failure: (failure) {
            return ErrorStateView(
              error: errorMapper.fromFailure(failure),
              onRetry: onRetry,
            );
          },
        );

        if (!value.isRefreshing && !value.isReloading) {
          return content;
        }

        return Stack(
          children: [
            content,
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(minHeight: 2),
            ),
          ],
        );
      },
    );
  }
}
