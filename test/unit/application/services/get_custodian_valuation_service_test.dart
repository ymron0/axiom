@Tags(['application'])
library;

import 'package:axiom/src/application/services/get_account_valuation_service.dart';
import 'package:axiom/src/application/services/get_custodian_valuation_service.dart';
import 'package:axiom/src/application/services/get_valuation_currency_service.dart';
import 'package:axiom/src/application/services/resolve_conversion_rate_service.dart';
import 'package:axiom/src/application/services/value_asset_amounts_service.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/custodian_id.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_repository_failure.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_asset_by_id_use_case.dart';
import 'package:axiom/src/features/assets/domain/services/asset_valuation_calculator.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_repository_failure.dart';
import 'package:axiom/src/features/custodians/domain/services/custodian_aggregation_calculator.dart';
import 'package:axiom/src/features/rates/domain/services/rate_conversion_service.dart';
import 'package:axiom/src/features/settings/domain/entities/settings.dart';
import 'package:decimal/decimal.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../fixtures/features/accounts/account_fixtures.dart';
import '../../../fixtures/features/assets/asset_fixtures.dart';
import '../../../fixtures/features/custodians/custodian_fixtures.dart';
import '../../../mocks/asset_repository_mock.dart';
import '../../../mocks/get_account_asset_balances_service_mock.dart';
import '../../../mocks/get_account_by_id_use_case_mock.dart';
import '../../../mocks/get_accounts_by_custodian_id_use_case_mock.dart';
import '../../../mocks/get_custodian_by_id_use_case_mock.dart';
import '../../../mocks/get_rate_at_use_case_mock.dart';
import '../../../mocks/get_settings_use_case_mock.dart';

void main() {
  late MockGetCustodianByIdUseCase getCustodianById;
  late MockGetAccountsByCustodianIdUseCase getAccounts;
  late MockGetAccountByIdUseCase getAccountById;
  late MockGetAccountAssetBalancesService getAssetBalances;
  late MockGetSettingsUseCase getSettings;
  late MockAssetRepository assets;
  late MockGetRateAtUseCase getRateAt;
  late GetCustodianValuationService service;

  final valuationId = AssetId.fromString('valuation-chf');
  final now = DateTime.utc(2026, 9, 20);

  setUpAll(() {
    registerFallbackValue(CustodianId.fromString('fallback-custodian'));
    registerFallbackValue(AccountId.fromString('fallback-account'));
  });

  setUp(() {
    getCustodianById = MockGetCustodianByIdUseCase();
    getAccounts = MockGetAccountsByCustodianIdUseCase();
    getAccountById = MockGetAccountByIdUseCase();
    getAssetBalances = MockGetAccountAssetBalancesService();
    getSettings = MockGetSettingsUseCase();
    assets = MockAssetRepository();
    getRateAt = MockGetRateAtUseCase();

    when(() => getSettings()).thenAnswer(
      (_) async => Success(Settings(valuationCurrencyId: valuationId)),
    );

    when(
      () => assets.getById(valuationId),
    ).thenAnswer((_) async => Success(currencyFixture(id: valuationId.value)));

    final getValuationCurrency = GetValuationCurrencyService(
      getSettings: getSettings,
      getAssetById: GetAssetByIdUseCase(assets),
    );

    final valueAssetAmounts = ValueAssetAmountsService(
      resolveConversionRate: ResolveConversionRateService(
        getRateAt: getRateAt,
        canonicalBridgeAssetId: valuationId,
        rateConversion: const RateConversionService(),
      ),
      calculator: const AssetValuationCalculator(),
    );

    final accountValuation = GetAccountValuationService(
      getAccountById: getAccountById,
      getAccountAssetBalances: getAssetBalances,
      getValuationCurrency: getValuationCurrency,
      valueAssetAmounts: valueAssetAmounts,
      clock: FixedClock(now),
    );

    service = GetCustodianValuationService(
      getCustodianById: getCustodianById,
      getAccountsByCustodianId: getAccounts,
      getAccountValuation: accountValuation,
      getValuationCurrency: getValuationCurrency,
      calculator: const CustodianAggregationCalculator(),
    );
  });

  test('values and aggregates all custodian accounts', () async {
    // Given
    final custodian = custodianFixture(id: 'bank');

    final first = accountFixture(
      id: 'first',
      custodianId: custodian.id.value,
      denominationAssetId: valuationId.value,
    );

    final second = accountFixture(
      id: 'second',
      custodianId: custodian.id.value,
      denominationAssetId: valuationId.value,
    );

    when(
      () => getCustodianById(custodian.id),
    ).thenAnswer((_) async => Success(custodian));

    when(
      () => getAccounts(custodian.id),
    ).thenAnswer((_) async => Success([first, second]));

    when(
      () => getAccountById(first.id),
    ).thenAnswer((_) async => Success(first));

    when(
      () => getAccountById(second.id),
    ).thenAnswer((_) async => Success(second));

    when(() => getAssetBalances(first.id)).thenAnswer(
      (_) async => Success<List<AssetAmount>>([
        AssetAmount.incoming(
          assetId: valuationId,
          amount: Decimal.fromInt(100),
        ),
      ]),
    );

    when(() => getAssetBalances(second.id)).thenAnswer(
      (_) async => Success<List<AssetAmount>>([
        AssetAmount.incoming(assetId: valuationId, amount: Decimal.fromInt(25)),
      ]),
    );

    // When
    final result = await service(custodian.id);

    // Then
    expect(result.isSuccess, isTrue);

    final aggregation = result.valueOrNull!;

    expect(aggregation.custodianId, custodian.id);

    expect(aggregation.accountCount, 2);

    expect(aggregation.total.assetId, valuationId);

    expect(aggregation.total.amount, Decimal.fromInt(125));

    expect(aggregation.total.isIncoming, isTrue);

    verify(() => getAssetBalances(first.id)).called(1);

    verify(() => getAssetBalances(second.id)).called(1);
  });

  test('aggregates positive and negative account positions', () async {
    // Given
    final custodian = custodianFixture(id: 'mixed-bank');

    final positive = accountFixture(
      id: 'positive',
      custodianId: custodian.id.value,
      denominationAssetId: valuationId.value,
    );

    final negative = accountFixture(
      id: 'negative',
      custodianId: custodian.id.value,
      denominationAssetId: valuationId.value,
    );

    when(
      () => getCustodianById(custodian.id),
    ).thenAnswer((_) async => Success(custodian));

    when(
      () => getAccounts(custodian.id),
    ).thenAnswer((_) async => Success([positive, negative]));

    when(
      () => getAccountById(positive.id),
    ).thenAnswer((_) async => Success(positive));

    when(
      () => getAccountById(negative.id),
    ).thenAnswer((_) async => Success(negative));

    when(() => getAssetBalances(positive.id)).thenAnswer(
      (_) async => Success<List<AssetAmount>>([
        AssetAmount.incoming(
          assetId: valuationId,
          amount: Decimal.fromInt(100),
        ),
      ]),
    );

    when(() => getAssetBalances(negative.id)).thenAnswer(
      (_) async => Success<List<AssetAmount>>([
        AssetAmount.outgoing(assetId: valuationId, amount: Decimal.fromInt(30)),
      ]),
    );

    // When
    final result = await service(custodian.id);

    // Then
    expect(result.isSuccess, isTrue);

    final aggregation = result.valueOrNull!;

    expect(aggregation.accountCount, 2);

    expect(aggregation.total.assetId, valuationId);

    expect(aggregation.total.amount, Decimal.fromInt(70));

    expect(aggregation.total.isIncoming, isTrue);
  });

  test('returns zero for a custodian without accounts', () async {
    // Given
    final custodian = custodianFixture(id: 'empty-bank');

    when(
      () => getCustodianById(custodian.id),
    ).thenAnswer((_) async => Success(custodian));

    when(
      () => getAccounts(custodian.id),
    ).thenAnswer((_) async => const Success([]));

    // When
    final result = await service(custodian.id);

    // Then
    expect(result.isSuccess, isTrue);

    final aggregation = result.valueOrNull!;

    expect(aggregation.custodianId, custodian.id);

    expect(aggregation.accountCount, 0);

    expect(aggregation.total.assetId, valuationId);

    expect(aggregation.total.amount, Decimal.zero);

    expect(aggregation.total.isIncoming, isTrue);

    verifyNever(() => getAccountById(any()));

    verifyNever(() => getAssetBalances(any()));
  });

  test('returns not found without loading accounts', () async {
    // Given
    final id = custodianFixture(id: 'missing').id;

    when(
      () => getCustodianById(id),
    ).thenAnswer((_) async => const Success(null));

    // When
    final result = await service(id);

    // Then
    expect(result.failureOrNull?.message, contains(id.value));

    verifyNever(() => getAccounts(any()));

    verifyNever(() => getAssetBalances(any()));
  });

  test('propagates custodian lookup failure', () async {
    // Given
    final custodian = custodianFixture(id: 'failed');

    const failure = CustodianRepositoryFailure(
      message: 'custodian lookup failed',
    );

    when(() => getCustodianById(custodian.id)).thenAnswer((_) async => failure);

    // When
    final result = await service(custodian.id);

    // Then
    expect(result.failureOrNull, same(failure));

    verifyNever(() => getAccounts(any()));

    verifyNever(() => getAssetBalances(any()));
  });

  test('propagates account-list lookup failure', () async {
    // Given
    final custodian = custodianFixture(id: 'failed-accounts');

    const failure = AccountRepositoryFailure(message: 'accounts lookup failed');

    when(
      () => getCustodianById(custodian.id),
    ).thenAnswer((_) async => Success(custodian));

    when(() => getAccounts(custodian.id)).thenAnswer((_) async => failure);

    // When
    final result = await service(custodian.id);

    // Then
    expect(result.failureOrNull, same(failure));

    verifyNever(() => getAssetBalances(any()));
  });

  test('propagates account valuation failure', () async {
    // Given
    final custodian = custodianFixture(id: 'valuation-failure');

    final account = accountFixture(
      id: 'account-failure',
      custodianId: custodian.id.value,
      denominationAssetId: valuationId.value,
    );

    const failure = AccountRepositoryFailure(message: 'account lookup failed');

    when(
      () => getCustodianById(custodian.id),
    ).thenAnswer((_) async => Success(custodian));

    when(
      () => getAccounts(custodian.id),
    ).thenAnswer((_) async => Success([account]));

    when(() => getAccountById(account.id)).thenAnswer((_) async => failure);

    // When
    final result = await service(custodian.id);

    // Then
    expect(result.failureOrNull, same(failure));

    verifyNever(() => getAssetBalances(account.id));
  });
}
