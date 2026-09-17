import 'package:axiom/src/features/transactions/application/use_cases/query_transactions_use_case.dart';
import 'package:mocktail/mocktail.dart';

/// A mock transaction query use case for application-service tests.
class MockQueryTransactionsUseCase extends Mock
    implements QueryTransactionsUseCase {}
