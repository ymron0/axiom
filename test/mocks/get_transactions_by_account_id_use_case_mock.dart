import 'package:axiom/src/features/transactions/application/use_cases/get_transactions_by_account_id_use_case.dart';
import 'package:mocktail/mocktail.dart';

/// A mock transaction lookup use case for application-service tests.
class MockGetTransactionsByAccountIdUseCase extends Mock
    implements GetTransactionsByAccountIdUseCase {}
