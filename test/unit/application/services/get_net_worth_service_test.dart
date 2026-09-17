@Tags(['application'])
library;

import 'package:axiom/src/application/failures/invalid_valuation_currency_failure.dart';
import 'package:axiom/src/application/services/asset_valuation_service.dart';
import 'package:axiom/src/application/services/get_net_worth_service.dart';
import 'package:axiom/src/application/services/resolve_conversion_rate_service.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/application/use_cases/get_accounts_use_case.dart';
import 'package:axiom/src/features/accounts/domain/entities/account.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_not_found_failure.dart';
import 'package:axiom/src/features/assets/domain/services/asset_valuation_calculator.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/rates/domain/failures/rate_not_found_failure.dart';
import 'package:axiom/src/features/rates/domain/services/rate_conversion_service.dart';
import 'package:axiom/src/features/settings/domain/entities/settings.dart';
import 'package:axiom/src/features/settings/domain/failures/settings_not_initialized_failure.dart';
import 'package:decimal/decimal.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../fixtures/features/accounts/account_fixtures.dart';
import '../../../fixtures/features/rates/rate_fixtures.dart';
import '../../../mocks/account_repository_mock.dart';
import '../../../mocks/get_account_balance_service_mock.dart';
import '../../../mocks/get_settings_use_case_mock.dart';
import '../../../mocks/rate_repository_mock.dart';

void main() {
  group('GetNetWorthService', () {
    late MockGetSettingsUseCase getSettings;
    late MockAccountRepository accountRepository;
    late MockGetAccountBalanceService getAccountBalance;
    late MockRateRepository rateRepository;

    late GetAccountsUseCase getAccounts;
    late AssetValuationService assetValuation;
    late GetNetWorthService service;

    late AssetId usd;
    late AssetId eur;
    late AssetId gbp;
    late DateTime now;

    setUpAll(() {
      registerFallbackValue(
        AccountId.fromString('fallback-account'),
      );
    });

    setUp(() {
      getSettings = MockGetSettingsUseCase();
      accountRepository = MockAccountRepository();
      getAccountBalance = MockGetAccountBalanceService();
      rateRepository = MockRateRepository();

      usd = AssetId.fromString('asset-usd');
      eur = AssetId.fromString('asset-eur');
      gbp = AssetId.fromString('asset-gbp');

      now = DateTime.utc(2026, 9, 17, 8, 30);

      getAccounts = GetAccountsUseCase(accountRepository);

      assetValuation = AssetValuationService(
        getSettings: getSettings,
        resolveConversionRate: ResolveConversionRateService(
          repository: rateRepository,
          canonicalBridgeAssetId: usd,
          rateConversion: const RateConversionService(),
        ),
        calculator: const AssetValuationCalculator(),
      );

      service = GetNetWorthService(
        getSettings: getSettings,
        getAccounts: getAccounts,
        getAccountBalance: getAccountBalance,
        assetValuation: assetValuation,
        clock: FixedClock(now),
      );
    });

    Account createAccount({
      required String id,
      required AssetId denominationAssetId,
    }) {
      return accountFixture(
        id: id,
        denominationAssetId: denominationAssetId.value,
      );
    }

    void stubSettings(AssetId valuationCurrencyId) {
      when(
        () => getSettings(),
      ).thenAnswer(
        (_) async => Success(
          Settings(
            valuationCurrencyId: valuationCurrencyId,
          ),
        ),
      );
    }

    void stubAccounts(List<Account> accounts) {
      when(
        () => accountRepository.getAll(),
      ).thenAnswer(
        (_) async => Success<List<Account>>(accounts),
      );
    }

    void stubBalance(
      Account account,
      String balance,
    ) {
      when(
        () => getAccountBalance(account.id),
      ).thenAnswer(
        (_) async => Success(
          Decimal.parse(balance),
        ),
      );
    }

    void stubUsdRate({
      required AssetId sourceAssetId,
      required String rate,
    }) {
      final exchangeRate = exchangeRateFixture(
        id: 'rate-${sourceAssetId.value}-usd',
        baseAssetId: sourceAssetId.value,
        quoteAssetId: usd.value,
        rate: rate,
      );

      when(
        () => rateRepository.getAtOrBefore(
          baseAssetId: sourceAssetId,
          quoteAssetId: usd,
          effectiveAt: now,
        ),
      ).thenAnswer(
        (_) async => Success(exchangeRate),
      );
    }

    void expectAmount(
      AssetAmount? actual, {
      required AssetId assetId,
      required String amount,
      required bool incoming,
    }) {
      expect(actual, isNotNull);
      expect(actual!.assetId, assetId);
      expect(actual.amount, Decimal.parse(amount));

      if (incoming) {
        expect(actual.isIncoming, isTrue);
        expect(actual.isOutgoing, isFalse);
      } else {
        expect(actual.isIncoming, isFalse);
        expect(actual.isOutgoing, isTrue);
      }
    }

    test(
      'returns zero in the valuation currency when there are no accounts',
      () async {
        // Given
        stubSettings(usd);
        stubAccounts(const []);

        // When
        final result = await service();

        // Then
        expect(result.failureOrNull, isNull);

        expectAmount(
          result.valueOrNull,
          assetId: usd,
          amount: '0',
          incoming: true,
        );

        verify(() => getSettings()).called(1);
        verify(() => accountRepository.getAll()).called(1);

        verifyNever(
          () => getAccountBalance(any()),
        );

        verifyZeroInteractions(rateRepository);
      },
    );

    test(
      'uses a valuation-currency account balance without resolving a rate',
      () async {
        // Given
        final account = createAccount(
          id: 'account-usd',
          denominationAssetId: usd,
        );

        stubSettings(usd);
        stubAccounts([account]);
        stubBalance(account, '125.40');

        // When
        final result = await service();

        // Then
        expect(result.failureOrNull, isNull);

        expectAmount(
          result.valueOrNull,
          assetId: usd,
          amount: '125.40',
          incoming: true,
        );

        verify(
          () => getAccountBalance(account.id),
        ).called(1);

        verifyZeroInteractions(rateRepository);
      },
    );

    test(
      'aggregates accounts sharing an asset before valuation',
      () async {
        // Given
        final first = createAccount(
          id: 'account-eur-1',
          denominationAssetId: eur,
        );

        final second = createAccount(
          id: 'account-eur-2',
          denominationAssetId: eur,
        );

        stubSettings(usd);
        stubAccounts([first, second]);

        stubBalance(first, '100.25');
        stubBalance(second, '-20.10');

        stubUsdRate(
          sourceAssetId: eur,
          rate: '1.25',
        );

        // EUR 100.25 - EUR 20.10 = EUR 80.15
        // EUR 80.15 * 1.25 = USD 100.1875

        // When
        final result = await service();

        // Then
        expect(result.failureOrNull, isNull);

        expectAmount(
          result.valueOrNull,
          assetId: usd,
          amount: '100.1875',
          incoming: true,
        );

        verify(
          () => getAccountBalance(first.id),
        ).called(1);

        verify(
          () => getAccountBalance(second.id),
        ).called(1);

        verify(
          () => rateRepository.getAtOrBefore(
            baseAssetId: eur,
            quoteAssetId: usd,
            effectiveAt: now,
          ),
        ).called(1);
      },
    );

    test(
      'combines separately valued asset aggregates into net worth',
      () async {
        // Given
        final usdAccount = createAccount(
          id: 'account-usd',
          denominationAssetId: usd,
        );

        final eurAccount = createAccount(
          id: 'account-eur',
          denominationAssetId: eur,
        );

        final gbpAccount = createAccount(
          id: 'account-gbp',
          denominationAssetId: gbp,
        );

        stubSettings(usd);
        stubAccounts([
          usdAccount,
          eurAccount,
          gbpAccount,
        ]);

        stubBalance(usdAccount, '100');
        stubBalance(eurAccount, '50');
        stubBalance(gbpAccount, '25');

        stubUsdRate(
          sourceAssetId: eur,
          rate: '1.2',
        );

        stubUsdRate(
          sourceAssetId: gbp,
          rate: '1.4',
        );

        // USD 100
        // EUR 50 * 1.2 = USD 60
        // GBP 25 * 1.4 = USD 35
        // Total = USD 195

        // When
        final result = await service();

        // Then
        expect(result.failureOrNull, isNull);

        expectAmount(
          result.valueOrNull,
          assetId: usd,
          amount: '195',
          incoming: true,
        );

        verify(
          () => rateRepository.getAtOrBefore(
            baseAssetId: eur,
            quoteAssetId: usd,
            effectiveAt: now,
          ),
        ).called(1);

        verify(
          () => rateRepository.getAtOrBefore(
            baseAssetId: gbp,
            quoteAssetId: usd,
            effectiveAt: now,
          ),
        ).called(1);
      },
    );

    test(
      'returns outgoing net worth when liabilities exceed assets',
      () async {
        // Given
        final cashAccount = createAccount(
          id: 'account-cash',
          denominationAssetId: usd,
        );

        final liabilityAccount = createAccount(
          id: 'account-liability',
          denominationAssetId: eur,
        );

        stubSettings(usd);
        stubAccounts([
          cashAccount,
          liabilityAccount,
        ]);

        stubBalance(cashAccount, '50');
        stubBalance(liabilityAccount, '-100');

        stubUsdRate(
          sourceAssetId: eur,
          rate: '1.2',
        );

        // USD +50
        // EUR -100 * 1.2 = USD -120
        // Net worth = USD -70

        // When
        final result = await service();

        // Then
        expect(result.failureOrNull, isNull);

        expectAmount(
          result.valueOrNull,
          assetId: usd,
          amount: '70',
          incoming: false,
        );
      },
    );

    test(
      'skips valuation when accounts in a foreign asset net to zero',
      () async {
        // Given
        final positive = createAccount(
          id: 'account-eur-positive',
          denominationAssetId: eur,
        );

        final negative = createAccount(
          id: 'account-eur-negative',
          denominationAssetId: eur,
        );

        stubSettings(usd);
        stubAccounts([
          positive,
          negative,
        ]);

        stubBalance(positive, '50');
        stubBalance(negative, '-50');

        // When
        final result = await service();

        // Then
        expect(result.failureOrNull, isNull);

        expectAmount(
          result.valueOrNull,
          assetId: usd,
          amount: '0',
          incoming: true,
        );

        // Only GetNetWorthService itself needs Settings. AssetValuationService
        // is never invoked because the EUR aggregate contributes exactly zero.
        verify(() => getSettings()).called(1);

        verifyZeroInteractions(rateRepository);
      },
    );

    test(
      'preserves exact decimal arithmetic without binary rounding',
      () async {
        // Given
        final first = createAccount(
          id: 'account-usd-1',
          denominationAssetId: usd,
        );

        final second = createAccount(
          id: 'account-usd-2',
          denominationAssetId: usd,
        );

        stubSettings(usd);
        stubAccounts([
          first,
          second,
        ]);

        stubBalance(first, '0.1');
        stubBalance(second, '0.2');

        // When
        final result = await service();

        // Then
        expectAmount(
          result.valueOrNull,
          assetId: usd,
          amount: '0.3',
          incoming: true,
        );

        verifyZeroInteractions(rateRepository);
      },
    );

    test(
      'uses the same UTC valuation instant for every foreign asset',
      () async {
        // Given
        final eurAccount = createAccount(
          id: 'account-eur',
          denominationAssetId: eur,
        );

        final gbpAccount = createAccount(
          id: 'account-gbp',
          denominationAssetId: gbp,
        );

        stubSettings(usd);
        stubAccounts([
          eurAccount,
          gbpAccount,
        ]);

        stubBalance(eurAccount, '10');
        stubBalance(gbpAccount, '20');

        stubUsdRate(
          sourceAssetId: eur,
          rate: '1.1',
        );

        stubUsdRate(
          sourceAssetId: gbp,
          rate: '1.3',
        );

        // When
        await service();

        // Then
        verify(
          () => rateRepository.getAtOrBefore(
            baseAssetId: eur,
            quoteAssetId: usd,
            effectiveAt: now,
          ),
        ).called(1);

        verify(
          () => rateRepository.getAtOrBefore(
            baseAssetId: gbp,
            quoteAssetId: usd,
            effectiveAt: now,
          ),
        ).called(1);
      },
    );

    test(
      'returns settings-not-initialized when settings do not exist',
      () async {
        // Given
        when(
          () => getSettings(),
        ).thenAnswer(
          (_) async => const Success<Settings?>(null),
        );

        // When
        final result = await service();

        // Then
        expect(
          result.failureOrNull,
          isA<SettingsNotInitializedFailure>(),
        );

        expect(
          result.failureOrNull?.message,
          'Settings have not been initialized.',
        );

        verifyNever(
          () => accountRepository.getAll(),
        );

        verifyNever(
          () => getAccountBalance(any()),
        );

        verifyZeroInteractions(rateRepository);
      },
    );

    test(
      'propagates settings failures unchanged',
      () async {
        // Given
        const failure = SettingsNotInitializedFailure(
          message: 'settings read failed',
        );

        when(
          () => getSettings(),
        ).thenAnswer(
          (_) async => failure,
        );

        // When
        final result = await service();

        // Then
        expect(
          result.failureOrNull,
          same(failure),
        );

        verifyNever(
          () => accountRepository.getAll(),
        );

        verifyNever(
          () => getAccountBalance(any()),
        );

        verifyZeroInteractions(rateRepository);
      },
    );

    test(
      'propagates account retrieval failures unchanged',
      () async {
        // Given
        const failure = AccountNotFoundFailure(
          message: 'account retrieval failed',
        );

        stubSettings(usd);

        when(
          () => accountRepository.getAll(),
        ).thenAnswer(
          (_) async => failure,
        );

        // When
        final result = await service();

        // Then
        expect(
          result.failureOrNull,
          same(failure),
        );

        verifyNever(
          () => getAccountBalance(any()),
        );

        verifyZeroInteractions(rateRepository);
      },
    );

    test(
      'propagates account balance failures and stops immediately',
      () async {
        // Given
        final first = createAccount(
          id: 'account-first',
          denominationAssetId: eur,
        );

        final second = createAccount(
          id: 'account-second',
          denominationAssetId: eur,
        );

        const failure = AccountNotFoundFailure(
          message: 'balance account missing',
        );

        stubSettings(usd);
        stubAccounts([
          first,
          second,
        ]);

        when(
          () => getAccountBalance(first.id),
        ).thenAnswer(
          (_) async => failure,
        );

        // When
        final result = await service();

        // Then
        expect(
          result.failureOrNull,
          same(failure),
        );

        verify(
          () => getAccountBalance(first.id),
        ).called(1);

        verifyNever(
          () => getAccountBalance(second.id),
        );

        verifyZeroInteractions(rateRepository);
      },
    );

    test(
      'propagates valuation failures unchanged',
      () async {
        // Given
        final account = createAccount(
          id: 'account-eur',
          denominationAssetId: eur,
        );

        const failure = RateNotFoundFailure(
          message: 'EUR/USD rate was not found.',
        );

        stubSettings(usd);
        stubAccounts([account]);
        stubBalance(account, '100');

        when(
          () => rateRepository.getAtOrBefore(
            baseAssetId: eur,
            quoteAssetId: usd,
            effectiveAt: now,
          ),
        ).thenAnswer(
          (_) async => failure,
        );

        // When
        final result = await service();

        // Then
        expect(
          result.failureOrNull,
          same(failure),
        );

        verify(
          () => rateRepository.getAtOrBefore(
            baseAssetId: eur,
            quoteAssetId: usd,
            effectiveAt: now,
          ),
        ).called(1);
      },
    );

    test(
      'fails rather than combining values when valuation currency changes',
      () async {
        // Given
        final account = createAccount(
          id: 'account-eur',
          denominationAssetId: eur,
        );

        var settingsReadCount = 0;

        when(
          () => getSettings(),
        ).thenAnswer(
          (_) async {
            settingsReadCount++;

            return Success(
              Settings(
                valuationCurrencyId:
                    settingsReadCount == 1 ? usd : eur,
              ),
            );
          },
        );

        stubAccounts([account]);
        stubBalance(account, '100');

        // GetNetWorthService locks USD from the first settings read.
        //
        // AssetValuationService then observes EUR on the second settings read.
        // Since the source amount is already EUR, it returns an EUR valuation.
        //
        // GetNetWorthService must reject that result instead of treating
        // EUR 100 as USD 100.

        // When
        final result = await service();

        // Then
        expect(
          result.failureOrNull,
          isA<InvalidValuationCurrencyFailure>(),
        );

        expect(
          result.failureOrNull?.message,
          contains(usd.value),
        );

        expect(
          result.failureOrNull?.message,
          contains(eur.value),
        );

        verifyZeroInteractions(rateRepository);
      },
    );

    test(
      'requests every successful account balance exactly once',
      () async {
        // Given
        final first = createAccount(
          id: 'account-first',
          denominationAssetId: usd,
        );

        final second = createAccount(
          id: 'account-second',
          denominationAssetId: eur,
        );

        final third = createAccount(
          id: 'account-third',
          denominationAssetId: eur,
        );

        stubSettings(usd);
        stubAccounts([
          first,
          second,
          third,
        ]);

        stubBalance(first, '10');
        stubBalance(second, '20');
        stubBalance(third, '30');

        stubUsdRate(
          sourceAssetId: eur,
          rate: '1.2',
        );

        // When
        await service();

        // Then
        verify(
          () => getAccountBalance(first.id),
        ).called(1);

        verify(
          () => getAccountBalance(second.id),
        ).called(1);

        verify(
          () => getAccountBalance(third.id),
        ).called(1);

        // Despite there being two EUR accounts, EUR is valued only once.
        verify(
          () => rateRepository.getAtOrBefore(
            baseAssetId: eur,
            quoteAssetId: usd,
            effectiveAt: now,
          ),
        ).called(1);
      },
    );
  });
}