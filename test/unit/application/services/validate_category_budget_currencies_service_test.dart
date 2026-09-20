@Tags(['application'])
library;

import 'package:axiom/src/application/failures/invalid_valuation_currency_failure.dart';
import 'package:axiom/src/application/services/get_valuation_currency_service.dart';
import 'package:axiom/src/application/services/validate_category_budget_currencies_service.dart';
import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_asset_by_id_use_case.dart';
import 'package:axiom/src/features/assets/domain/enums/asset_amount_direction.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/categories/domain/enums/budget_period.dart';
import 'package:axiom/src/features/categories/domain/value_objects/category_budget.dart';
import 'package:axiom/src/features/settings/domain/entities/settings.dart';
import 'package:axiom/src/features/settings/domain/failures/settings_repository_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

import '../../../fixtures/features/assets/asset_fixtures.dart';
import '../../../mocks/asset_repository_mock.dart';
import '../../../mocks/get_settings_use_case_mock.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(AssetId.fromString('fallback-asset'));
  });

  late MockGetSettingsUseCase getSettings;
  late MockAssetRepository repository;
  late ValidateCategoryBudgetCurrenciesService service;
  final valuationId = AssetId.fromString('valuation-chf');

  setUp(() {
    getSettings = MockGetSettingsUseCase();
    repository = MockAssetRepository();
    service = ValidateCategoryBudgetCurrenciesService(
      getValuationCurrency: GetValuationCurrencyService(
        getSettings: getSettings,
        getAssetById: GetAssetByIdUseCase(repository),
      ),
    );
    when(() => repository.getById(any())).thenAnswer((invocation) async {
      final id = invocation.positionalArguments.single as AssetId;
      return Success(currencyFixture(id: id.value));
    });
  });

  test('accepts empty budgets without loading settings', () async {
    final result = await service(const []);

    expect(result.isSuccess, isTrue);
    verifyNever(() => getSettings());
  });

  test('accepts budgets using the configured valuation currency', () async {
    when(() => getSettings()).thenAnswer(
      (_) async => Success(Settings(valuationCurrencyId: valuationId)),
    );

    final result = await service([_budget(valuationId)]);

    expect(result.isSuccess, isTrue);
  });

  test('rejects a budget using another asset', () async {
    when(() => getSettings()).thenAnswer(
      (_) async => Success(Settings(valuationCurrencyId: valuationId)),
    );
    final otherId = AssetId.fromString('valuation-eur');

    final result = await service([_budget(otherId)]);

    expect(result.failureOrNull, isA<InvalidValuationCurrencyFailure>());
    expect(result.failureOrNull?.message, contains(otherId.value));
  });

  test('propagates valuation-currency lookup failures', () async {
    const failure = SettingsRepositoryFailure(message: 'lookup failed');
    when(() => getSettings()).thenAnswer((_) async => failure);

    final result = await service([_budget(valuationId)]);

    expect(result.failureOrNull, same(failure));
  });
}

CategoryBudget _budget(AssetId assetId) {
  return CategoryBudget(
    limit: AssetAmount(
      assetId: assetId,
      amount: Decimal.fromInt(100),
      direction: AssetAmountDirection.outgoing,
    ),
    period: BudgetPeriod.monthly,
    effectiveFrom: CalendarDate(2026, 1, 1),
  );
}
