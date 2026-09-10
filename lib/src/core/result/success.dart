part of 'result.dart';

/// Represents a successful [Result] containing the value produced by a
/// completed operation.
///
/// ## Invariants
///
/// A [Success] always represents a successful result and cannot represent a
/// failure at the same time. The successful [value] is immutable after
/// construction. When value equality is provided by the mapping mechanism,
/// it is based on the meaningful stored value.
///
/// ## Semantics
///
/// [Success] means that the operation completed successfully and produced a
/// value of type [T]. Nullable payloads are valid when [T] is nullable.
///
/// ## Contract
///
/// The payload is available through [value] and [valueOrNull]. The result
/// state is available through [isSuccess] and [isFailure]; [failureOrNull] is
/// always `null` for a [Success]. Use [when] to handle the successful outcome
/// without treating it as a failure.
@MappableClass()
final class Success<T extends Object?> extends Result<T, Never>
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
