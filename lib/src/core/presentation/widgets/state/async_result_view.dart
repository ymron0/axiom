import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/presentation/failures/presentation_failure.dart';
import 'package:axiom/src/core/presentation/failures/presentation_failure_mapper.dart';
import 'package:axiom/src/core/presentation/widgets/state/app_state_view.dart';
import 'package:axiom/src/core/result/result.dart';
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
/// This widget is the shared presentation boundary between:
///
/// - Riverpod asynchronous state;
/// - typed application/domain failures;
/// - successfully loaded content;
/// - successfully loaded empty content.
///
/// ## Loading behavior
///
/// Initial loading replaces content with [LoadingStateView].
///
/// Refresh and reload preserve successfully loaded content and display a
/// lightweight progress indicator above it.
///
/// ## Failure behavior
///
/// Expected failures contained in [Result] remain typed until they reach this
/// widget and are converted with [PresentationFailureMapper].
///
/// Unexpected errors produced by the asynchronous provider are converted into
/// a generic safe presentation failure.
///
/// ## Empty behavior
///
/// Empty state is determined only after the operation succeeds. The optional
/// [isEmpty] predicate defines what empty means for the feature.
///
/// ## Contract
///
/// Feature screens should not reproduce loading/error/result/refresh branching.
///
/// Business logic and retry operations remain owned by the feature.
final class AsyncResultView<T, F extends BaseFailure> extends StatelessWidget {
  final AsyncValue<Result<T, F>> value;
  final AsyncResultDataBuilder<T> builder;
  final AsyncResultEmptyPredicate<T>? isEmpty;
  final WidgetBuilder? emptyBuilder;
  final VoidCallback? onRetry;
  final PresentationFailureMapper errorMapper;
  final String loadingSemanticLabel;
  final String refreshSemanticLabel;
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
    this.refreshSemanticLabel = 'Refreshing',
    this.emptyTitle = 'Nothing here yet',
    this.emptyMessage,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      loading: () {
        return LoadingStateView(semanticLabel: loadingSemanticLabel);
      },
      error: (error, stackTrace) {
        return ErrorStateView(
          error: errorMapper.fromObject(error),
          onRetry: onRetry,
        );
      },
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
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Semantics(
                liveRegion: true,
                label: refreshSemanticLabel,
                child: const ExcludeSemantics(
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
