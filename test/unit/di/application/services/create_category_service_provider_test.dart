@Tags(['di'])
library;

import 'package:axiom/src/application/di/services/create_category_service_provider.dart';
import 'package:axiom/src/application/di/services/validate_category_budget_currencies_service_provider.dart';
import 'package:axiom/src/application/services/create_category_service.dart';
import 'package:axiom/src/application/services/get_valuation_currency_service.dart';
import 'package:axiom/src/application/services/validate_category_budget_currencies_service.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_asset_by_id_use_case.dart';
import 'package:axiom/src/features/categories/application/use_cases/create_category_use_case.dart';
import 'package:axiom/src/features/categories/di/create_category_use_case_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

import '../../../../mocks/asset_repository_mock.dart';
import '../../../../mocks/category_repository_mock.dart';
import '../../../../mocks/get_settings_use_case_mock.dart';

void main() {
  test('provides the category creation service', () {
    final container = ProviderContainer(
      overrides: [
        validateCategoryBudgetCurrenciesServiceProvider.overrideWithValue(
          ValidateCategoryBudgetCurrenciesService(
            getValuationCurrency: GetValuationCurrencyService(
              getSettings: MockGetSettingsUseCase(),
              getAssetById: GetAssetByIdUseCase(MockAssetRepository()),
            ),
          ),
        ),
        createCategoryUseCaseProvider.overrideWithValue(
          CreateCategoryUseCase(
            repository: MockCategoryRepository(),
            clock: FixedClock(DateTime.utc(2026, 9, 20)),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(createCategoryServiceProvider),
      isA<CreateCategoryService>(),
    );
  });
}
