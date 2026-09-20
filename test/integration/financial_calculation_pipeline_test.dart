@Tags(['integration'])
library;

import 'package:axiom/src/application/services/asset_valuation_service.dart';
import 'package:axiom/src/application/services/get_valuation_currency_service.dart';
import 'package:axiom/src/application/services/get_account_balance_service.dart';
import 'package:axiom/src/application/services/get_net_worth_service.dart';
import 'package:axiom/src/application/services/resolve_conversion_rate_service.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/application/use_cases/get_accounts_use_case.dart';
import 'package:axiom/src/features/accounts/domain/entities/account.dart';
import 'package:axiom/src/features/accounts/domain/services/account_balance_calculator.dart';
import 'package:axiom/src/features/assets/domain/services/asset_valuation_calculator.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_asset_by_id_use_case.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/rates/domain/services/rate_conversion_service.dart';
import 'package:axiom/src/features/settings/domain/entities/settings.dart';
import 'package:axiom/src/features/transactions/domain/enums/ledger_entry_role.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/ledger_entry.dart';
import 'package:decimal/decimal.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../fixtures/features/accounts/account_fixtures.dart';
import '../fixtures/features/assets/asset_fixtures.dart';
import '../fixtures/features/rates/rate_fixtures.dart';
import '../mocks/account_repository_mock.dart';
import '../mocks/get_account_by_id_use_case_mock.dart';
import '../mocks/asset_repository_mock.dart';
import '../mocks/get_ledger_entries_by_account_id_use_case_mock.dart';
import '../mocks/get_settings_use_case_mock.dart';
import '../mocks/get_rate_at_use_case_mock.dart';
import '../mocks/rate_repository_mock.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(AssetId.fromString('fallback-asset'));
    registerFallbackValue(DateTime.utc(1970));
  });

  group('Financial calculation pipeline', () {
    late MockGetSettingsUseCase getSettings;
    late MockAssetRepository assetRepository;
    late MockAccountRepository accountRepository;
    late MockGetAccountByIdUseCase getAccountById;
    late MockGetLedgerEntriesByAccountIdUseCase getLedgerEntriesByAccountId;
    late MockGetRateAtUseCase getRateAt;
    late MockRateRepository rateRepository;

    late GetAccountBalanceService getAccountBalance;
    late AssetValuationService assetValuation;
    late GetNetWorthService getNetWorth;

    late AssetId usd;
    late AssetId eur;
    late DateTime now;

    setUp(() {
      getSettings = MockGetSettingsUseCase();
      assetRepository = MockAssetRepository();
      accountRepository = MockAccountRepository();
      getAccountById = MockGetAccountByIdUseCase();
      getLedgerEntriesByAccountId = MockGetLedgerEntriesByAccountIdUseCase();
      getRateAt = MockGetRateAtUseCase();
      rateRepository = MockRateRepository();

      usd = AssetId.fromString('asset-usd');
      eur = AssetId.fromString('asset-eur');

      now = DateTime.utc(2026, 9, 17, 10);

      when(
        () => getRateAt(
          baseAssetId: any(named: 'baseAssetId'),
          quoteAssetId: any(named: 'quoteAssetId'),
          at: any(named: 'at'),
        ),
      ).thenAnswer((invocation) {
        final arguments = invocation.namedArguments;
        final baseAssetId = arguments[#baseAssetId];
        final quoteAssetId = arguments[#quoteAssetId];
        final at = arguments[#at];

        if (baseAssetId is! AssetId ||
            quoteAssetId is! AssetId ||
            at is! DateTime) {
          throw StateError('Unexpected rate lookup arguments.');
        }

        return rateRepository.getAtOrBefore(
          baseAssetId: baseAssetId,
          quoteAssetId: quoteAssetId,
          effectiveAt: at,
        );
      });

      getAccountBalance = GetAccountBalanceService(
        getAccountById: getAccountById,
        getLedgerEntriesByAccountId: getLedgerEntriesByAccountId,
        calculator: const AccountBalanceCalculator(),
      );

      final getValuationCurrency = GetValuationCurrencyService(
        getSettings: getSettings,
        getAssetById: GetAssetByIdUseCase(assetRepository),
      );

      when(() => assetRepository.getById(any())).thenAnswer((invocation) async {
        final assetId = invocation.positionalArguments.single as AssetId;
        return Success(currencyFixture(id: assetId.value));
      });

      assetValuation = AssetValuationService(
        getValuationCurrency: getValuationCurrency,
        resolveConversionRate: ResolveConversionRateService(
          getRateAt: getRateAt,
          canonicalBridgeAssetId: usd,
          rateConversion: const RateConversionService(),
        ),
        calculator: const AssetValuationCalculator(),
      );

      getNetWorth = GetNetWorthService(
        getSettings: getSettings,
        getAccounts: GetAccountsUseCase(accountRepository),
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

    LedgerEntry createLedgerEntry({
      required Account account,
      required String amount,
      required bool incoming,
    }) {
      final createAmount = incoming
          ? AssetAmount.incoming
          : AssetAmount.outgoing;

      final accountAmount = createAmount(
        assetId: account.denominationAssetId,
        amount: Decimal.parse(amount),
      );

      return LedgerEntry(
        accountId: account.id,
        transactionAmount: accountAmount,
        accountAmount: accountAmount,
        valuationAmount: accountAmount,
        role: LedgerEntryRole.primary,
      );
    }

    void stubSettings() {
      when(
        () => getSettings(),
      ).thenAnswer((_) async => Success(Settings(valuationCurrencyId: usd)));
    }

    void stubAccount(Account account, List<LedgerEntry> entries) {
      when(
        () => getAccountById(account.id),
      ).thenAnswer((_) async => Success(account));

      when(
        () => getLedgerEntriesByAccountId(account.id),
      ).thenAnswer((_) async => Success<List<LedgerEntry>>(entries));
    }

    test(
      'derives net worth from ledger entries and values foreign balances',
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

        stubSettings();

        when(() => accountRepository.getAll()).thenAnswer(
          (_) async => Success<List<Account>>([usdAccount, eurAccount]),
        );

        stubAccount(usdAccount, [
          createLedgerEntry(
            account: usdAccount,
            amount: '100.10',
            incoming: true,
          ),
          createLedgerEntry(
            account: usdAccount,
            amount: '20.05',
            incoming: false,
          ),
        ]);

        stubAccount(eurAccount, [
          createLedgerEntry(
            account: eurAccount,
            amount: '50.20',
            incoming: true,
          ),
          createLedgerEntry(
            account: eurAccount,
            amount: '10.10',
            incoming: false,
          ),
        ]);

        final eurUsdRate = exchangeRateFixture(
          id: 'rate-eur-usd',
          baseAssetId: eur.value,
          quoteAssetId: usd.value,
          rate: '1.25',
        );

        when(
          () => rateRepository.getAtOrBefore(
            baseAssetId: eur,
            quoteAssetId: usd,
            effectiveAt: now,
          ),
        ).thenAnswer((_) async => Success(eurUsdRate));

        // USD:
        //   100.10 - 20.05 = 80.05
        //
        // EUR:
        //   50.20 - 10.10 = 40.10
        //
        // EUR -> USD:
        //   40.10 * 1.25 = 50.125
        //
        // Net worth:
        //   80.05 + 50.125 = 130.175

        // When
        final result = await getNetWorth();

        // Then
        expect(result.failureOrNull, isNull);

        final netWorth = result.valueOrNull;

        expect(netWorth, isNotNull);
        expect(netWorth!.assetId, usd);
        expect(netWorth.amount, Decimal.parse('130.175'));
        expect(netWorth.isIncoming, isTrue);

        verify(() => accountRepository.getAll()).called(1);

        verify(() => getAccountById(usdAccount.id)).called(1);

        verify(() => getAccountById(eurAccount.id)).called(1);

        verify(() => getLedgerEntriesByAccountId(usdAccount.id)).called(1);

        verify(() => getLedgerEntriesByAccountId(eurAccount.id)).called(1);

        verify(
          () => rateRepository.getAtOrBefore(
            baseAssetId: eur,
            quoteAssetId: usd,
            effectiveAt: now,
          ),
        ).called(1);
      },
    );

    test('nets same-asset account balances before foreign valuation', () async {
      // Given
      final first = createAccount(
        id: 'account-eur-1',
        denominationAssetId: eur,
      );

      final second = createAccount(
        id: 'account-eur-2',
        denominationAssetId: eur,
      );

      stubSettings();

      when(
        () => accountRepository.getAll(),
      ).thenAnswer((_) async => Success<List<Account>>([first, second]));

      stubAccount(first, [
        createLedgerEntry(account: first, amount: '100.25', incoming: true),
      ]);

      stubAccount(second, [
        createLedgerEntry(account: second, amount: '20.10', incoming: false),
      ]);

      final eurUsdRate = exchangeRateFixture(
        id: 'rate-eur-usd',
        baseAssetId: eur.value,
        quoteAssetId: usd.value,
        rate: '1.25',
      );

      when(
        () => rateRepository.getAtOrBefore(
          baseAssetId: eur,
          quoteAssetId: usd,
          effectiveAt: now,
        ),
      ).thenAnswer((_) async => Success(eurUsdRate));

      // EUR:
      //   100.25 - 20.10 = 80.15
      //
      // USD:
      //   80.15 * 1.25 = 100.1875

      // When
      final result = await getNetWorth();

      // Then
      expect(result.failureOrNull, isNull);

      final netWorth = result.valueOrNull;

      expect(netWorth, isNotNull);
      expect(netWorth!.assetId, usd);
      expect(netWorth.amount, Decimal.parse('100.1875'));
      expect(netWorth.isIncoming, isTrue);

      // There must be one rate lookup for the aggregate EUR balance,
      // not one lookup per EUR account.
      verify(
        () => rateRepository.getAtOrBefore(
          baseAssetId: eur,
          quoteAssetId: usd,
          effectiveAt: now,
        ),
      ).called(1);
    });

    test(
      'skips foreign valuation when same-asset balances cancel exactly',
      () async {
        // Given
        final first = createAccount(
          id: 'account-eur-positive',
          denominationAssetId: eur,
        );

        final second = createAccount(
          id: 'account-eur-negative',
          denominationAssetId: eur,
        );

        stubSettings();

        when(
          () => accountRepository.getAll(),
        ).thenAnswer((_) async => Success<List<Account>>([first, second]));

        stubAccount(first, [
          createLedgerEntry(
            account: first,
            amount: '100.123456789',
            incoming: true,
          ),
        ]);

        stubAccount(second, [
          createLedgerEntry(
            account: second,
            amount: '100.123456789',
            incoming: false,
          ),
        ]);

        // No FX rate is intentionally stubbed.

        // When
        final result = await getNetWorth();

        // Then
        expect(result.failureOrNull, isNull);

        final netWorth = result.valueOrNull;

        expect(netWorth, isNotNull);
        expect(netWorth!.assetId, usd);
        expect(netWorth.amount, Decimal.zero);
        expect(netWorth.isIncoming, isTrue);

        verifyZeroInteractions(rateRepository);
      },
    );
  });
}
