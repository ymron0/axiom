@Tags(['di'])
library;

import 'package:axiom/src/application/di/services/get_account_balance_service_provider.dart';
import 'package:axiom/src/application/di/services/get_custodian_summary_service_provider.dart';
import 'package:axiom/src/application/services/get_custodian_summary_service.dart';
import 'package:axiom/src/features/accounts/application/use_cases/get_accounts_by_custodian_id_use_case.dart';
import 'package:axiom/src/features/accounts/di/get_accounts_by_custodian_id_use_case_provider.dart';
import 'package:axiom/src/features/custodians/application/use_cases/get_custodian_by_id_use_case.dart';
import 'package:axiom/src/features/custodians/di/get_custodian_by_id_use_case_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

import '../../../../mocks/account_repository_mock.dart';
import '../../../../mocks/custodian_repository_mock.dart';
import '../../../../mocks/get_account_balance_service_mock.dart';

void main() {
  group('getCustodianSummaryService provider', () {
    test('resolves the custodian summary service', () {
      final container = ProviderContainer(
        overrides: [
          getCustodianByIdUseCaseProvider.overrideWithValue(
            GetCustodianByIdUseCase(MockCustodianRepository()),
          ),
          getAccountsByCustodianIdUseCaseProvider.overrideWithValue(
            GetAccountsByCustodianIdUseCase(MockAccountRepository()),
          ),
          getAccountBalanceServiceProvider.overrideWithValue(
            MockGetAccountBalanceService(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(getCustodianSummaryServiceProvider);

      expect(service, isA<GetCustodianSummaryService>());
    });
  });
}
