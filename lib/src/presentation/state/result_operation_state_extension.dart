import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/presentation/failures/presentation_failure_mapper.dart';
import 'package:axiom/src/presentation/state/operation_state.dart';

/// Presentation helpers for expected operation results.
extension ResultOperationStateExtension<
  T extends Object?,
  F extends BaseFailure
>
    on Result<T, F> {
  /// Converts this result to the corresponding presentation operation state.
  OperationState<T> toOperationState(PresentationFailureMapper errorMapper) {
    return when(
      success: (value) => OperationSuccess<T>(value),
      failure: (failure) =>
          OperationFailure<T>(errorMapper.fromFailure(failure)),
    );
  }
}
