part of 'result.dart';

/// Represents a result containing a typed failure.
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
