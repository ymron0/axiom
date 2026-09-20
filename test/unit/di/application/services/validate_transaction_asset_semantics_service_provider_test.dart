@Tags(['di'])
library;

import 'package:axiom/src/application/di/services/get_valuation_currency_service_provider.dart';
import 'package:axiom/src/application/di/services/validate_transaction_asset_semantics_service_provider.dart';
import 'package:axiom/src/application/services/get_valuation_currency_service.dart';
import 'package:axiom/src/application/services/validate_transaction_asset_semantics_service.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_asset_by_id_use_case.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_assets_by_ids_use_case.dart';
import 'package:axiom/src/features/assets/di/get_assets_by_ids_use_case_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

import '../../../../mocks/asset_repository_mock.dart';
import '../../../../mocks/get_settings_use_case_mock.dart';

void main() {
  test('provides the transaction asset-semantics validator', () {
    final container = ProviderContainer(
      overrides: [
        getAssetsByIdsUseCaseProvider.overrideWithValue(
          GetAssetsByIdsUseCase(MockAssetRepository()),
        ),
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
      container.read(validateTransactionAssetSemanticsServiceProvider),
      isA<ValidateTransactionAssetSemanticsService>(),
    );
  });
}
