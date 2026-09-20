import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'custodian_repository_failure.mapper.dart';

/// Indicates that a custodian repository operation could not complete.
@MappableClass()
final class CustodianRepositoryFailure
    extends Failure<CustodianRepositoryFailure>
    with CustodianRepositoryFailureMappable
    implements CustodianFailure {
  /// Creates a custodian repository failure with optional details.
  const CustodianRepositoryFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'custodians.repository';

  @override
  CustodianRepositoryFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
