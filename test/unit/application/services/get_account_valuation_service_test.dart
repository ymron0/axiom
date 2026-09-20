@Tags(['application'])
library;

import 'package:axiom/src/application/failures/account_valuation_unavailable_failure.dart';
import 'package:axiom/src/application/services/asset_valuation_service.dart';
import 'package:axiom/src/application/services/get_account_valuation_service.dart';
import 'package:axiom/src/application/services/get_valuation_currency_service.dart';
import 'package:axiom/src/application/services/resolve_conversion_rate_service.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
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
import '../../../mocks/asset_repository_mock.dart';
import '../../../mocks/get_account_balance_service_mock.dart';
import '../../../mocks/get_account_by_id_use_case_mock.dart';
import '../../../mocks/get_rate_at_use_case_mock.dart';
import '../../../mocks/get_settings_use_case_mock.dart';

void main() {
  late MockGetAccountByIdUseCase getAccountById;
  late MockGetAccountBalanceService getAccountBalance;
  late MockGetSettingsUseCase getSettings;
  late MockAssetRepository assetRepository;
  late MockGetRateAtUseCase getRateAt;
  late GetAccountValuationService service;

  final valuationId = AssetId.fromString('valuation-chf');
  final at = DateTime.utc(2026, 9, 20, 12);

  setUpAll(() {
    registerFallbackValue(AccountId.fromString('fallback-account'));
  });

  setUp(() {
    getAccountById = MockGetAccountByIdUseCase();
    getAccountBalance = MockGetAccountBalanceService();
    getSettings = MockGetSettingsUseCase();
    assetRepository = MockAssetRepository();
    getRateAt = MockGetRateAtUseCase();

    when(() => getSettings()).thenAnswer(
      (_) async => Success(Settings(valuationCurrencyId: valuationId)),
    );
    when(
      () => assetRepository.getById(valuationId),
    ).thenAnswer((_) async => Success(currencyFixture(id: valuationId.value)));

    service = GetAccountValuationService(
      getAccountById: getAccountById,
      getAccountBalance: getAccountBalance,
      assetValuation: AssetValuationService(
        getValuationCurrency: GetValuationCurrencyService(
          getSettings: getSettings,
          getAssetById: GetAssetByIdUseCase(assetRepository),
        ),
        resolveConversionRate: ResolveConversionRateService(
          getRateAt: getRateAt,
          canonicalBridgeAssetId: valuationId,
          rateConversion: const RateConversionService(),
        ),
        calculator: const AssetValuationCalculator(),
      ),
      clock: FixedClock(at),
    );
  });

  test(
    'returns an incoming account valuation for a positive balance',
    () async {
      final account = accountFixture(
        id: 'account-positive',
        denominationAssetId: valuationId.value,
      );
      when(
        () => getAccountById(account.id),
      ).thenAnswer((_) async => Success(account));
      when(
        () => getAccountBalance(account.id),
      ).thenAnswer((_) async => Success(Decimal.fromInt(125)));

      final result = await service(account.id);

      final valuation = result.valueOrNull!;
      expect(
        valuation.accountAmount,
        AssetAmount.incoming(
          assetId: valuationId,
          amount: Decimal.fromInt(125),
        ),
      );
      expect(valuation.valuationAmount.amount, Decimal.fromInt(125));
      expect(valuation.valuationAmount.isIncoming, isTrue);
      verify(() => getAccountBalance(account.id)).called(1);
    },
  );

  test('represents a negative balance as outgoing', () async {
    final account = accountFixture(
      id: 'account-negative',
      denominationAssetId: valuationId.value,
    );
    when(
      () => getAccountById(account.id),
    ).thenAnswer((_) async => Success(account));
    when(
      () => getAccountBalance(account.id),
    ).thenAnswer((_) async => Success(Decimal.fromInt(-30)));

    final result = await service(account.id);

    expect(result.valueOrNull!.accountAmount.isOutgoing, isTrue);
    expect(result.valueOrNull!.accountAmount.amount, Decimal.fromInt(30));
    expect(result.valueOrNull!.valuationAmount.isOutgoing, isTrue);
  });

  test(
    'returns not found when the account lookup succeeds with null',
    () async {
      final accountId = accountFixture(id: 'missing').id;
      when(
        () => getAccountById(accountId),
      ).thenAnswer((_) async => const Success(null));

      final result = await service(accountId);

      expect(result.failureOrNull?.message, contains(accountId.value));
      verifyNever(() => getAccountBalance(any()));
    },
  );

  test('propagates account and balance failures', () async {
    final account = accountFixture(id: 'failed-account');
    const lookupFailure = AccountRepositoryFailure(message: 'lookup failed');
    when(
      () => getAccountById(account.id),
    ).thenAnswer((_) async => lookupFailure);

    expect((await service(account.id)).failureOrNull, same(lookupFailure));

    when(
      () => getAccountById(account.id),
    ).thenAnswer((_) async => Success(account));
    const balanceFailure = AccountRepositoryFailure(message: 'balance failed');
    when(
      () => getAccountBalance(account.id),
    ).thenAnswer((_) async => balanceFailure);

    expect((await service(account.id)).failureOrNull, same(balanceFailure));
  });

  test(
    'returns unavailable when a cross-asset valuation has no rate',
    () async {
      final account = accountFixture(
        id: 'account-unknown',
        denominationAssetId: 'asset-eur',
      );
      when(
        () => getAccountById(account.id),
      ).thenAnswer((_) async => Success(account));
      when(
        () => getAccountBalance(account.id),
      ).thenAnswer((_) async => Success(Decimal.fromInt(20)));
      when(
        () => getRateAt(
          baseAssetId: AssetId.fromString('asset-eur'),
          quoteAssetId: valuationId,
          at: at,
        ),
      ).thenAnswer((_) async => const RateNotFoundFailure());

      final result = await service(account.id);

      expect(result.failureOrNull, isA<AccountValuationUnavailableFailure>());
    },
  );
}
