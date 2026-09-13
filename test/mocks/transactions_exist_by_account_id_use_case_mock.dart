import 'package:axiom/src/features/transactions/application/use_cases/transactions_exist_by_account_id_use_case.dart';
import 'package:mocktail/mocktail.dart';

/// A mock transaction-existence use case for application-service tests.
class MockTransactionsExistByAccountIdUseCase extends Mock
    implements TransactionsExistByAccountIdUseCase {}
