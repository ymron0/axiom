import 'package:axiom/src/core/result/result.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'record_already_exists_failure.mapper.dart';

/// Indicates that a persisted record conflicts with an existing record.
@MappableClass()
final class RecordAlreadyExistsFailure
    extends Failure<RecordAlreadyExistsFailure>
    with RecordAlreadyExistsFailureMappable {
  /// Creates a record-already-exists failure with optional details.
  const RecordAlreadyExistsFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'persistence.recordAlreadyExists';

  @override
  RecordAlreadyExistsFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
