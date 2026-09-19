@Tags(['di'])
library;

import 'package:axiom/src/application/di/services/capture_balance_snapshots_service_provider.dart';
import 'package:axiom/src/application/di/services/historical_balance_query_service_provider.dart';
import 'package:axiom/src/application/di/services/resolve_conversion_rate_service_provider.dart';
import 'package:axiom/src/application/services/capture_balance_snapshots_service.dart';
import 'package:axiom/src/application/services/historical_balance_query_service.dart';
import 'package:axiom/src/application/services/resolve_conversion_rate_service.dart';
import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/features/accounts/application/use_cases/get_accounts_use_case.dart';
import 'package:axiom/src/features/accounts/di/get_accounts_use_case_provider.dart';
import 'package:axiom/src/features/balance_snapshots/di/balance_snapshot_repository_provider.dart';
import 'package:axiom/src/features/custodians/application/use_cases/get_custodians_use_case.dart';
import 'package:axiom/src/features/custodians/di/get_custodians_use_case_provider.dart';
import 'package:axiom/src/features/jars/application/use_cases/get_jars_use_case.dart';
import 'package:axiom/src/features/jars/di/get_jars_use_case_provider.dart';
import 'package:axiom/src/features/rates/domain/services/rate_conversion_service.dart';
import 'package:axiom/src/features/settings/application/use_cases/get_settings_use_case.dart';
import 'package:axiom/src/features/settings/di/get_settings_use_case_provider.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_all_transactions_use_case.dart';
import 'package:axiom/src/features/transactions/di/get_all_transactions_use_case_provider.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

import '../../../../mocks/account_repository_mock.dart';
import '../../../../mocks/balance_snapshot_repository_mock.dart';
import '../../../../mocks/custodian_repository_mock.dart';
import '../../../../mocks/get_rate_at_use_case_mock.dart';
import '../../../../mocks/jar_repository_mock.dart';
import '../../../../mocks/settings_repository_mock.dart';
import '../../../../mocks/transaction_repository_mock.dart';

void main() {
  group('balance snapshot service providers', () {
    late ProviderContainer container;

    setUp(() {
      final snapshotRepository = MockBalanceSnapshotRepository();

      final resolveConversionRate = ResolveConversionRateService(
        getRateAt: MockGetRateAtUseCase(),
        canonicalBridgeAssetId: AssetId.fromString('asset-usd'),
        rateConversion: const RateConversionService(),
      );

      container = ProviderContainer(
        overrides: [
          balanceSnapshotRepositoryProvider.overrideWithValue(
            snapshotRepository,
          ),
          getSettingsUseCaseProvider.overrideWithValue(
            GetSettingsUseCase(MockSettingsRepository()),
          ),
          getAccountsUseCaseProvider.overrideWithValue(
            GetAccountsUseCase(MockAccountRepository()),
          ),
          getCustodiansUseCaseProvider.overrideWithValue(
            GetCustodiansUseCase(MockCustodianRepository()),
          ),
          getJarsUseCaseProvider.overrideWithValue(
            GetJarsUseCase(MockJarRepository()),
          ),
          getAllTransactionsUseCaseProvider.overrideWithValue(
            GetAllTransactionsUseCase(MockTransactionRepository()),
          ),
          resolveConversionRateServiceProvider.overrideWithValue(
            resolveConversionRate,
          ),
          clockProvider.overrideWithValue(
            FixedClock(DateTime.utc(2026, 9, 19, 12)),
          ),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('resolves the snapshot capture service', () {
      // When
      final service = container.read(captureBalanceSnapshotsServiceProvider);

      // Then
      expect(service, isA<CaptureBalanceSnapshotsService>());
    });

    test('resolves the historical balance query service', () {
      // When
      final service = container.read(historicalBalanceQueryServiceProvider);

      // Then
      expect(service, isA<HistoricalBalanceQueryService>());
    });
  });
}
