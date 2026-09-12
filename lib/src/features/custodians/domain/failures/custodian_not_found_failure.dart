import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'custodian_not_found_failure.mapper.dart';

/// Indicates that an expected custodian does not exist.
@MappableClass()
final class CustodianNotFoundFailure
    extends Failure<CustodianNotFoundFailure>
    with CustodianNotFoundFailureMappable
    implements CustodianFailure {
  /// Creates a custodian-not-found failure with optional details.
  const CustodianNotFoundFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'custodians.custodianNotFound';

  @override
  CustodianNotFoundFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
