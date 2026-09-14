import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'custodian_already_archived_failure.mapper.dart';

/// Indicates that a custodian is already archived.
@MappableClass()
final class CustodianAlreadyArchivedFailure
    extends Failure<CustodianAlreadyArchivedFailure>
    with CustodianAlreadyArchivedFailureMappable
    implements CustodianFailure {
  /// Creates a custodian-already-archived failure.
  const CustodianAlreadyArchivedFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'custodians.custodianAlreadyArchived';

  @override
  CustodianAlreadyArchivedFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
