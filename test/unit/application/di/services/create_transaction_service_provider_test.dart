@Tags(['application'])
library;

import 'package:axiom/src/application/di/services/create_transaction_service_provider.dart';
import 'package:axiom/src/application/di/services/validate_transaction_allocations_service_provider.dart';
import 'package:axiom/src/application/di/services/validate_transaction_asset_semantics_service_provider.dart';
import 'package:axiom/src/application/di/services/validate_transaction_tags_service_provider.dart';
import 'package:axiom/src/application/services/create_transaction_service.dart';
import 'package:axiom/src/application/services/get_valuation_currency_service.dart';
import 'package:axiom/src/application/services/validate_transaction_allocations_service.dart';
import 'package:axiom/src/application/services/validate_transaction_asset_semantics_service.dart';
import 'package:axiom/src/application/services/validate_transaction_tags_service.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_asset_by_id_use_case.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_assets_by_ids_use_case.dart';
import 'package:axiom/src/features/settings/application/use_cases/get_settings_use_case.dart';
import 'package:axiom/src/features/tags/application/use_cases/get_tags_by_ids_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/create_transaction_use_case.dart';
import 'package:axiom/src/features/transactions/di/create_transaction_use_case_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

import '../../../../mocks/get_category_by_id_use_case_mock.dart';
import '../../../../mocks/get_jar_by_id_use_case_mock.dart';
import '../../../../mocks/asset_repository_mock.dart';
import '../../../../mocks/settings_repository_mock.dart';
import '../../../../mocks/tag_repository_mock.dart';
import '../../../../mocks/transaction_repository_mock.dart';

void main() {
  group('createTransactionServiceProvider', () {
    test('provides the create transaction service', () {
      final container = ProviderContainer(
        overrides: [
          createTransactionUseCaseProvider.overrideWithValue(
            CreateTransactionUseCase(repository: MockTransactionRepository()),
          ),
          validateTransactionAssetSemanticsServiceProvider.overrideWithValue(
            ValidateTransactionAssetSemanticsService(
              getAssetsByIds: GetAssetsByIdsUseCase(MockAssetRepository()),
              getValuationCurrency: GetValuationCurrencyService(
                getSettings: GetSettingsUseCase(MockSettingsRepository()),
                getAssetById: GetAssetByIdUseCase(MockAssetRepository()),
              ),
            ),
          ),
          validateTransactionAllocationsServiceProvider.overrideWithValue(
            ValidateTransactionAllocationsService(
              getCategoryById: MockGetCategoryByIdUseCase(),
              getJarById: MockGetJarByIdUseCase(),
            ),
          ),
          validateTransactionTagsServiceProvider.overrideWithValue(
            ValidateTransactionTagsService(
              getTagsByIds: GetTagsByIdsUseCase(MockTagRepository()),
            ),
          ),
        ],
      );

      addTearDown(container.dispose);

      final service = container.read(createTransactionServiceProvider);

      expect(service, isA<CreateTransactionService>());
    });
  });
}
