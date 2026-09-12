import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'custodian_in_use_failure.mapper.dart';

/// Indicates that a custodian is referenced by at least one account.
@MappableClass()
final class CustodianInUseFailure extends Failure<CustodianInUseFailure>
    with CustodianInUseFailureMappable
    implements CustodianFailure {
  /// Creates a custodian-in-use failure with optional details.
  const CustodianInUseFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'custodians.custodianInUse';

  @override
  CustodianInUseFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
