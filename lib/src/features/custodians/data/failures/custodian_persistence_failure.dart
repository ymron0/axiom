import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'custodian_persistence_failure.mapper.dart';

/// Indicates that custodian persistence could not complete successfully.
///
/// This failure represents storage-level problems exposed through the
/// Custodians domain failure contract.
///
/// Infrastructure-specific failures and exceptions must not escape through
/// `CustodianRepository`. Persistent repository implementations translate
/// expected storage problems into this failure instead.
///
/// Examples include:
///
/// - Sembast database failures,
/// - file-system failures,
/// - malformed persisted custodian records,
/// - persisted custodian records that cannot be reconstructed according to the
///   current domain invariants.
///
/// Programmer errors and violated internal assumptions are deliberately not
/// translated into this failure and must continue to propagate normally.
@MappableClass()
final class CustodianPersistenceFailure
    extends Failure<CustodianPersistenceFailure>
    with CustodianPersistenceFailureMappable
    implements CustodianFailure {
  /// Creates a custodian-persistence failure with optional details.
  const CustodianPersistenceFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'custodians.persistence';

  @override
  CustodianPersistenceFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
