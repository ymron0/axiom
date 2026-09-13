import 'package:axiom/src/features/transactions/application/use_cases/transactions_exist_by_merchant_id_use_case.dart';
import 'package:mocktail/mocktail.dart';

/// A mock transaction-existence use case for application-service tests.
class MockTransactionsExistByMerchantIdUseCase extends Mock
    implements TransactionsExistByMerchantIdUseCase {}
