@Tags(['application'])
library;

import 'package:axiom/src/application/services/get_valuation_currency_service.dart';
import 'package:axiom/src/application/services/update_category_service.dart';
import 'package:axiom/src/application/services/validate_category_budget_currencies_service.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_asset_by_id_use_case.dart';
import 'package:axiom/src/features/categories/application/use_cases/update_category_use_case.dart';
import 'package:axiom/src/features/categories/domain/failures/category_repository_failure.dart';
import 'package:axiom/src/features/settings/application/use_cases/get_settings_use_case.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../fixtures/features/categories/category_fixtures.dart';
import '../../../mocks/asset_repository_mock.dart';
import '../../../mocks/category_repository_mock.dart';
import '../../../mocks/settings_repository_mock.dart';

void main() {
  late MockCategoryRepository categoryRepository;
  late UpdateCategoryService service;

  setUp(() {
    categoryRepository = MockCategoryRepository();
    final validator = ValidateCategoryBudgetCurrenciesService(
      getValuationCurrency: GetValuationCurrencyService(
        getSettings: GetSettingsUseCase(MockSettingsRepository()),
        getAssetById: GetAssetByIdUseCase(MockAssetRepository()),
      ),
    );
    service = UpdateCategoryService(
      validateBudgetCurrencies: validator,
      updateCategory: UpdateCategoryUseCase(categoryRepository),
    );
  });

  test('validates and updates an active top-level category', () async {
    final category = categoryFixture(id: 'groceries');
    when(
      () => categoryRepository.getByParentId(category.id),
    ).thenAnswer((_) async => const Success([]));
    when(
      () => categoryRepository.update(category),
    ).thenAnswer((_) async => const Success(null));

    final result = await service(category);

    expect(result.isSuccess, isTrue);
    verify(() => categoryRepository.update(category)).called(1);
  });

  test('propagates update failures', () async {
    final category = categoryFixture(id: 'failed');
    when(
      () => categoryRepository.getByParentId(category.id),
    ).thenAnswer((_) async => const Success([]));
    const failure = CategoryRepositoryFailure(message: 'write failed');
    when(
      () => categoryRepository.update(category),
    ).thenAnswer((_) async => failure);

    final result = await service(category);

    expect(result.failureOrNull, same(failure));
  });
}
