@Tags(['application'])
library;

import 'package:axiom/src/application/services/asset_valuation_service.dart';
import 'package:axiom/src/application/services/get_account_valuation_service.dart';
import 'package:axiom/src/application/services/get_custodian_valuation_service.dart';
import 'package:axiom/src/application/services/get_valuation_currency_service.dart';
import 'package:axiom/src/application/services/resolve_conversion_rate_service.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/custodian_id.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_repository_failure.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_repository_failure.dart';
import 'package:axiom/src/features/custodians/domain/services/custodian_aggregation_calculator.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_asset_by_id_use_case.dart';
import 'package:axiom/src/features/assets/domain/services/asset_valuation_calculator.dart';
import 'package:axiom/src/features/rates/domain/services/rate_conversion_service.dart';
import 'package:axiom/src/features/settings/domain/entities/settings.dart';
import 'package:decimal/decimal.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../fixtures/features/accounts/account_fixtures.dart';
import '../../../fixtures/features/assets/asset_fixtures.dart';
import '../../../fixtures/features/custodians/custodian_fixtures.dart';
import '../../../mocks/asset_repository_mock.dart';
import '../../../mocks/get_account_balance_service_mock.dart';
import '../../../mocks/get_account_by_id_use_case_mock.dart';
import '../../../mocks/get_accounts_by_custodian_id_use_case_mock.dart';
import '../../../mocks/get_custodian_by_id_use_case_mock.dart';
import '../../../mocks/get_rate_at_use_case_mock.dart';
import '../../../mocks/get_settings_use_case_mock.dart';

void main() {
  late MockGetCustodianByIdUseCase getCustodianById;
  late MockGetAccountsByCustodianIdUseCase getAccounts;
  late MockGetAccountByIdUseCase getAccountById;
  late MockGetAccountBalanceService getBalance;
  late MockGetSettingsUseCase getSettings;
  late MockAssetRepository assets;
  late MockGetRateAtUseCase getRateAt;
  late GetCustodianValuationService service;

  final valuationId = AssetId.fromString('valuation-chf');

  setUpAll(() {
    registerFallbackValue(CustodianId.fromString('fallback-custodian'));
  });

  setUp(() {
    getCustodianById = MockGetCustodianByIdUseCase();
    getAccounts = MockGetAccountsByCustodianIdUseCase();
    getAccountById = MockGetAccountByIdUseCase();
    getBalance = MockGetAccountBalanceService();
    getSettings = MockGetSettingsUseCase();
    assets = MockAssetRepository();
    getRateAt = MockGetRateAtUseCase();

    when(() => getSettings()).thenAnswer(
      (_) async => Success(Settings(valuationCurrencyId: valuationId)),
    );
    when(
      () => assets.getById(valuationId),
    ).thenAnswer((_) async => Success(currencyFixture(id: valuationId.value)));
    final currency = GetValuationCurrencyService(
      getSettings: getSettings,
      getAssetById: GetAssetByIdUseCase(assets),
    );
    final accountValuation = GetAccountValuationService(
      getAccountById: getAccountById,
      getAccountBalance: getBalance,
      assetValuation: AssetValuationService(
        getValuationCurrency: currency,
        resolveConversionRate: ResolveConversionRateService(
          getRateAt: getRateAt,
          canonicalBridgeAssetId: valuationId,
          rateConversion: const RateConversionService(),
        ),
        calculator: const AssetValuationCalculator(),
      ),
      clock: FixedClock(DateTime.utc(2026, 9, 20)),
    );
    service = GetCustodianValuationService(
      getCustodianById: getCustodianById,
      getAccountsByCustodianId: getAccounts,
      getAccountValuation: accountValuation,
      getValuationCurrency: currency,
      calculator: const CustodianAggregationCalculator(),
    );
  });

  test('values and aggregates all custodian accounts', () async {
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
    when(
      () => getBalance(first.id),
    ).thenAnswer((_) async => Success(Decimal.fromInt(100)));
    when(
      () => getBalance(second.id),
    ).thenAnswer((_) async => Success(Decimal.fromInt(25)));

    final result = await service(custodian.id);

    expect(result.valueOrNull!.custodianId, custodian.id);
    expect(result.valueOrNull!.accountCount, 2);
    expect(result.valueOrNull!.total.amount, Decimal.fromInt(125));
    expect(result.valueOrNull!.total.assetId, valuationId);
  });

  test('returns not found without loading accounts', () async {
    final id = custodianFixture(id: 'missing').id;
    when(
      () => getCustodianById(id),
    ).thenAnswer((_) async => const Success(null));

    final result = await service(id);

    expect(result.failureOrNull?.message, contains(id.value));
    verifyNever(() => getAccounts(any()));
  });

  test('propagates custodian and account lookup failures', () async {
    final custodian = custodianFixture(id: 'failed');
    const custodianFailure = CustodianRepositoryFailure(message: 'custodian');
    when(
      () => getCustodianById(custodian.id),
    ).thenAnswer((_) async => custodianFailure);
    expect((await service(custodian.id)).failureOrNull, same(custodianFailure));

    when(
      () => getCustodianById(custodian.id),
    ).thenAnswer((_) async => Success(custodian));
    const accountsFailure = AccountRepositoryFailure(message: 'accounts');
    when(
      () => getAccounts(custodian.id),
    ).thenAnswer((_) async => accountsFailure);
    expect((await service(custodian.id)).failureOrNull, same(accountsFailure));
  });
}
