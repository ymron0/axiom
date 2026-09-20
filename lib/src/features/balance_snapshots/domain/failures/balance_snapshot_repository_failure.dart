import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/balance_snapshots/domain/failures/balance_snapshot_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'balance_snapshot_repository_failure.mapper.dart';

/// Indicates that a balance snapshot repository operation could not complete.
@MappableClass()
final class BalanceSnapshotRepositoryFailure
    extends Failure<BalanceSnapshotRepositoryFailure>
    with BalanceSnapshotRepositoryFailureMappable
    implements BalanceSnapshotFailure {
  /// Creates a balance snapshot repository failure with optional details.
  const BalanceSnapshotRepositoryFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'balanceSnapshots.repository';

  @override
  BalanceSnapshotRepositoryFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
