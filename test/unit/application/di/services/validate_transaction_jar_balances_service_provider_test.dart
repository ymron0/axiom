@Tags(['application', 'di'])
library;

import 'package:axiom/src/application/di/services/validate_transaction_jar_balances_service_provider.dart';
import 'package:axiom/src/application/services/validate_transaction_jar_balances_service.dart';
import 'package:axiom/src/features/settings/application/use_cases/get_settings_use_case.dart';
import 'package:axiom/src/features/settings/di/get_settings_use_case_provider.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_transactions_by_jar_id_use_case.dart';
import 'package:axiom/src/features/transactions/di/get_transactions_by_jar_id_use_case_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

import '../../../../mocks/settings_repository_mock.dart';
import '../../../../mocks/transaction_repository_mock.dart';

void main() {
  group('validateTransactionJarBalancesServiceProvider', () {
    test('provides the configured jar-balance validator', () {
      final container = ProviderContainer(
        overrides: [
          getSettingsUseCaseProvider.overrideWithValue(
            GetSettingsUseCase(MockSettingsRepository()),
          ),
          getTransactionsByJarIdUseCaseProvider.overrideWithValue(
            GetTransactionsByJarIdUseCase(MockTransactionRepository()),
          ),
        ],
      );

      addTearDown(container.dispose);

      final service = container.read(
        validateTransactionJarBalancesServiceProvider,
      );

      expect(service, isA<ValidateTransactionJarBalancesService>());
    });
  });
}
