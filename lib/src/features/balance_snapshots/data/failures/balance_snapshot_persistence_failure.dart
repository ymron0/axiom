import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/balance_snapshots/domain/failures/balance_snapshot_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'balance_snapshot_persistence_failure.mapper.dart';

/// Indicates that balance-snapshot persistence could not complete
/// successfully.
///
/// This failure represents expected storage-level problems exposed through the
/// Balance Snapshots domain failure contract.
///
/// Examples include:
///
/// - Sembast database failures;
/// - file-system failures;
/// - malformed persisted snapshot records;
/// - unsupported persisted record versions; and
/// - persisted snapshots that violate current domain invariants.
///
/// Programmer errors and violated internal assumptions deliberately propagate.
@MappableClass()
final class BalanceSnapshotPersistenceFailure
    extends Failure<BalanceSnapshotPersistenceFailure>
    with BalanceSnapshotPersistenceFailureMappable
    implements BalanceSnapshotFailure {
  /// Creates a balance-snapshot persistence failure.
  const BalanceSnapshotPersistenceFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'balanceSnapshots.persistence';

  @override
  BalanceSnapshotPersistenceFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
