part of 'operation_state.dart';

/// No operation has started.
final class OperationIdle<T extends Object?> extends OperationState<T> {
  /// Creates an idle state.
  const OperationIdle();

  @override
  bool get isIdle => true;

  @override
  bool get isInProgress => false;

  @override
  bool get isSuccess => false;

  @override
  bool get isFailure => false;

  @override
  T? get valueOrNull => null;

  @override
  PresentationFailure? get errorOrNull => null;
}
