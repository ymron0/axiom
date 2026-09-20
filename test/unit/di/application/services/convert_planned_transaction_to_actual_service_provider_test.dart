@Tags(['application', 'di'])
library;

import 'package:axiom/src/application/di/services/convert_planned_transaction_to_actual_service_provider.dart';
import 'package:axiom/src/application/di/services/update_transaction_service_provider.dart';
import 'package:axiom/src/application/services/convert_planned_transaction_to_actual_service.dart';
import 'package:axiom/src/application/services/get_valuation_currency_service.dart';
import 'package:axiom/src/application/services/update_transaction_service.dart';
import 'package:axiom/src/application/services/validate_transaction_asset_semantics_service.dart';
import 'package:axiom/src/application/services/validate_transaction_allocations_service.dart';
import 'package:axiom/src/application/services/validate_transaction_tags_service.dart';
import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/repositories/batch_lookup.dart';
import 'package:axiom/src/features/categories/application/use_cases/get_category_by_id_use_case.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_asset_by_id_use_case.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_assets_by_ids_use_case.dart';
import 'package:axiom/src/features/settings/application/use_cases/get_settings_use_case.dart';
import 'package:axiom/src/features/settings/domain/entities/settings.dart';
import 'package:axiom/src/features/jars/application/use_cases/get_jar_by_id_use_case.dart';
import 'package:axiom/src/features/tags/application/use_cases/get_tags_by_ids_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_transaction_by_id_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/update_transaction_use_case.dart';
import 'package:axiom/src/features/transactions/di/get_transaction_by_id_use_case_provider.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

import '../../../../fixtures/application/services/allow_all_transaction_budgets_service.dart';
import '../../../../mocks/category_repository_mock.dart';
import '../../../../mocks/jar_repository_mock.dart';
import '../../../../mocks/tag_repository_mock.dart';
import '../../../../mocks/transaction_repository_mock.dart';
import '../../../../mocks/asset_repository_mock.dart';
import '../../../../mocks/settings_repository_mock.dart';
import '../../../../fixtures/features/assets/asset_fixtures.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:mocktail/mocktail.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(AssetId.fromString('fallback-asset'));
  });

  group('convertPlannedTransactionToActualServiceProvider', () {
    test('provides the planned-to-actual workflow', () {
      final lookupRepository = MockTransactionRepository();
      final updateRepository = MockTransactionRepository();
      final assetRepository = MockAssetRepository();
      final settingsRepository = MockSettingsRepository();

      final allocationValidator = ValidateTransactionAllocationsService(
        getCategoryById: GetCategoryByIdUseCase(MockCategoryRepository()),
        getJarById: GetJarByIdUseCase(MockJarRepository()),
      );

      final tagValidator = ValidateTransactionTagsService(
        getTagsByIds: GetTagsByIdsUseCase(MockTagRepository()),
      );

      when(() => settingsRepository.get()).thenAnswer(
        (_) async => Success(
          Settings(valuationCurrencyId: AssetId.fromString('asset-eur')),
        ),
      );
      when(() => assetRepository.getById(any())).thenAnswer((invocation) async {
        final assetId = invocation.positionalArguments.single as AssetId;
        return Success(currencyFixture(id: assetId.value));
      });
      when(() => assetRepository.getByIds(any())).thenAnswer((invocation) async {
        final ids = invocation.positionalArguments.single as List<AssetId>;
        return Success(
          BatchLookup(
            found: [for (final id in ids) currencyFixture(id: id.value)],
            missing: const [],
          ),
        );
      });

      final updateService = UpdateTransactionService(
        getTransactionById: GetTransactionByIdUseCase(updateRepository),
        updateTransaction: UpdateTransactionUseCase(updateRepository),
        validateAssets: ValidateTransactionAssetSemanticsService(
          getAssetsByIds: GetAssetsByIdsUseCase(assetRepository),
          getValuationCurrency: GetValuationCurrencyService(
            getSettings: GetSettingsUseCase(settingsRepository),
            getAssetById: GetAssetByIdUseCase(assetRepository),
          ),
        ),
        validateAllocations: allocationValidator,
        validateTags: tagValidator,
        validateBudgets: const AllowAllTransactionBudgetsService(),
      );

      final container = ProviderContainer(
        overrides: [
          clockProvider.overrideWithValue(
            FixedClock(DateTime.utc(2026, 9, 19)),
          ),
          getTransactionByIdUseCaseProvider.overrideWithValue(
            GetTransactionByIdUseCase(lookupRepository),
          ),
          updateTransactionServiceProvider.overrideWithValue(updateService),
        ],
      );

      addTearDown(container.dispose);

      final service = container.read(
        convertPlannedTransactionToActualServiceProvider,
      );

      expect(service, isA<ConvertPlannedTransactionToActualService>());
    });
  });
}
