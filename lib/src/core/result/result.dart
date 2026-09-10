import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'failure.dart';
part 'success.dart';
part 'result.mapper.dart';

/// Represents the outcome of an operation that may succeed or fail.
///
/// Use [Result] when failure is an expected, recoverable part of a domain or
/// application contract. Do not use it to suppress programmer errors,
/// violated assumptions, or invariant violations that indicate invalid
/// program state.
///
/// ## Invariants
///
/// A [Result] represents exactly one operation outcome. It is either
/// successful or failed, and must never represent both at the same time.
/// Successful values are represented by [Success], failed outcomes are
/// represented by [Failure], and the result object is immutable after
/// creation. Concrete result implementations enforce these invariants.
///
/// ## Semantics
///
/// A successful result carries the value produced by the operation. A failed
/// result carries typed failure information describing an expected failure.
/// Programmer errors and violated domain invariants should be handled through
/// the project's exception or invariant-validation mechanisms instead.
///
/// ## Contract
///
/// [isSuccess] and [isFailure] identify the single outcome. [valueOrNull] is
/// populated only for a successful result, and [failureOrNull] is populated
/// only for a failed result. Because a successful value may itself be null,
/// callers must use the state properties when distinguishing outcomes.
@MappableClass()
sealed class Result<T extends Object?, F extends BaseFailure>
    with ResultMappable {
  /// Creates a result for use by a concrete result type.
  const Result();

  /// Whether this result contains a failure.
  bool get isFailure;

  /// Whether this result contains a successful value.
  bool get isSuccess;

  /// The failure, or `null` when this result is successful.
  F? get failureOrNull;

  /// The successful value, or `null` when this result is a failure.
  T? get valueOrNull;

  /// Handles the result by invoking the callback for its state.
  R when<R>({
    required R Function(T value) success,
    required R Function(F failure) failure,
  });
}
