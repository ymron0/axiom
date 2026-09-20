@Tags(['di'])
library;

import 'package:axiom/src/application/di/services/update_category_service_provider.dart';
import 'package:axiom/src/application/di/services/validate_category_budget_currencies_service_provider.dart';
import 'package:axiom/src/application/services/get_valuation_currency_service.dart';
import 'package:axiom/src/application/services/update_category_service.dart';
import 'package:axiom/src/application/services/validate_category_budget_currencies_service.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_asset_by_id_use_case.dart';
import 'package:axiom/src/features/categories/application/use_cases/update_category_use_case.dart';
import 'package:axiom/src/features/categories/di/update_category_use_case_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

import '../../../../mocks/asset_repository_mock.dart';
import '../../../../mocks/category_repository_mock.dart';
import '../../../../mocks/get_settings_use_case_mock.dart';

void main() {
  test('provides the category update service', () {
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
        updateCategoryUseCaseProvider.overrideWithValue(
          UpdateCategoryUseCase(MockCategoryRepository()),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(updateCategoryServiceProvider),
      isA<UpdateCategoryService>(),
    );
  });
}
