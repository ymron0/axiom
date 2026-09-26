import 'package:flutter_riverpod/experimental/mutation.dart';

import '../../failures/base_failure.dart';
import '../../result/result.dart';
import '../failures/presentation_failure.dart';
import '../failures/presentation_failure_mapper.dart';

/// Widens a typed failure result to the shared presentation failure boundary.
///
/// This is deliberately implemented through [Result.when]. Returning
/// `result.failureOrNull` would return the failure payload rather than a
/// `Result`, which is not type-compatible with `Result<T, BaseFailure>`.
Result<T, BaseFailure> widenResult<T, F extends BaseFailure>(
  Result<T, F> result,
) {
  return result.when<Result<T, BaseFailure>>(
    success: (value) => Success<T>(value),
    failure: (failure) => failure,
  );
}

/// Maps the current mutation state to a presentation failure when applicable.
///
/// Expected application/domain failures are represented by a successful
/// mutation containing a failed [Result]. Unexpected exceptions are
/// represented by [MutationError].
PresentationFailure? resultMutationFailure<T>(
  MutationState<Result<T, BaseFailure>> state, {
  PresentationFailureMapper mapper = const PresentationFailureMapper(),
}) {
  return switch (state) {
    MutationError(:final error) => mapper.fromObject(error),
    MutationSuccess(:final value) when value.isFailure => mapper.fromFailure(
      value.failureOrNull!,
    ),
    _ => null,
  };
}
