@Tags(['domain'])
library;

import 'package:axiom/src/features/balance_snapshots/domain/failures/balance_snapshot_persistence_failure.dart';
import 'package:test/test.dart';

void main() {
  group('BalanceSnapshotPersistenceFailure', () {
    test('can be instantiated without a diagnostic message', () {
      // Given
      const failure = BalanceSnapshotPersistenceFailure();

      // Then
      expect(failure.message, isNull);
    });

    test('preserves the provided diagnostic message', () {
      // Given
      const message = 'Balance snapshot persistence failed.';

      // When
      const failure = BalanceSnapshotPersistenceFailure(message: message);

      // Then
      expect(failure.message, message);
    });

    test('returns its static type identifier from type', () {
      // Given
      const failure = BalanceSnapshotPersistenceFailure();

      // Then
      expect(failure.type, BalanceSnapshotPersistenceFailure.typeId);
    });

    test('returns itself from failureOrNull', () {
      // Given
      const failure = BalanceSnapshotPersistenceFailure();

      // Then
      expect(failure.failureOrNull, same(failure));
    });
  });
}
