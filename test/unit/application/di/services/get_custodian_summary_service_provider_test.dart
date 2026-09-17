@Tags(['application'])
library;

import 'package:axiom/src/application/di/services/get_account_balance_service_provider.dart';
import 'package:axiom/src/application/di/services/get_custodian_summary_service_provider.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/di/get_accounts_by_custodian_id_use_case_provider.dart';
import 'package:axiom/src/features/accounts/domain/entities/account.dart';
import 'package:axiom/src/features/custodians/di/get_custodian_by_id_use_case_provider.dart';
import 'package:axiom/src/features/custodians/domain/entities/custodian.dart';
import 'package:decimal/decimal.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

import '../../../../fixtures/features/accounts/account_fixtures.dart';
import '../../../../fixtures/features/custodians/custodian_fixtures.dart';
import '../../../../mocks/get_account_balance_service_mock.dart';
import '../../../../mocks/get_accounts_by_custodian_id_use_case_mock.dart';
import '../../../../mocks/get_custodian_by_id_use_case_mock.dart';

void main() {
  group('getCustodianSummaryServiceProvider', () {
    test('uses the configured custodian, account, and balance dependencies',
        () async {
      // Given
      final getCustodianById = MockGetCustodianByIdUseCase();
      final getAccountsByCustodianId = MockGetAccountsByCustodianIdUseCase();
      final getAccountBalance = MockGetAccountBalanceService();
      final custodian = custodianFixture(id: 'provider-summary-custodian');
      final account = accountFixture(
        id: 'provider-summary-account',
        custodianId: custodian.id.value,
        denominationAssetId: 'provider-summary-asset',
      );
      when(
        () => getCustodianById(custodian.id),
      ).thenAnswer((_) async => Success<Custodian?>(custodian));
      when(
        () => getAccountsByCustodianId(custodian.id),
      ).thenAnswer((_) async => Success<List<Account>>([account]));
      when(
        () => getAccountBalance(account.id),
      ).thenAnswer((_) async => Success<Decimal>(Decimal.fromInt(42)));
      final container = ProviderContainer(
        overrides: [
          getCustodianByIdUseCaseProvider.overrideWithValue(getCustodianById),
          getAccountsByCustodianIdUseCaseProvider.overrideWithValue(
            getAccountsByCustodianId,
          ),
          getAccountBalanceServiceProvider.overrideWithValue(
            getAccountBalance,
          ),
        ],
      );
      addTearDown(container.dispose);

      // When
      final result = await container.read(getCustodianSummaryServiceProvider)(
        custodian.id,
      );

      // Then
      final summary = result.valueOrNull;
      expect(summary, isNotNull);
      expect(summary!.custodianId, custodian.id);
      expect(summary.accountCount, 1);
      expect(
        summary.balancesByAsset[account.denominationAssetId],
        Decimal.fromInt(42),
      );
      verify(() => getCustodianById(custodian.id)).called(1);
      verify(() => getAccountsByCustodianId(custodian.id)).called(1);
      verify(() => getAccountBalance(account.id)).called(1);
    });
  });
}
