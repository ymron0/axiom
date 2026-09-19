@Tags(['application'])
library;

import 'package:axiom/src/application/services/capture_balance_snapshots_service.dart';
import 'package:axiom/src/application/services/resolve_conversion_rate_service.dart';
import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/identity/ids/transaction_id.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/application/use_cases/get_accounts_use_case.dart';
import 'package:axiom/src/features/accounts/domain/entities/account.dart';
import 'package:axiom/src/features/assets/domain/services/asset_valuation_calculator.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/balance_snapshots/domain/value_objects/balance_snapshot.dart';
import 'package:axiom/src/features/balance_snapshots/domain/value_objects/balance_snapshot_subject.dart';
import 'package:axiom/src/features/custodians/application/use_cases/get_custodians_use_case.dart';
import 'package:axiom/src/features/custodians/domain/entities/custodian.dart';
import 'package:axiom/src/features/jars/application/use_cases/get_jars_use_case.dart';
import 'package:axiom/src/features/jars/domain/entities/jar.dart';
import 'package:axiom/src/features/jars/domain/services/jar_balance_calculator.dart';
import 'package:axiom/src/features/rates/domain/entities/rate.dart';
import 'package:axiom/src/features/rates/domain/failures/rate_not_found_failure.dart';
import 'package:axiom/src/features/rates/domain/services/rate_conversion_service.dart';
import 'package:axiom/src/features/settings/application/use_cases/get_settings_use_case.dart';
import 'package:axiom/src/features/settings/domain/entities/settings.dart';
import 'package:axiom/src/features/settings/domain/failures/settings_not_initialized_failure.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_all_transactions_use_case.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/enums/ledger_entry_role.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_kind.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_state.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/ledger_entry.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/transaction_split.dart';
import 'package:decimal/decimal.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../fixtures/features/accounts/account_fixtures.dart';
import '../../../fixtures/features/custodians/custodian_fixtures.dart';
import '../../../fixtures/features/jars/jar_fixtures.dart';
import '../../../fixtures/features/rates/rate_fixtures.dart';
import '../../../mocks/account_repository_mock.dart';
import '../../../mocks/balance_snapshot_repository_mock.dart';
import '../../../mocks/custodian_repository_mock.dart';
import '../../../mocks/get_rate_at_use_case_mock.dart';
import '../../../mocks/jar_repository_mock.dart';
import '../../../mocks/settings_repository_mock.dart';
import '../../../mocks/transaction_repository_mock.dart';

void main() {
  final usd = AssetId.fromString('asset-usd');
  final eur = AssetId.fromString('asset-eur');
  final chf = AssetId.fromString('asset-chf');
  final btc = AssetId.fromString('asset-btc');

  final snapshotDate = CalendarDate(2026, 9, 19);
  final capturedAt = DateTime.utc(2026, 9, 20, 2);

  late MockSettingsRepository settingsRepository;
  late MockAccountRepository accountRepository;
  late MockCustodianRepository custodianRepository;
  late MockJarRepository jarRepository;
  late MockTransactionRepository transactionRepository;
  late MockGetRateAtUseCase getRateAt;
  late MockBalanceSnapshotRepository snapshotRepository;

  late CaptureBalanceSnapshotsService service;

  setUpAll(() {
    registerFallbackValue(AssetId.fromString('fallback-asset'));

    registerFallbackValue(DateTime.utc(1970));

    registerFallbackValue(
      BalanceSnapshot(
        subject: BalanceSnapshotSubject.account(
          AccountId.fromString('fallback-account'),
        ),
        snapshotDate: CalendarDate(2026, 1, 1),
        capturedAt: DateTime.utc(2026, 1, 2),
        assetBalances: [
          AssetAmount.incoming(
            assetId: AssetId.fromString('asset-chf'),
            amount: Decimal.one,
          ),
        ],
        denominationAmount: AssetAmount.incoming(
          assetId: AssetId.fromString('asset-chf'),
          amount: Decimal.one,
        ),
        valuationAmount: AssetAmount.incoming(
          assetId: AssetId.fromString('asset-chf'),
          amount: Decimal.one,
        ),
      ),
    );
  });

  setUp(() {
    settingsRepository = MockSettingsRepository();
    accountRepository = MockAccountRepository();
    custodianRepository = MockCustodianRepository();
    jarRepository = MockJarRepository();
    transactionRepository = MockTransactionRepository();
    getRateAt = MockGetRateAtUseCase();
    snapshotRepository = MockBalanceSnapshotRepository();

    service = CaptureBalanceSnapshotsService(
      getSettings: GetSettingsUseCase(settingsRepository),
      getAccounts: GetAccountsUseCase(accountRepository),
      getCustodians: GetCustodiansUseCase(custodianRepository),
      getJars: GetJarsUseCase(jarRepository),
      getTransactions: GetAllTransactionsUseCase(transactionRepository),
      resolveConversionRate: ResolveConversionRateService(
        getRateAt: getRateAt,
        canonicalBridgeAssetId: usd,
        rateConversion: const RateConversionService(),
      ),
      assetValuationCalculator: const AssetValuationCalculator(),
      jarBalanceCalculator: const JarBalanceCalculator(),
      snapshotRepository: snapshotRepository,
      clock: FixedClock(capturedAt),
    );

    when(() => settingsRepository.get()).thenAnswer(
      (_) async => Success<Settings?>(Settings(valuationCurrencyId: chf)),
    );

    when(
      () => snapshotRepository.save(any()),
    ).thenAnswer((_) async => const Success(null));

    _stubRates(getRateAt: getRateAt, usd: usd, eur: eur, chf: chf, btc: btc);
  });

  group('CaptureBalanceSnapshotsService', () {
    test('throws when an account snapshot is missing for a custodian', () {
      // Given
      final custodian = custodianFixture(id: 'custodian-bank');
      final account = accountFixture(
        id: 'account-missing',
        custodianId: custodian.id.value,
      );

      // When / Then
      expect(
        () => service.captureCustodianSnapshot(
          custodian: custodian,
          accounts: [account],
          accountSnapshots: const {},
          baseValuationCurrencyId: chf,
          snapshotDate: snapshotDate,
          capturedAt: capturedAt,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'Account snapshot missing during custodian snapshot capture: '
                'account-missing.',
          ),
        ),
      );
    });

    test(
      'throws when an account snapshot uses another valuation currency',
      () {
        // Given
        final custodian = custodianFixture(id: 'custodian-bank');
        final account = accountFixture(
          id: 'account-wrong-currency',
          custodianId: custodian.id.value,
        );
        final accountSnapshot = BalanceSnapshot(
          subject: BalanceSnapshotSubject.account(account.id),
          snapshotDate: snapshotDate,
          capturedAt: capturedAt,
          assetBalances: [_incoming(eur, '100')],
          denominationAmount: _incoming(eur, '100'),
          valuationAmount: _incoming(eur, '100'),
        );

        // When / Then
        expect(
          () => service.captureCustodianSnapshot(
            custodian: custodian,
            accounts: [account],
            accountSnapshots: {account.id: accountSnapshot},
            baseValuationCurrencyId: chf,
            snapshotDate: snapshotDate,
            capturedAt: capturedAt,
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'Account snapshot valuation does not use the configured base '
                  'valuation currency: account-wrong-currency.',
            ),
          ),
        );
      },
    );

    test('throws when valuing an unknown amount', () async {
      // Given
      final unknownAmount = AssetAmount.incoming(
        assetId: btc,
        amount: Decimal.fromInt(-1),
      );

      // When / Then
      await expectLater(
        service.valueAmounts(
          amounts: [unknownAmount],
          valuationCurrencyId: chf,
          at: capturedAt,
        ),
        throwsA(
          isA<ArgumentError>()
              .having((error) => error.name, 'name', 'amounts')
              .having(
                (error) => error.message,
                'message',
                'Snapshot valuation cannot contain an unknown amount.',
              ),
        ),
      );
    });

    test('throws when aggregating an unknown account amount', () async {
      // Given
      final custodian = custodianFixture(id: 'custodian-bank');
      final account = accountFixture(
        id: 'account-unknown',
        custodianId: custodian.id.value,
      );
      final unknownAmount = AssetAmount.incoming(
        assetId: btc,
        amount: Decimal.fromInt(-1),
      );
      final transaction = _income(
        id: 'unknown-income',
        accountId: account.id,
        effectiveAt: DateTime.utc(2026, 9, 19, 10),
        transactionAmount: unknownAmount,
        accountAmount: unknownAmount,
        valuationAmount: unknownAmount,
      );

      when(
        () => accountRepository.getAll(),
      ).thenAnswer((_) async => Success<List<Account>>([account]));

      when(
        () => custodianRepository.getAll(),
      ).thenAnswer((_) async => Success<List<Custodian>>([custodian]));

      when(
        () => jarRepository.getAll(),
      ).thenAnswer((_) async => const Success<List<Jar>>([]));

      when(
        () => transactionRepository.getAll(),
      ).thenAnswer((_) async => Success<List<Transaction>>([transaction]));

      // When / Then
      await expectLater(
        service(snapshotDate),
        throwsA(
          isA<ArgumentError>()
              .having((error) => error.name, 'name', 'amounts')
              .having(
                (error) => error.message,
                'message',
                'Snapshot asset balances cannot contain unknown amounts.',
              ),
        ),
      );
    });

    test(
      'captures account, custodian, and jar snapshots for one date',
      () async {
        // Given
        final custodian = custodianFixture(id: 'custodian-bank');

        final eurAccount = accountFixture(
          id: 'account-eur',
          custodianId: custodian.id.value,
          denominationAssetId: eur.value,
        );

        final chfAccount = accountFixture(
          id: 'account-chf',
          custodianId: custodian.id.value,
          denominationAssetId: chf.value,
        );

        final jar = jarFixture(id: 'jar-holiday');

        final transactions = <Transaction>[
          _income(
            id: 'usd-income',
            accountId: eurAccount.id,
            effectiveAt: DateTime.utc(2026, 9, 19, 8),
            transactionAmount: _incoming(usd, '100'),
            accountAmount: _incoming(eur, '50'),
            valuationAmount: _incoming(chf, '100'),
          ),
          _income(
            id: 'btc-income',
            accountId: eurAccount.id,
            effectiveAt: DateTime.utc(2026, 9, 19, 9),
            transactionAmount: _incoming(btc, '1'),
            accountAmount: _incoming(eur, '50'),
            valuationAmount: _incoming(chf, '100'),
          ),
          _income(
            id: 'chf-income',
            accountId: chfAccount.id,
            effectiveAt: DateTime.utc(2026, 9, 19, 10),
            transactionAmount: _incoming(chf, '50'),
            accountAmount: _incoming(chf, '50'),
            valuationAmount: _incoming(chf, '50'),
          ),
          _expenseWithJar(
            id: 'jar-expense',
            accountId: chfAccount.id,
            jarId: jar.id,
            effectiveAt: DateTime.utc(2026, 9, 19, 11),
            amount: _outgoing(chf, '20'),
          ),
          _income(
            id: 'planned-income',
            accountId: eurAccount.id,
            effectiveAt: DateTime.utc(2026, 9, 19, 12),
            transactionAmount: _incoming(usd, '999'),
            accountAmount: _incoming(eur, '999'),
            valuationAmount: _incoming(chf, '999'),
            state: TransactionState.planned,
          ),
          _income(
            id: 'next-day-income',
            accountId: eurAccount.id,
            effectiveAt: DateTime.utc(2026, 9, 20),
            transactionAmount: _incoming(usd, '999'),
            accountAmount: _incoming(eur, '999'),
            valuationAmount: _incoming(chf, '999'),
          ),
        ];

        when(() => accountRepository.getAll()).thenAnswer(
          (_) async => Success<List<Account>>([eurAccount, chfAccount]),
        );

        when(
          () => custodianRepository.getAll(),
        ).thenAnswer((_) async => Success<List<Custodian>>([custodian]));

        when(
          () => jarRepository.getAll(),
        ).thenAnswer((_) async => Success<List<Jar>>([jar]));

        when(
          () => transactionRepository.getAll(),
        ).thenAnswer((_) async => Success<List<Transaction>>(transactions));

        // When
        final result = await service(snapshotDate);

        // Then
        expect(result.isSuccess, isTrue);

        final snapshots = result.valueOrNull!;

        expect(snapshots, hasLength(4));

        expect(
          snapshots.every((snapshot) => snapshot.snapshotDate == snapshotDate),
          isTrue,
        );

        expect(
          snapshots.every((snapshot) => snapshot.capturedAt == capturedAt),
          isTrue,
        );

        final eurAccountSnapshot = snapshots.singleWhere(
          (snapshot) => snapshot.subject.accountId == eurAccount.id,
        );

        expect(
          eurAccountSnapshot.assetBalances
              .map((amount) => amount.assetId)
              .toList(),
          [btc, usd],
        );

        expect(_amountFor(eurAccountSnapshot, btc).amount, Decimal.one);

        expect(
          _amountFor(eurAccountSnapshot, usd).amount,
          Decimal.fromInt(100),
        );

        // Account denomination is EUR.
        //
        // USD 100 -> EUR 50.
        // BTC 1   -> USD 100 -> EUR 50.
        //
        // Total denomination = EUR 100.
        expect(eurAccountSnapshot.denominationAmount.assetId, eur);

        expect(
          eurAccountSnapshot.denominationAmount.amount,
          Decimal.fromInt(100),
        );

        expect(eurAccountSnapshot.denominationAmount.isIncoming, isTrue);

        // User base valuation currency is CHF.
        //
        // USD 100 -> CHF 100.
        // BTC 1   -> USD 100 -> CHF 100.
        //
        // Total valuation = CHF 200.
        expect(eurAccountSnapshot.valuationAmount.assetId, chf);

        expect(eurAccountSnapshot.valuationAmount.amount, Decimal.fromInt(200));

        expect(eurAccountSnapshot.valuationAmount.isIncoming, isTrue);

        final chfAccountSnapshot = snapshots.singleWhere(
          (snapshot) => snapshot.subject.accountId == chfAccount.id,
        );

        expect(chfAccountSnapshot.assetBalances, hasLength(1));

        expect(chfAccountSnapshot.assetBalances.single.assetId, chf);

        expect(
          chfAccountSnapshot.assetBalances.single.amount,
          Decimal.fromInt(30),
        );

        expect(chfAccountSnapshot.assetBalances.single.isIncoming, isTrue);

        expect(chfAccountSnapshot.denominationAmount.assetId, chf);

        expect(
          chfAccountSnapshot.denominationAmount.amount,
          Decimal.fromInt(30),
        );

        expect(chfAccountSnapshot.valuationAmount.assetId, chf);

        expect(chfAccountSnapshot.valuationAmount.amount, Decimal.fromInt(30));

        expect(
          chfAccountSnapshot.denominationAmount,
          chfAccountSnapshot.valuationAmount,
        );

        final custodianSnapshot = snapshots.singleWhere(
          (snapshot) => snapshot.subject.custodianId == custodian.id,
        );

        expect(
          custodianSnapshot.assetBalances
              .map((amount) => amount.assetId)
              .toList(),
          [btc, chf, usd],
        );

        expect(_amountFor(custodianSnapshot, btc).amount, Decimal.one);

        expect(_amountFor(custodianSnapshot, chf).amount, Decimal.fromInt(30));

        expect(_amountFor(custodianSnapshot, usd).amount, Decimal.fromInt(100));

        // EUR-account base valuation = CHF 200.
        // CHF-account base valuation = CHF 30.
        //
        // Custodian total = CHF 230.
        expect(custodianSnapshot.denominationAmount.assetId, chf);

        expect(
          custodianSnapshot.denominationAmount.amount,
          Decimal.fromInt(230),
        );

        expect(custodianSnapshot.valuationAmount.assetId, chf);

        expect(custodianSnapshot.valuationAmount.amount, Decimal.fromInt(230));

        expect(
          custodianSnapshot.denominationAmount,
          custodianSnapshot.valuationAmount,
        );

        final jarSnapshot = snapshots.singleWhere(
          (snapshot) => snapshot.subject.jarId == jar.id,
        );

        expect(jarSnapshot.assetBalances, hasLength(1));

        expect(jarSnapshot.assetBalances.single.assetId, chf);

        expect(jarSnapshot.assetBalances.single.amount, Decimal.fromInt(20));

        expect(jarSnapshot.assetBalances.single.isOutgoing, isTrue);

        expect(
          jarSnapshot.denominationAmount,
          jarSnapshot.assetBalances.single,
        );

        expect(jarSnapshot.valuationAmount, jarSnapshot.assetBalances.single);

        expect(jarSnapshot.denominationAmount, jarSnapshot.valuationAmount);

        verify(() => snapshotRepository.save(any())).called(4);
      },
    );

    test(
      'uses one historical valuation instant for all rate lookups',
      () async {
        // Given
        final custodian = custodianFixture(id: 'custodian-bank');

        final account = accountFixture(
          id: 'account-eur',
          custodianId: custodian.id.value,
          denominationAssetId: eur.value,
        );

        final transaction = _income(
          id: 'usd-income',
          accountId: account.id,
          effectiveAt: DateTime.utc(2026, 9, 19, 10),
          transactionAmount: _incoming(usd, '100'),
          accountAmount: _incoming(eur, '50'),
          valuationAmount: _incoming(chf, '100'),
        );

        when(
          () => accountRepository.getAll(),
        ).thenAnswer((_) async => Success<List<Account>>([account]));

        when(
          () => custodianRepository.getAll(),
        ).thenAnswer((_) async => Success<List<Custodian>>([custodian]));

        when(
          () => jarRepository.getAll(),
        ).thenAnswer((_) async => const Success<List<Jar>>([]));

        when(
          () => transactionRepository.getAll(),
        ).thenAnswer((_) async => Success<List<Transaction>>([transaction]));

        // When
        final result = await service(snapshotDate);

        // Then
        expect(result.isSuccess, isTrue);

        final expectedValuationAt = DateTime.utc(
          2026,
          9,
          19,
          23,
          59,
          59,
          999,
          999,
        );

        final capturedTimes = verify(
          () => getRateAt(
            baseAssetId: any(named: 'baseAssetId'),
            quoteAssetId: usd,
            at: captureAny(named: 'at'),
          ),
        ).captured;

        expect(capturedTimes, isNotEmpty);

        expect(
          capturedTimes.every((value) => value == expectedValuationAt),
          isTrue,
        );
      },
    );

    test(
      'does not persist snapshots when denomination valuation fails',
      () async {
        // Given
        final custodian = custodianFixture(id: 'custodian-bank');

        final account = accountFixture(
          id: 'account-eur',
          custodianId: custodian.id.value,
          denominationAssetId: eur.value,
        );

        final transaction = _income(
          id: 'btc-income',
          accountId: account.id,
          effectiveAt: DateTime.utc(2026, 9, 19, 10),
          transactionAmount: _incoming(btc, '1'),
          accountAmount: _incoming(eur, '50'),
          valuationAmount: _incoming(chf, '100'),
        );

        when(
          () => accountRepository.getAll(),
        ).thenAnswer((_) async => Success<List<Account>>([account]));

        when(
          () => custodianRepository.getAll(),
        ).thenAnswer((_) async => Success<List<Custodian>>([custodian]));

        when(
          () => jarRepository.getAll(),
        ).thenAnswer((_) async => const Success<List<Jar>>([]));

        when(
          () => transactionRepository.getAll(),
        ).thenAnswer((_) async => Success<List<Transaction>>([transaction]));

        when(
          () => getRateAt(
            baseAssetId: btc,
            quoteAssetId: usd,
            at: any(named: 'at'),
          ),
        ).thenAnswer(
          (_) async =>
              const RateNotFoundFailure(message: 'BTC/USD rate missing.'),
        );

        // When
        final result = await service(snapshotDate);

        // Then
        expect(result.isFailure, isTrue);

        expect(result.failureOrNull, isA<RateNotFoundFailure>());

        verifyNever(() => snapshotRepository.save(any()));
      },
    );

    test(
      'returns settings-not-initialized before reading snapshot subjects',
      () async {
        // Given
        when(
          () => settingsRepository.get(),
        ).thenAnswer((_) async => const Success<Settings?>(null));

        // When
        final result = await service(snapshotDate);

        // Then
        expect(result.isFailure, isTrue);

        expect(result.failureOrNull, isA<SettingsNotInitializedFailure>());

        verifyNever(() => accountRepository.getAll());

        verifyNever(() => custodianRepository.getAll());

        verifyNever(() => jarRepository.getAll());

        verifyNever(() => transactionRepository.getAll());

        verifyNever(() => snapshotRepository.save(any()));
      },
    );

    test('captures an empty source set successfully', () async {
      // Given
      when(
        () => accountRepository.getAll(),
      ).thenAnswer((_) async => const Success<List<Account>>([]));

      when(
        () => custodianRepository.getAll(),
      ).thenAnswer((_) async => const Success<List<Custodian>>([]));

      when(
        () => jarRepository.getAll(),
      ).thenAnswer((_) async => const Success<List<Jar>>([]));

      when(
        () => transactionRepository.getAll(),
      ).thenAnswer((_) async => const Success<List<Transaction>>([]));

      // When
      final result = await service(snapshotDate);

      // Then
      expect(result.isSuccess, isTrue);

      expect(result.valueOrNull, isEmpty);

      verifyNever(() => snapshotRepository.save(any()));
    });

    test('captures an empty account as zero in both currencies', () async {
      // Given
      final custodian = custodianFixture(id: 'custodian-bank');

      final account = accountFixture(
        id: 'account-empty',
        custodianId: custodian.id.value,
        denominationAssetId: eur.value,
      );

      when(
        () => accountRepository.getAll(),
      ).thenAnswer((_) async => Success<List<Account>>([account]));

      when(
        () => custodianRepository.getAll(),
      ).thenAnswer((_) async => Success<List<Custodian>>([custodian]));

      when(
        () => jarRepository.getAll(),
      ).thenAnswer((_) async => const Success<List<Jar>>([]));

      when(
        () => transactionRepository.getAll(),
      ).thenAnswer((_) async => const Success<List<Transaction>>([]));

      // When
      final result = await service(snapshotDate);

      // Then
      expect(result.isSuccess, isTrue);

      final accountSnapshot = result.valueOrNull!.singleWhere(
        (snapshot) => snapshot.subject.accountId == account.id,
      );

      expect(accountSnapshot.assetBalances, isEmpty);

      expect(accountSnapshot.denominationAmount.assetId, eur);

      expect(accountSnapshot.denominationAmount.amount, Decimal.zero);

      expect(accountSnapshot.denominationAmount.isIncoming, isTrue);

      expect(accountSnapshot.valuationAmount.assetId, chf);

      expect(accountSnapshot.valuationAmount.amount, Decimal.zero);

      expect(accountSnapshot.valuationAmount.isIncoming, isTrue);

      final custodianSnapshot = result.valueOrNull!.singleWhere(
        (snapshot) => snapshot.subject.custodianId == custodian.id,
      );

      expect(custodianSnapshot.assetBalances, isEmpty);

      expect(custodianSnapshot.denominationAmount.assetId, chf);

      expect(custodianSnapshot.denominationAmount.amount, Decimal.zero);

      expect(custodianSnapshot.valuationAmount.assetId, chf);

      expect(custodianSnapshot.valuationAmount.amount, Decimal.zero);

      expect(
        custodianSnapshot.denominationAmount,
        custodianSnapshot.valuationAmount,
      );
    });

    test('rejects capture for a future snapshot date', () async {
      // Given
      final futureDate = CalendarDate(2026, 9, 21);

      // When / Then
      await expectLater(
        service(futureDate),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.name,
            'name',
            'snapshotDate',
          ),
        ),
      );

      verifyNever(() => settingsRepository.get());

      verifyNever(() => snapshotRepository.save(any()));
    });

    test('excludes an entity created after the snapshot date', () async {
      // Given
      final current = accountFixture(
        id: 'account-current',
        denominationAssetId: chf.value,
      );

      final future = Account(
        id: AccountId.fromString('account-future'),
        name: 'Future account',
        custodianId: current.custodianId,
        denominationAssetId: chf,
        kind: current.kind,
        reference: null,
        logo: null,
        icon: current.icon,
        color: current.color,
        sortOrder: 1,
        createdAt: DateTime.utc(2026, 9, 20),
        modifiedAt: DateTime.utc(2026, 9, 20),
        entityVersion: 1,
      );

      final custodian = custodianFixture(id: current.custodianId.value);

      when(
        () => accountRepository.getAll(),
      ).thenAnswer((_) async => Success<List<Account>>([current, future]));

      when(
        () => custodianRepository.getAll(),
      ).thenAnswer((_) async => Success<List<Custodian>>([custodian]));

      when(
        () => jarRepository.getAll(),
      ).thenAnswer((_) async => const Success<List<Jar>>([]));

      when(
        () => transactionRepository.getAll(),
      ).thenAnswer((_) async => const Success<List<Transaction>>([]));

      // When
      final result = await service(snapshotDate);

      // Then
      expect(result.isSuccess, isTrue);

      final accountSnapshots = result.valueOrNull!
          .where((snapshot) => snapshot.subject.isAccount)
          .toList();

      expect(accountSnapshots, hasLength(1));

      expect(accountSnapshots.single.subject.accountId, current.id);

      expect(
        result.valueOrNull!.any(
          (snapshot) => snapshot.subject.accountId == future.id,
        ),
        isFalse,
      );
    });

    test(
      'excludes a future actual transaction when capturing the current day',
      () async {
        // Given
        final currentDate = CalendarDate(2026, 9, 20);

        final custodian = custodianFixture(id: 'custodian-bank');

        final account = accountFixture(
          id: 'account-chf',
          custodianId: custodian.id.value,
          denominationAssetId: chf.value,
        );

        final alreadyEffective = _income(
          id: 'already-effective',
          accountId: account.id,
          effectiveAt: DateTime.utc(2026, 9, 20, 1),
          transactionAmount: _incoming(chf, '50'),
          accountAmount: _incoming(chf, '50'),
          valuationAmount: _incoming(chf, '50'),
        );

        final futureToday = _income(
          id: 'future-today',
          accountId: account.id,
          effectiveAt: DateTime.utc(2026, 9, 20, 3),
          transactionAmount: _incoming(chf, '100'),
          accountAmount: _incoming(chf, '100'),
          valuationAmount: _incoming(chf, '100'),
        );

        when(
          () => accountRepository.getAll(),
        ).thenAnswer((_) async => Success<List<Account>>([account]));

        when(
          () => custodianRepository.getAll(),
        ).thenAnswer((_) async => Success<List<Custodian>>([custodian]));

        when(
          () => jarRepository.getAll(),
        ).thenAnswer((_) async => const Success<List<Jar>>([]));

        when(() => transactionRepository.getAll()).thenAnswer(
          (_) async =>
              Success<List<Transaction>>([alreadyEffective, futureToday]),
        );

        // When
        final result = await service(currentDate);

        // Then
        expect(result.isSuccess, isTrue);

        final accountSnapshot = result.valueOrNull!.singleWhere(
          (snapshot) => snapshot.subject.accountId == account.id,
        );

        expect(accountSnapshot.assetBalances, hasLength(1));

        expect(
          accountSnapshot.assetBalances.single.amount,
          Decimal.fromInt(50),
        );

        expect(accountSnapshot.denominationAmount.amount, Decimal.fromInt(50));

        expect(accountSnapshot.valuationAmount.amount, Decimal.fromInt(50));
      },
    );

    test(
      'nets opposing positions in the same asset before valuation',
      () async {
        // Given
        final custodian = custodianFixture(id: 'custodian-bank');

        final account = accountFixture(
          id: 'account-eur',
          custodianId: custodian.id.value,
          denominationAssetId: eur.value,
        );

        final income = _income(
          id: 'income',
          accountId: account.id,
          effectiveAt: DateTime.utc(2026, 9, 19, 8),
          transactionAmount: _incoming(usd, '100'),
          accountAmount: _incoming(eur, '50'),
          valuationAmount: _incoming(chf, '100'),
        );

        final expense = _expense(
          id: 'expense',
          accountId: account.id,
          effectiveAt: DateTime.utc(2026, 9, 19, 9),
          transactionAmount: _outgoing(usd, '25'),
          accountAmount: _outgoing(eur, '12.5'),
          valuationAmount: _outgoing(chf, '25'),
        );

        when(
          () => accountRepository.getAll(),
        ).thenAnswer((_) async => Success<List<Account>>([account]));

        when(
          () => custodianRepository.getAll(),
        ).thenAnswer((_) async => Success<List<Custodian>>([custodian]));

        when(
          () => jarRepository.getAll(),
        ).thenAnswer((_) async => const Success<List<Jar>>([]));

        when(() => transactionRepository.getAll()).thenAnswer(
          (_) async => Success<List<Transaction>>([income, expense]),
        );

        // When
        final result = await service(snapshotDate);

        // Then
        expect(result.isSuccess, isTrue);

        final snapshot = result.valueOrNull!.singleWhere(
          (candidate) => candidate.subject.accountId == account.id,
        );

        expect(snapshot.assetBalances, hasLength(1));

        expect(snapshot.assetBalances.single.assetId, usd);

        expect(snapshot.assetBalances.single.amount, Decimal.fromInt(75));

        expect(snapshot.assetBalances.single.isIncoming, isTrue);

        expect(snapshot.denominationAmount.assetId, eur);

        expect(snapshot.denominationAmount.amount, Decimal.parse('37.5'));

        expect(snapshot.valuationAmount.assetId, chf);

        expect(snapshot.valuationAmount.amount, Decimal.fromInt(75));
      },
    );

    test('preserves an outgoing direction for a net-negative position', () async {
      // Given
      final custodian = custodianFixture(id: 'custodian-bank');
      final account = accountFixture(
        id: 'account-outgoing',
        custodianId: custodian.id.value,
        denominationAssetId: chf.value,
      );
      final expense = _expense(
        id: 'expense',
        accountId: account.id,
        effectiveAt: DateTime.utc(2026, 9, 19, 10),
        transactionAmount: _outgoing(chf, '25'),
        accountAmount: _outgoing(chf, '25'),
        valuationAmount: _outgoing(chf, '25'),
      );

      when(
        () => accountRepository.getAll(),
      ).thenAnswer((_) async => Success<List<Account>>([account]));

      when(
        () => custodianRepository.getAll(),
      ).thenAnswer((_) async => Success<List<Custodian>>([custodian]));

      when(
        () => jarRepository.getAll(),
      ).thenAnswer((_) async => const Success<List<Jar>>([]));

      when(
        () => transactionRepository.getAll(),
      ).thenAnswer((_) async => Success<List<Transaction>>([expense]));

      // When
      final result = await service(snapshotDate);

      // Then
      expect(result.isSuccess, isTrue);

      final accountSnapshot = result.valueOrNull!.singleWhere(
        (snapshot) => snapshot.subject.accountId == account.id,
      );

      expect(accountSnapshot.assetBalances.single.isOutgoing, isTrue);
      expect(accountSnapshot.denominationAmount.isOutgoing, isTrue);
      expect(accountSnapshot.valuationAmount.isOutgoing, isTrue);

      final custodianSnapshot = result.valueOrNull!.singleWhere(
        (snapshot) => snapshot.subject.custodianId == custodian.id,
      );

      expect(custodianSnapshot.denominationAmount.isOutgoing, isTrue);
      expect(custodianSnapshot.valuationAmount.isOutgoing, isTrue);
    });

    test('omits an asset whose net position is zero', () async {
      // Given
      final custodian = custodianFixture(id: 'custodian-bank');

      final account = accountFixture(
        id: 'account-chf',
        custodianId: custodian.id.value,
        denominationAssetId: chf.value,
      );

      final income = _income(
        id: 'income',
        accountId: account.id,
        effectiveAt: DateTime.utc(2026, 9, 19, 8),
        transactionAmount: _incoming(chf, '50'),
        accountAmount: _incoming(chf, '50'),
        valuationAmount: _incoming(chf, '50'),
      );

      final expense = _expense(
        id: 'expense',
        accountId: account.id,
        effectiveAt: DateTime.utc(2026, 9, 19, 9),
        transactionAmount: _outgoing(chf, '50'),
        accountAmount: _outgoing(chf, '50'),
        valuationAmount: _outgoing(chf, '50'),
      );

      when(
        () => accountRepository.getAll(),
      ).thenAnswer((_) async => Success<List<Account>>([account]));

      when(
        () => custodianRepository.getAll(),
      ).thenAnswer((_) async => Success<List<Custodian>>([custodian]));

      when(
        () => jarRepository.getAll(),
      ).thenAnswer((_) async => const Success<List<Jar>>([]));

      when(
        () => transactionRepository.getAll(),
      ).thenAnswer((_) async => Success<List<Transaction>>([income, expense]));

      // When
      final result = await service(snapshotDate);

      // Then
      expect(result.isSuccess, isTrue);

      final snapshot = result.valueOrNull!.singleWhere(
        (candidate) => candidate.subject.accountId == account.id,
      );

      expect(snapshot.assetBalances, isEmpty);

      expect(snapshot.denominationAmount.amount, Decimal.zero);

      expect(snapshot.valuationAmount.amount, Decimal.zero);
    });
  });
}

void _stubRates({
  required MockGetRateAtUseCase getRateAt,
  required AssetId usd,
  required AssetId eur,
  required AssetId chf,
  required AssetId btc,
}) {
  when(
    () => getRateAt(
      baseAssetId: any(named: 'baseAssetId'),
      quoteAssetId: usd,
      at: any(named: 'at'),
    ),
  ).thenAnswer((invocation) async {
    final baseAssetId =
        invocation.namedArguments[const Symbol('baseAssetId')]! as AssetId;

    if (baseAssetId == eur) {
      return Success<Rate>(
        exchangeRateFixture(
          id: 'eur-usd',
          baseAssetId: eur.value,
          quoteAssetId: usd.value,
          rate: '2',
        ),
      );
    }

    if (baseAssetId == chf) {
      return Success<Rate>(
        exchangeRateFixture(
          id: 'chf-usd',
          baseAssetId: chf.value,
          quoteAssetId: usd.value,
          rate: '1',
        ),
      );
    }

    if (baseAssetId == btc) {
      return Success<Rate>(
        exchangeRateFixture(
          id: 'btc-usd',
          baseAssetId: btc.value,
          quoteAssetId: usd.value,
          rate: '100',
        ),
      );
    }

    throw StateError(
      'Unexpected bridge-rate request: '
      '${baseAssetId.value}/${usd.value}.',
    );
  });
}

Transaction _income({
  required String id,
  required AccountId accountId,
  required DateTime effectiveAt,
  required AssetAmount transactionAmount,
  required AssetAmount accountAmount,
  required AssetAmount valuationAmount,
  TransactionState state = TransactionState.actual,
}) {
  return Transaction(
    id: TransactionId.fromString(id),
    kind: TransactionKind.income,
    merchantId: MerchantId.self,
    effectiveAt: effectiveAt,
    description: id,
    state: state,
    splits: const [],
    ledgerEntries: [
      LedgerEntry(
        accountId: accountId,
        transactionAmount: transactionAmount,
        accountAmount: accountAmount,
        valuationAmount: valuationAmount,
        role: LedgerEntryRole.primary,
      ),
    ],
    createdAt: DateTime.utc(2026, 1, 1),
    modifiedAt: DateTime.utc(2026, 1, 1),
    entityVersion: 1,
  );
}

Transaction _expense({
  required String id,
  required AccountId accountId,
  required DateTime effectiveAt,
  required AssetAmount transactionAmount,
  required AssetAmount accountAmount,
  required AssetAmount valuationAmount,
}) {
  return Transaction(
    id: TransactionId.fromString(id),
    kind: TransactionKind.expense,
    merchantId: MerchantId.self,
    effectiveAt: effectiveAt,
    description: id,
    state: TransactionState.actual,
    splits: const [],
    ledgerEntries: [
      LedgerEntry(
        accountId: accountId,
        transactionAmount: transactionAmount,
        accountAmount: accountAmount,
        valuationAmount: valuationAmount,
        role: LedgerEntryRole.primary,
      ),
    ],
    createdAt: DateTime.utc(2026, 1, 1),
    modifiedAt: DateTime.utc(2026, 1, 1),
    entityVersion: 1,
  );
}

Transaction _expenseWithJar({
  required String id,
  required AccountId accountId,
  required JarId jarId,
  required DateTime effectiveAt,
  required AssetAmount amount,
}) {
  return Transaction(
    id: TransactionId.fromString(id),
    kind: TransactionKind.expense,
    merchantId: MerchantId.self,
    effectiveAt: effectiveAt,
    description: id,
    state: TransactionState.actual,
    splits: [
      TransactionSplit(
        transactionAmount: amount,
        valuationAmount: amount,
        jarId: jarId,
      ),
    ],
    ledgerEntries: [
      LedgerEntry(
        accountId: accountId,
        transactionAmount: amount,
        accountAmount: amount,
        valuationAmount: amount,
        role: LedgerEntryRole.primary,
      ),
    ],
    createdAt: DateTime.utc(2026, 1, 1),
    modifiedAt: DateTime.utc(2026, 1, 1),
    entityVersion: 1,
  );
}

AssetAmount _incoming(AssetId assetId, String amount) {
  return AssetAmount.incoming(assetId: assetId, amount: Decimal.parse(amount));
}

AssetAmount _outgoing(AssetId assetId, String amount) {
  return AssetAmount.outgoing(assetId: assetId, amount: Decimal.parse(amount));
}

AssetAmount _amountFor(BalanceSnapshot snapshot, AssetId assetId) {
  return snapshot.assetBalances.singleWhere(
    (amount) => amount.assetId == assetId,
  );
}
