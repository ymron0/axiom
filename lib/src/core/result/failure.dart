part of 'result.dart';

/// Represents an expected unsuccessful [Result] containing typed failure
/// information for callers to inspect and handle.
///
/// A [Failure] is for failures that are part of the normal domain or
/// application contract. It is not a replacement for programmer errors or
/// violated internal invariants that indicate invalid program state.
///
/// ## Invariants
///
/// A [Failure] always represents a failed result and cannot represent a
/// successful result at the same time. Its failure state is immutable after
/// construction, and required failure information remains available for the
/// lifetime of the object. When value equality is provided by the mapping
/// mechanism, it remains stable and reflects meaningful failure state.
///
/// ## Semantics
///
/// [Failure] represents an expected unsuccessful outcome. The typed failure
/// information identifies the kind of failure and may include additional
/// context through [message]. Callers can inspect or handle it without
/// treating it as an exception or presentation concern.
///
/// ## Contract
///
/// Concrete failures return themselves from [failureOrNull], expose a stable
/// [type] identifier, and never expose a successful value through
/// [valueOrNull]. [isFailure] is always `true`, [isSuccess] is always `false`,
/// and [when] invokes the failure callback with the typed failure.
@MappableClass()
abstract class Failure<F extends BaseFailure> extends Result<Never, F>
    with FailureMappable
    implements BaseFailure {
  /// Creates a failure with optional human-readable details.
  const Failure([this.message]);

  /// Describes the failure when additional context is available.
  @override
  final String? message;

  /// This instance as its declared failure type.
  ///
  /// Concrete failures must return themselves from this getter.
  @override
  F get failureOrNull;

  /// Whether this result contains a failure.
  @override
  bool get isFailure => true;

  /// Whether this result contains a successful value.
  @override
  bool get isSuccess => false;

  /// The stable, namespaced identifier for this kind of failure.
  ///
  /// Concrete failures must use an identifier such as
  /// `authentication.invalidCredentials` that remains unchanged when the
  /// implementing class is renamed.
  @override
  String get type;

  /// The successful value, which is always `null` for a failure.
  @override
  Never? get valueOrNull => null;

  /// Invokes the failure callback with this failure.
  @override
  R when<R>({
    required R Function(Never value) success,
    required R Function(F failure) failure,
  }) {
    return failure(failureOrNull);
  }
}
