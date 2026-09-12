import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'custodian_already_exists_failure.mapper.dart';

/// Indicates that a custodian conflicts with an existing custodian.
@MappableClass()
final class CustodianAlreadyExistsFailure
    extends Failure<CustodianAlreadyExistsFailure>
    with CustodianAlreadyExistsFailureMappable
    implements CustodianFailure {
  /// Creates a custodian-already-exists failure with optional details.
  const CustodianAlreadyExistsFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'custodians.custodianAlreadyExists';

  @override
  CustodianAlreadyExistsFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
