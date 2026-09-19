import 'package:axiom/src/features/balance_snapshots/domain/repositories/balance_snapshot_repository.dart';
import 'package:mocktail/mocktail.dart';

/// A mock balance-snapshot repository for application-service tests.
class MockBalanceSnapshotRepository extends Mock
    implements BalanceSnapshotRepository {}
