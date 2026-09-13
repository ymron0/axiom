import 'package:axiom/src/features/transactions/application/use_cases/get_ledger_entries_by_account_id_use_case.dart';
import 'package:mocktail/mocktail.dart';

/// A mock ledger-entry lookup use case for application-service tests.
class MockGetLedgerEntriesByAccountIdUseCase extends Mock
    implements GetLedgerEntriesByAccountIdUseCase {}
