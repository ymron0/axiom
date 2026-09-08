import 'package:axiom/src/core/result/result.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'record_not_found_failure.mapper.dart';

/// Indicates that a requested persisted record does not exist.
///
/// Example:
/// ```dart
/// const failure = RecordNotFoundFailure(message: 'Asset was not found.');
/// ```
@MappableClass()
final class RecordNotFoundFailure extends Failure<RecordNotFoundFailure>
    with RecordNotFoundFailureMappable {
  /// Creates a record-not-found failure with an optional explanation.
  const RecordNotFoundFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'persistence.recordNotFound';

  /// Returns this failure as its declared failure type.
  @override
  RecordNotFoundFailure get failureOrNull => this;

  /// Returns the stable identifier for this failure kind.
  @override
  String get type => typeId;
}
