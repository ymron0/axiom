import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'custodian_not_archived_failure.mapper.dart';

/// Indicates that an operation requiring an archived custodian received an
/// active custodian.
@MappableClass()
final class CustodianNotArchivedFailure
    extends Failure<CustodianNotArchivedFailure>
    with CustodianNotArchivedFailureMappable
    implements CustodianFailure {
  /// Creates a custodian-not-archived failure.
  const CustodianNotArchivedFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'custodians.custodianNotArchived';

  @override
  CustodianNotArchivedFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
