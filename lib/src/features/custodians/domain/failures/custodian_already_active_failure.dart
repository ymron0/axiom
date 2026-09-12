import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'custodian_already_active_failure.mapper.dart';

/// Indicates that a custodian is already active.
@MappableClass()
final class CustodianAlreadyActiveFailure
    extends Failure<CustodianAlreadyActiveFailure>
    with CustodianAlreadyActiveFailureMappable
    implements CustodianFailure {
  /// Creates a custodian-already-active failure with optional details.
  const CustodianAlreadyActiveFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'custodians.custodianAlreadyActive';

  @override
  CustodianAlreadyActiveFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
