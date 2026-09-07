part of 'result.dart';

/// Represents a result containing a successful value.
@MappableClass()
final class Success<T extends Object> extends Result<T, Never>
    with SuccessMappable {
  /// Creates a successful result containing [value].
  const Success(this.value);

  /// The value produced by the successful operation.
  final T value;

  /// The failure, which is always `null` for a success.
  @override
  Never? get failureOrNull => null;

  /// Whether this result contains a failure.
  @override
  bool get isFailure => false;

  /// Whether this result contains a successful value.
  @override
  bool get isSuccess => true;

  /// The successful value.
  @override
  T get valueOrNull => value;

  /// Invokes the success callback with [value].
  @override
  R when<R>({
    required R Function(T value) success,
    required R Function(Never failure) failure,
  }) {
    return success(value);
  }
}
