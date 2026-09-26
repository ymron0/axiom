part of 'operation_state.dart';

/// An operation failed.
final class OperationFailure<T extends Object?> extends OperationState<T> {
  final PresentationFailure error;

  /// Creates a failed operation state.
  const OperationFailure(this.error);

  @override
  bool get isIdle => false;

  @override
  bool get isInProgress => false;

  @override
  bool get isSuccess => false;

  @override
  bool get isFailure => true;

  @override
  T? get valueOrNull => null;

  @override
  PresentationFailure get errorOrNull => error;
}
