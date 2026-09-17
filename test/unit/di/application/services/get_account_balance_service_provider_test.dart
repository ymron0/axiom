@Tags(['di'])
library;

import 'package:axiom/src/application/di/services/get_account_balance_service_provider.dart';
import 'package:axiom/src/application/services/get_account_balance_service.dart';
import 'package:axiom/src/features/accounts/application/use_cases/get_account_by_id_use_case.dart';
import 'package:axiom/src/features/accounts/di/get_account_by_id_use_case_provider.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_ledger_entries_by_account_id_use_case.dart';
import 'package:axiom/src/features/transactions/di/get_ledger_entries_by_account_id_use_case_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

import '../../../../mocks/account_repository_mock.dart';
import '../../../../mocks/transaction_repository_mock.dart';

void main() {
  group('getAccountBalanceService provider', () {
    test('resolves the account balance service', () {
      final container = ProviderContainer(
        overrides: [
          getAccountByIdUseCaseProvider.overrideWithValue(
            GetAccountByIdUseCase(MockAccountRepository()),
          ),
          getLedgerEntriesByAccountIdUseCaseProvider.overrideWithValue(
            GetLedgerEntriesByAccountIdUseCase(MockTransactionRepository()),
          ),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(getAccountBalanceServiceProvider);

      expect(service, isA<GetAccountBalanceService>());
    });
  });
}
