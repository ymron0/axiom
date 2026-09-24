import 'package:axiom/src/presentation/failures/presentation_failure.dart';

part 'operation_idle.dart';
part 'operation_in_progress.dart';
part 'operation_success.dart';
part 'operation_failure.dart';

/// Represents the state of a user-triggered operation.
///
/// Examples include creating, updating, deleting, archiving, restoring, and
/// converting entities.
///
/// ## Invariants
///
/// Exactly one operation state is active at a time.
///
/// ## Semantics
///
/// Page content should generally remain visible while an operation is in
/// progress. This state therefore describes the operation itself rather than
/// replacing the state of the entire screen.
///
/// ## Contract
///
/// Controllers transition from [OperationIdle] to [OperationInProgress], then
/// to either [OperationSuccess] or [OperationFailure].
sealed class OperationState<T extends Object?> {
  const OperationState();

  /// Whether no operation is currently active.
  bool get isIdle;

  /// Whether an operation is running.
  bool get isInProgress;

  /// Whether the last operation completed successfully.
  bool get isSuccess;

  /// Whether the last operation failed.
  bool get isFailure;

  /// Successful result when available.
  T? get valueOrNull;

  /// Presentation error when available.
  PresentationFailure? get errorOrNull;
}
