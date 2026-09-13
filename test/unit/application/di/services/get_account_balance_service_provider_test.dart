import 'package:axiom/src/application/di/services/get_account_balance_service_provider.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/di/get_account_by_id_use_case_provider.dart';
import 'package:axiom/src/features/accounts/domain/entities/account.dart';
import 'package:axiom/src/features/transactions/di/get_ledger_entries_by_account_id_use_case_provider.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/ledger_entry.dart';
import 'package:decimal/decimal.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

import '../../../../fixtures/features/accounts/account_fixtures.dart';
import '../../../../mocks/get_account_by_id_use_case_mock.dart';
import '../../../../mocks/get_ledger_entries_by_account_id_use_case_mock.dart';

void main() {
  group('getAccountBalanceServiceProvider', () {
    test('uses the configured account and ledger-entry use cases', () async {
      // Given
      final getAccountById = MockGetAccountByIdUseCase();
      final getLedgerEntriesByAccountId =
          MockGetLedgerEntriesByAccountIdUseCase();
      final account = accountFixture(id: 'provider-balance-account');
      when(
        () => getAccountById(account.id),
      ).thenAnswer((_) async => Success<Account?>(account));
      when(
        () => getLedgerEntriesByAccountId(account.id),
      ).thenAnswer((_) async => const Success<List<LedgerEntry>>([]));
      final container = ProviderContainer(
        overrides: [
          getAccountByIdUseCaseProvider.overrideWithValue(getAccountById),
          getLedgerEntriesByAccountIdUseCaseProvider.overrideWithValue(
            getLedgerEntriesByAccountId,
          ),
        ],
      );
      addTearDown(container.dispose);

      // When
      final result = await container.read(getAccountBalanceServiceProvider)(
        account.id,
      );

      // Then
      expect(result.valueOrNull, Decimal.zero);
      verify(() => getAccountById(account.id)).called(1);
      verify(() => getLedgerEntriesByAccountId(account.id)).called(1);
    });
  });
}
