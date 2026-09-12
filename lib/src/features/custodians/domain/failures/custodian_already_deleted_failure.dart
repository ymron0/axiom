import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'custodian_already_deleted_failure.mapper.dart';

/// Indicates that a custodian is already marked as deleted.
@MappableClass()
final class CustodianAlreadyDeletedFailure
    extends Failure<CustodianAlreadyDeletedFailure>
    with CustodianAlreadyDeletedFailureMappable
    implements CustodianFailure {
  /// Creates a custodian-already-deleted failure with optional details.
  const CustodianAlreadyDeletedFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'custodians.custodianAlreadyDeleted';

  @override
  CustodianAlreadyDeletedFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
