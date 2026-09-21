@Tags(['application', 'di'])
library;

import 'package:axiom/src/application/di/services/get_account_asset_balances_service_provider.dart';
import 'package:axiom/src/application/services/get_account_asset_balances_service.dart';
import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/di/get_account_by_id_use_case_provider.dart';
import 'package:axiom/src/features/accounts/domain/entities/account.dart';
import 'package:axiom/src/features/transactions/di/get_transactions_by_account_id_use_case_provider.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

import '../../../../fixtures/features/accounts/account_fixtures.dart';
import '../../../../mocks/get_account_by_id_use_case_mock.dart';
import '../../../../mocks/get_transactions_by_account_id_use_case_mock.dart';

void main() {
  group('getAccountAssetBalancesServiceProvider', () {
    test(
      'uses the configured account, transaction, and clock dependencies',
      () async {
        // Given
        final getAccountById = MockGetAccountByIdUseCase();
        final getTransactionsByAccountId =
            MockGetTransactionsByAccountIdUseCase();
        final account = accountFixture(id: 'provider-asset-balance-account');
        final clock = FixedClock(DateTime.utc(2026, 1, 1));

        when(
          () => getAccountById(account.id),
        ).thenAnswer((_) async => Success<Account?>(account));
        when(
          () => getTransactionsByAccountId(account.id),
        ).thenAnswer((_) async => const Success<List<Transaction>>([]));

        final container = ProviderContainer(
          overrides: [
            getAccountByIdUseCaseProvider.overrideWithValue(getAccountById),
            getTransactionsByAccountIdUseCaseProvider.overrideWithValue(
              getTransactionsByAccountId,
            ),
            clockProvider.overrideWithValue(clock),
          ],
        );
        addTearDown(container.dispose);

        // When
        final service = container.read(getAccountAssetBalancesServiceProvider);
        final result = await service(account.id);

        // Then
        expect(service, isA<GetAccountAssetBalancesService>());
        expect(result.valueOrNull, isEmpty);
        verify(() => getAccountById(account.id)).called(1);
        verify(() => getTransactionsByAccountId(account.id)).called(1);
      },
    );
  });
}
