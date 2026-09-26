part of 'operation_state.dart';

/// An operation completed successfully.
final class OperationSuccess<T extends Object?> extends OperationState<T> {
  final T value;

  /// Creates a successful operation state.
  const OperationSuccess(this.value);

  @override
  bool get isIdle => false;

  @override
  bool get isInProgress => false;

  @override
  bool get isSuccess => true;

  @override
  bool get isFailure => false;

  @override
  T get valueOrNull => value;

  @override
  PresentationFailure? get errorOrNull => null;
}
