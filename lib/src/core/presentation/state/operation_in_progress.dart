part of 'operation_state.dart';

/// An operation is currently running.
final class OperationInProgress<T extends Object?> extends OperationState<T> {
  /// Creates an in-progress state.
  const OperationInProgress();

  @override
  bool get isIdle => false;

  @override
  bool get isInProgress => true;

  @override
  bool get isSuccess => false;

  @override
  bool get isFailure => false;

  @override
  T? get valueOrNull => null;

  @override
  PresentationFailure? get errorOrNull => null;
}
