import 'package:axiom/src/features/transactions/domain/repositories/transaction_series_repository.dart';
import 'package:mocktail/mocktail.dart';

/// Mock transaction-series repository for application-layer tests.
class MockTransactionSeriesRepository extends Mock
    implements TransactionSeriesRepository {}
