@Tags(['application'])
library;

import 'package:axiom/src/application/failures/account_valuation_unavailable_failure.dart';
import 'package:axiom/src/application/services/get_account_valuation_service.dart';
import 'package:axiom/src/application/services/get_valuation_currency_service.dart';
import 'package:axiom/src/application/services/resolve_conversion_rate_service.dart';
import 'package:axiom/src/application/services/value_asset_amounts_service.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_repository_failure.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_asset_by_id_use_case.dart';
import 'package:axiom/src/features/assets/domain/services/asset_valuation_calculator.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/rates/domain/failures/rate_not_found_failure.dart';
import 'package:axiom/src/features/rates/domain/services/rate_conversion_service.dart';
import 'package:axiom/src/features/settings/domain/entities/settings.dart';
import 'package:decimal/decimal.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../fixtures/features/accounts/account_fixtures.dart';
import '../../../fixtures/features/assets/asset_fixtures.dart';
import '../../../fixtures/features/rates/rate_fixtures.dart';
import '../../../mocks/asset_repository_mock.dart';
import '../../../mocks/get_account_asset_balances_service_mock.dart';
import '../../../mocks/get_account_by_id_use_case_mock.dart';
import '../../../mocks/get_rate_at_use_case_mock.dart';
import '../../../mocks/get_settings_use_case_mock.dart';

void main() {
  late MockGetAccountByIdUseCase getAccountById;
  late MockGetAccountAssetBalancesService getAssetBalances;
  late MockGetSettingsUseCase getSettings;
  late MockAssetRepository assetRepository;
  late MockGetRateAtUseCase getRateAt;
  late GetAccountValuationService service;

  final chf = AssetId.fromString('asset-chf');
  final eur = AssetId.fromString('asset-eur');
  final usd = AssetId.fromString('asset-usd');
  final at = DateTime.utc(2026, 9, 20, 12);

  setUp(() {
    getAccountById = MockGetAccountByIdUseCase();
    getAssetBalances = MockGetAccountAssetBalancesService();
    getSettings = MockGetSettingsUseCase();
    assetRepository = MockAssetRepository();
    getRateAt = MockGetRateAtUseCase();

    when(
      () => getSettings(),
    ).thenAnswer((_) async => Success(Settings(valuationCurrencyId: chf)));

    when(
      () => assetRepository.getById(chf),
    ).thenAnswer((_) async => Success(currencyFixture(id: chf.value)));

    final getValuationCurrency = GetValuationCurrencyService(
      getSettings: getSettings,
      getAssetById: GetAssetByIdUseCase(assetRepository),
    );

    final valueAssetAmounts = ValueAssetAmountsService(
      resolveConversionRate: ResolveConversionRateService(
        getRateAt: getRateAt,
        canonicalBridgeAssetId: chf,
        rateConversion: const RateConversionService(),
      ),
      calculator: const AssetValuationCalculator(),
    );

    service = GetAccountValuationService(
      getAccountById: getAccountById,
      getAccountAssetBalances: getAssetBalances,
      getValuationCurrency: getValuationCurrency,
      valueAssetAmounts: valueAssetAmounts,
      clock: FixedClock(at),
    );
  });

  test('values a multi-asset account in the user valuation currency', () async {
    final account = accountFixture(
      id: 'multi-asset',
      denominationAssetId: chf.value,
    );

    final balances = [
      AssetAmount.incoming(assetId: chf, amount: Decimal.parse('20')),
      AssetAmount.incoming(assetId: usd, amount: Decimal.parse('100')),
    ];

    when(
      () => getAccountById(account.id),
    ).thenAnswer((_) async => Success(account));

    when(
      () => getAssetBalances(account.id),
    ).thenAnswer((_) async => Success<List<AssetAmount>>(balances));

    when(
      () => getRateAt(baseAssetId: usd, quoteAssetId: chf, at: at),
    ).thenAnswer(
      (_) async => Success(
        exchangeRateFixture(
          id: 'usd-chf',
          baseAssetId: usd.value,
          quoteAssetId: chf.value,
          rate: '0.9',
        ),
      ),
    );

    final result = await service(account.id);

    expect(result.isSuccess, isTrue);

    final valuation = result.valueOrNull!;

    // CHF 20 + USD 100 * 0.9 = CHF 110.
    expect(valuation.accountAmount.assetId, chf);
    expect(valuation.accountAmount.amount, Decimal.parse('110'));
    expect(valuation.valuationAmount.assetId, chf);
    expect(valuation.valuationAmount.amount, Decimal.parse('110'));
  });

  test(
    'returns denomination and valuation amounts in different currencies',
    () async {
      final account = accountFixture(
        id: 'eur-account',
        denominationAssetId: eur.value,
      );

      final balances = [
        AssetAmount.incoming(assetId: eur, amount: Decimal.parse('100')),
      ];

      when(
        () => getAccountById(account.id),
      ).thenAnswer((_) async => Success(account));

      when(
        () => getAssetBalances(account.id),
      ).thenAnswer((_) async => Success<List<AssetAmount>>(balances));

      when(
        () => getRateAt(baseAssetId: eur, quoteAssetId: chf, at: at),
      ).thenAnswer(
        (_) async => Success(
          exchangeRateFixture(
            id: 'eur-chf',
            baseAssetId: eur.value,
            quoteAssetId: chf.value,
            rate: '0.95',
          ),
        ),
      );

      final result = await service(account.id);

      final valuation = result.valueOrNull!;

      expect(valuation.accountAmount.assetId, eur);
      expect(valuation.accountAmount.amount, Decimal.parse('100'));

      expect(valuation.valuationAmount.assetId, chf);
      expect(valuation.valuationAmount.amount, Decimal.parse('95'));
    },
  );

  test('returns zero valuation for an empty account', () async {
    final account = accountFixture(
      id: 'empty-account',
      denominationAssetId: eur.value,
    );

    when(
      () => getAccountById(account.id),
    ).thenAnswer((_) async => Success(account));

    when(
      () => getAssetBalances(account.id),
    ).thenAnswer((_) async => const Success<List<AssetAmount>>([]));

    final result = await service(account.id);

    expect(result.isSuccess, isTrue);

    expect(result.valueOrNull!.accountAmount.assetId, eur);
    expect(result.valueOrNull!.accountAmount.amount, Decimal.zero);

    expect(result.valueOrNull!.valuationAmount.assetId, chf);
    expect(result.valueOrNull!.valuationAmount.amount, Decimal.zero);
  });

  test('returns not found when the account does not exist', () async {
    final accountId = AccountId.fromString('missing');

    when(
      () => getAccountById(accountId),
    ).thenAnswer((_) async => const Success(null));

    final result = await service(accountId);

    expect(result.failureOrNull?.message, contains(accountId.value));

    verifyNever(() => getAssetBalances(accountId));
  });

  test('propagates account lookup failure', () async {
    final accountId = AccountId.fromString('failed');

    const failure = AccountRepositoryFailure(message: 'lookup failed');

    when(() => getAccountById(accountId)).thenAnswer((_) async => failure);

    final result = await service(accountId);

    expect(result.failureOrNull, same(failure));
  });

  test('propagates asset-balance failure', () async {
    final account = accountFixture(id: 'failed-balances');

    const failure = AccountRepositoryFailure(message: 'balance lookup failed');

    when(
      () => getAccountById(account.id),
    ).thenAnswer((_) async => Success(account));

    when(() => getAssetBalances(account.id)).thenAnswer((_) async => failure);

    final result = await service(account.id);

    expect(result.failureOrNull, same(failure));
  });

  test(
    'returns unavailable when a required current rate does not exist',
    () async {
      final account = accountFixture(
        id: 'missing-rate',
        denominationAssetId: eur.value,
      );

      final balances = [
        AssetAmount.incoming(assetId: eur, amount: Decimal.parse('100')),
      ];

      when(
        () => getAccountById(account.id),
      ).thenAnswer((_) async => Success(account));

      when(
        () => getAssetBalances(account.id),
      ).thenAnswer((_) async => Success<List<AssetAmount>>(balances));

      when(
        () => getRateAt(baseAssetId: eur, quoteAssetId: chf, at: at),
      ).thenAnswer(
        (_) async => const RateNotFoundFailure(message: 'EUR/CHF missing'),
      );

      final result = await service(account.id);

      expect(result.failureOrNull, isA<AccountValuationUnavailableFailure>());
    },
  );
}
