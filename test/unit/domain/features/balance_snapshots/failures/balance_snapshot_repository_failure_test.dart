import 'package:axiom/src/features/balance_snapshots/domain/failures/balance_snapshot_repository_failure.dart';
import 'package:test/test.dart';

void main() {
  group('BalanceSnapshotRepositoryFailure', () {
    test('preserves its diagnostic failure information', () {
      const failure = BalanceSnapshotRepositoryFailure(
        message: 'repository failed',
      );

      expect(failure.message, 'repository failed');
      expect(failure.type, BalanceSnapshotRepositoryFailure.typeId);
      expect(failure.failureOrNull, same(failure));
    });
  });
}
