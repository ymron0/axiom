import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'failure.dart';
part 'success.dart';
part 'result.mapper.dart';

/// Represents either a successful value or a failure.
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
