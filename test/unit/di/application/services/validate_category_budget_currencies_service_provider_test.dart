@Tags(['di'])
library;

import 'package:axiom/src/application/di/services/get_valuation_currency_service_provider.dart';
import 'package:axiom/src/application/di/services/validate_category_budget_currencies_service_provider.dart';
import 'package:axiom/src/application/services/get_valuation_currency_service.dart';
import 'package:axiom/src/application/services/validate_category_budget_currencies_service.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_asset_by_id_use_case.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

import '../../../../mocks/asset_repository_mock.dart';
import '../../../../mocks/get_settings_use_case_mock.dart';

void main() {
  test('provides the category budget validator', () {
    final container = ProviderContainer(
      overrides: [
        getValuationCurrencyServiceProvider.overrideWithValue(
          GetValuationCurrencyService(
            getSettings: MockGetSettingsUseCase(),
            getAssetById: GetAssetByIdUseCase(MockAssetRepository()),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(validateCategoryBudgetCurrenciesServiceProvider),
      isA<ValidateCategoryBudgetCurrenciesService>(),
    );
  });
}
