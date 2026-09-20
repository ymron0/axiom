@Tags(['application'])
library;

import 'package:axiom/src/application/services/create_category_service.dart';
import 'package:axiom/src/application/services/get_valuation_currency_service.dart';
import 'package:axiom/src/application/services/validate_category_budget_currencies_service.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_asset_by_id_use_case.dart';
import 'package:axiom/src/features/categories/application/use_cases/create_category_use_case.dart';
import 'package:axiom/src/features/categories/domain/entities/category.dart';
import 'package:axiom/src/features/categories/domain/failures/category_already_exists_failure.dart';
import 'package:axiom/src/features/settings/application/use_cases/get_settings_use_case.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../fixtures/features/categories/create_category_command_fixtures.dart';
import '../../../fixtures/features/categories/category_fixtures.dart';
import '../../../mocks/asset_repository_mock.dart';
import '../../../mocks/category_repository_mock.dart';
import '../../../mocks/settings_repository_mock.dart';

void main() {
  late MockCategoryRepository categoryRepository;
  late MockAssetRepository assetRepository;
  late MockSettingsRepository settingsRepository;
  late CreateCategoryService service;

  setUpAll(() {
    registerFallbackValue(categoryFixture(id: 'fallback-category'));
  });

  setUp(() {
    categoryRepository = MockCategoryRepository();
    assetRepository = MockAssetRepository();
    settingsRepository = MockSettingsRepository();
    final validator = ValidateCategoryBudgetCurrenciesService(
      getValuationCurrency: GetValuationCurrencyService(
        getSettings: GetSettingsUseCase(settingsRepository),
        getAssetById: GetAssetByIdUseCase(assetRepository),
      ),
    );
    service = CreateCategoryService(
      validateBudgetCurrencies: validator,
      createCategory: CreateCategoryUseCase(
        repository: categoryRepository,
        clock: FixedClock(DateTime.utc(2026, 9, 20)),
      ),
    );
  });

  test('validates and creates a category', () async {
    final command = createCategoryCommandFixture();
    when(
      () => categoryRepository.create(any()),
    ).thenAnswer((_) async => const Success(null));

    final result = await service(command);

    expect(result.valueOrNull, isA<Category>());
    expect(result.valueOrNull!.name, 'Test Category');
    verify(() => categoryRepository.create(any())).called(1);
    verifyNever(() => settingsRepository.get());
  });

  test('returns the creation failure and does not hide it', () async {
    const failure = CategoryAlreadyExistsFailure(message: 'duplicate');
    when(
      () => categoryRepository.create(any()),
    ).thenAnswer((_) async => failure);

    final result = await service(createCategoryCommandFixture());

    expect(result.failureOrNull, same(failure));
  });
}
