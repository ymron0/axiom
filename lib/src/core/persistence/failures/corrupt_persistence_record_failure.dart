import 'package:axiom/src/core/result/result.dart';
import 'package:dart_mappable/dart_mappable.dart';

import 'persistence_failure.dart';

part 'corrupt_persistence_record_failure.mapper.dart';

/// Indicates that persisted data cannot be safely reconstructed into the
/// expected domain representation.
///
/// This may result from missing fields, incorrect persisted types, malformed
/// serialized values, invalid identifiers, unknown enum values, or domain
/// invariants rejected while reconstructing an entity.
@MappableClass()
final class CorruptPersistenceRecordFailure
    extends Failure<CorruptPersistenceRecordFailure>
    with CorruptPersistenceRecordFailureMappable
    implements PersistenceFailure {
  const CorruptPersistenceRecordFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'persistence.corrupt_record';

  @override
  CorruptPersistenceRecordFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
