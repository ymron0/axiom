@Tags(['integration', 'balance_snapshots', 'persistence'])
library;

import 'package:axiom/src/application/di/services/capture_balance_snapshots_service_provider.dart';
import 'package:axiom/src/application/di/services/historical_balance_query_service_provider.dart';
import 'package:axiom/src/application/di/services/resolve_conversion_rate_service_provider.dart';
import 'package:axiom/src/application/services/resolve_conversion_rate_service.dart';
import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/core/di/validated_database_provider.dart';
import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/identity/ids/transaction_id.dart';
import 'package:axiom/src/core/persistence/sembast_stores.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/application/use_cases/get_accounts_use_case.dart';
import 'package:axiom/src/features/accounts/di/get_accounts_use_case_provider.dart';
import 'package:axiom/src/features/accounts/domain/entities/account.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/balance_snapshots/di/balance_snapshot_repository_provider.dart';
import 'package:axiom/src/features/balance_snapshots/domain/failures/balance_snapshot_repository_failure.dart';
import 'package:axiom/src/features/balance_snapshots/domain/value_objects/balance_snapshot_date_range.dart';
import 'package:axiom/src/features/balance_snapshots/domain/value_objects/balance_snapshot_subject.dart';
import 'package:axiom/src/features/custodians/application/use_cases/get_custodians_use_case.dart';
import 'package:axiom/src/features/custodians/di/get_custodians_use_case_provider.dart';
import 'package:axiom/src/features/custodians/domain/entities/custodian.dart';
import 'package:axiom/src/features/jars/application/use_cases/get_jars_use_case.dart';
import 'package:axiom/src/features/jars/di/get_jars_use_case_provider.dart';
import 'package:axiom/src/features/jars/domain/entities/jar.dart';
import 'package:axiom/src/features/rates/domain/services/rate_conversion_service.dart';
import 'package:axiom/src/features/settings/application/use_cases/get_settings_use_case.dart';
import 'package:axiom/src/features/settings/di/get_settings_use_case_provider.dart';
import 'package:axiom/src/features/settings/domain/entities/settings.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_all_transactions_use_case.dart';
import 'package:axiom/src/features/transactions/di/get_all_transactions_use_case_provider.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/enums/ledger_entry_role.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_kind.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_state.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/ledger_entry.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/transaction_split.dart';
import 'package:decimal/decimal.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';
import 'package:sembast/sembast_memory.dart' hide Transaction;
import 'package:test/test.dart';

import '../../../fixtures/features/accounts/account_fixtures.dart';
import '../../../fixtures/features/custodians/custodian_fixtures.dart';
import '../../../fixtures/features/jars/jar_fixtures.dart';
import '../../../fixtures/features/rates/rate_fixtures.dart';
import '../../../mocks/account_repository_mock.dart';
import '../../../mocks/custodian_repository_mock.dart';
import '../../../mocks/get_rate_at_use_case_mock.dart';
import '../../../mocks/jar_repository_mock.dart';
import '../../../mocks/settings_repository_mock.dart';
import '../../../mocks/transaction_repository_mock.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(DateTime.utc(1970));
  });

  group('Balance snapshot workflow integration', () {
    late Database database;
    late ProviderContainer container;

    late MockSettingsRepository settingsRepository;
    late MockAccountRepository accountRepository;
    late MockCustodianRepository custodianRepository;
    late MockJarRepository jarRepository;
    late MockTransactionRepository transactionRepository;
    late MockGetRateAtUseCase getRateAt;

    late AssetId eur;
    late AssetId usd;

    late Account account;
    late Custodian custodian;
    late Jar jar;
    late Transaction transaction;

    final capturedAt = DateTime.utc(2026, 9, 21, 12);

    setUp(() async {
      database = await databaseFactoryMemory.openDatabase(
        'balance-snapshot-workflow-'
        '${DateTime.now().microsecondsSinceEpoch}',
      );

      settingsRepository = MockSettingsRepository();
      accountRepository = MockAccountRepository();
      custodianRepository = MockCustodianRepository();
      jarRepository = MockJarRepository();
      transactionRepository = MockTransactionRepository();
      getRateAt = MockGetRateAtUseCase();

      eur = AssetId.fromString('asset-eur');
      usd = AssetId.fromString('asset-usd');

      custodian = custodianFixture(id: 'custodian-bank', name: 'Test Bank');

      account = accountFixture(
        id: 'account-eur',
        name: 'EUR Account',
        custodianId: custodian.id.value,
        denominationAssetId: eur.value,
      );

      jar = jarFixture(id: 'jar-travel', name: 'Travel');

      transaction = _transactionFixture(
        account: account,
        jar: jar,
        transactionAssetId: eur,
        valuationAssetId: usd,
      );

      when(
        () => settingsRepository.get(),
      ).thenAnswer((_) async => Success(Settings(valuationCurrencyId: usd)));

      when(
        () => accountRepository.getAll(),
      ).thenAnswer((_) async => Success<List<Account>>([account]));

      when(
        () => custodianRepository.getAll(),
      ).thenAnswer((_) async => Success<List<Custodian>>([custodian]));

      when(
        () => jarRepository.getAll(),
      ).thenAnswer((_) async => Success<List<Jar>>([jar]));

      when(
        () => transactionRepository.getAll(),
      ).thenAnswer((_) async => Success<List<Transaction>>([transaction]));

      final eurUsdRate = exchangeRateFixture(
        id: 'rate-eur-usd',
        baseAssetId: eur.value,
        quoteAssetId: usd.value,
        rate: '1.2',
        effectiveAt: DateTime.utc(2026, 9, 1),
      );

      when(
        () => getRateAt(
          baseAssetId: eur,
          quoteAssetId: usd,
          at: any(named: 'at'),
        ),
      ).thenAnswer((_) async => Success(eurUsdRate));

      final resolveConversionRate = ResolveConversionRateService(
        getRateAt: getRateAt,
        canonicalBridgeAssetId: usd,
        rateConversion: const RateConversionService(),
      );

      container = ProviderContainer(
        overrides: [
          validatedDatabaseProvider.overrideWithValue(database),
          clockProvider.overrideWithValue(FixedClock(capturedAt)),
          getSettingsUseCaseProvider.overrideWithValue(
            GetSettingsUseCase(settingsRepository),
          ),
          getAccountsUseCaseProvider.overrideWithValue(
            GetAccountsUseCase(accountRepository),
          ),
          getCustodiansUseCaseProvider.overrideWithValue(
            GetCustodiansUseCase(custodianRepository),
          ),
          getJarsUseCaseProvider.overrideWithValue(
            GetJarsUseCase(jarRepository),
          ),
          getAllTransactionsUseCaseProvider.overrideWithValue(
            GetAllTransactionsUseCase(transactionRepository),
          ),
          resolveConversionRateServiceProvider.overrideWithValue(
            resolveConversionRate,
          ),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await database.close();
    });

    test('captures, persists, replaces idempotently, and exposes ordered '
        'historical balances', () async {
      // Given
      final capture = container.read(captureBalanceSnapshotsServiceProvider);

      final historical = container.read(historicalBalanceQueryServiceProvider);

      final snapshotRepository = container.read(
        balanceSnapshotRepositoryProvider,
      );

      final september18 = CalendarDate(2026, 9, 18);
      final september19 = CalendarDate(2026, 9, 19);
      final september20 = CalendarDate(2026, 9, 20);
      final september21 = CalendarDate(2026, 9, 21);

      // When: capture the first historical day.
      final firstCaptureResult = await capture(september18);

      // Then
      expect(firstCaptureResult.isSuccess, isTrue);
      expect(firstCaptureResult.failureOrNull, isNull);

      final firstSnapshots = firstCaptureResult.valueOrNull!;

      expect(firstSnapshots, hasLength(3));

      expect(
        firstSnapshots.every(
          (snapshot) => snapshot.snapshotDate == september18,
        ),
        isTrue,
      );

      expect(
        firstSnapshots.every((snapshot) => snapshot.capturedAt == capturedAt),
        isTrue,
      );

      expect(
        firstSnapshots.where((snapshot) => snapshot.subject.isAccount),
        hasLength(1),
      );

      expect(
        firstSnapshots.where((snapshot) => snapshot.subject.isCustodian),
        hasLength(1),
      );

      expect(
        firstSnapshots.where((snapshot) => snapshot.subject.isJar),
        hasLength(1),
      );

      // The snapshot bounded context deliberately has no category or budget
      // subject representation.
      expect(
        firstSnapshots.every(
          (snapshot) =>
              snapshot.subject.isAccount ||
              snapshot.subject.isCustodian ||
              snapshot.subject.isJar,
        ),
        isTrue,
      );

      final accountSnapshot = firstSnapshots.singleWhere(
        (snapshot) => snapshot.subject.isAccount,
      );

      final custodianSnapshot = firstSnapshots.singleWhere(
        (snapshot) => snapshot.subject.isCustodian,
      );

      final jarSnapshot = firstSnapshots.singleWhere(
        (snapshot) => snapshot.subject.isJar,
      );

      // Account holdings are EUR 10 outgoing.
      expect(accountSnapshot.assetBalances, hasLength(1));
      expect(accountSnapshot.assetBalances.single.assetId, eur);
      expect(accountSnapshot.assetBalances.single.amount, Decimal.parse('10'));
      expect(accountSnapshot.assetBalances.single.isOutgoing, isTrue);

      // Account denomination remains EUR.
      expect(accountSnapshot.denominationAmount.assetId, eur);
      expect(accountSnapshot.denominationAmount.amount, Decimal.parse('10'));
      expect(accountSnapshot.denominationAmount.isOutgoing, isTrue);

      // User-base valuation uses EUR/USD = 1.2.
      expect(accountSnapshot.valuationAmount.assetId, usd);
      expect(accountSnapshot.valuationAmount.amount, Decimal.parse('12.0'));
      expect(accountSnapshot.valuationAmount.isOutgoing, isTrue);

      // Custodians are base-denominated.
      expect(custodianSnapshot.denominationAmount.assetId, usd);
      expect(custodianSnapshot.valuationAmount.assetId, usd);
      expect(
        custodianSnapshot.denominationAmount,
        custodianSnapshot.valuationAmount,
      );
      expect(custodianSnapshot.valuationAmount.amount, Decimal.parse('12.0'));

      // Jars are also base-denominated and use the persisted split valuation.
      expect(jarSnapshot.denominationAmount.assetId, usd);
      expect(jarSnapshot.valuationAmount.assetId, usd);
      expect(jarSnapshot.denominationAmount, jarSnapshot.valuationAmount);
      expect(jarSnapshot.valuationAmount.amount, Decimal.parse('12'));

      final recordsAfterFirstCapture = await SembastStores.balanceSnapshots
          .find(database);

      expect(recordsAfterFirstCapture, hasLength(3));

      // When: capture the same subject/date set again.
      final repeatedCaptureResult = await capture(september18);

      // Then: natural-key replacement is idempotent.
      expect(repeatedCaptureResult.isSuccess, isTrue);

      final recordsAfterRepeatedCapture = await SembastStores.balanceSnapshots
          .find(database);

      expect(recordsAfterRepeatedCapture, hasLength(3));

      // When: capture another day.
      final laterCaptureResult = await capture(september20);

      // Then
      expect(laterCaptureResult.isSuccess, isTrue);

      final recordsAfterLaterCapture = await SembastStores.balanceSnapshots
          .find(database);

      // Three subjects x two represented dates.
      expect(recordsAfterLaterCapture, hasLength(6));

      expect(
        recordsAfterLaterCapture.where(
          (record) =>
              record.key.startsWith('category|') ||
              record.key.startsWith('budget|'),
        ),
        isEmpty,
      );

      // Repository queries return only persisted snapshots, ordered by date.
      final persistedRangeResult = await snapshotRepository.getByDateRange(
        subject: BalanceSnapshotSubject.account(account.id),
        range: BalanceSnapshotDateRange(from: september18, until: september21),
      );

      expect(persistedRangeResult.isSuccess, isTrue);

      final persistedRange = persistedRangeResult.valueOrNull!;

      expect(persistedRange, hasLength(2));

      expect(persistedRange.map((snapshot) => snapshot.snapshotDate).toList(), [
        september18,
        september20,
      ]);

      // [from, until): September 20 is excluded here.
      final boundedRangeResult = await snapshotRepository.getByDateRange(
        subject: BalanceSnapshotSubject.account(account.id),
        range: BalanceSnapshotDateRange(from: september18, until: september20),
      );

      expect(boundedRangeResult.isSuccess, isTrue);

      expect(
        boundedRangeResult.valueOrNull!
            .map((snapshot) => snapshot.snapshotDate)
            .toList(),
        [september18],
      );

      // Exact missing-date lookup must not substitute September 18.
      final missingExactResult = await historical.getAccountByDate(
        accountId: account.id,
        snapshotDate: september19,
      );

      expect(missingExactResult.isSuccess, isTrue);

      final missingExact = missingExactResult.valueOrNull!;

      expect(missingExact.date, september19);
      expect(missingExact.isMissing, isTrue);
      expect(missingExact.snapshot, isNull);

      // Historical ranges contain one point per requested day.
      final historicalRangeResult = await historical.getAccountByDateRange(
        accountId: account.id,
        range: BalanceSnapshotDateRange(from: september18, until: september21),
      );

      expect(historicalRangeResult.isSuccess, isTrue);

      final historicalRange = historicalRangeResult.valueOrNull!;

      expect(historicalRange, hasLength(3));

      expect(historicalRange.map((point) => point.date).toList(), [
        september18,
        september19,
        september20,
      ]);

      expect(historicalRange[0].isMissing, isFalse);
      expect(historicalRange[1].isMissing, isTrue);
      expect(historicalRange[2].isMissing, isFalse);

      // Exact custodian and jar queries travel through the same persisted
      // snapshot repository.
      final custodianExactResult = await historical.getCustodianByDate(
        custodianId: custodian.id,
        snapshotDate: september18,
      );

      expect(custodianExactResult.isSuccess, isTrue);
      expect(custodianExactResult.valueOrNull!.isMissing, isFalse);

      final jarExactResult = await historical.getJarByDate(
        jarId: jar.id,
        snapshotDate: september18,
      );

      expect(jarExactResult.isSuccess, isTrue);
      expect(jarExactResult.valueOrNull!.isMissing, isFalse);
    });

    test('translates corrupt persisted snapshot data through the historical '
        'query boundary', () async {
      // Given
      final date = CalendarDate(2026, 9, 19);

      final recordKey = 'account|${account.id.value}|$date';

      await SembastStores.balanceSnapshots.record(recordKey).put(
        database,
        <String, Object?>{
          // Deliberately incomplete version-1 record.
          'recordVersion': 1,
        },
      );

      final historical = container.read(historicalBalanceQueryServiceProvider);

      // When
      final result = await historical.getAccountByDate(
        accountId: account.id,
        snapshotDate: date,
      );

      // Then
      expect(result.isFailure, isTrue);
      expect(result.valueOrNull, isNull);
      expect(result.failureOrNull, isA<BalanceSnapshotRepositoryFailure>());
    });
  });
}

Transaction _transactionFixture({
  required Account account,
  required Jar jar,
  required AssetId transactionAssetId,
  required AssetId valuationAssetId,
}) {
  final transactionAmount = AssetAmount.outgoing(
    assetId: transactionAssetId,
    amount: Decimal.parse('10'),
  );

  final valuationAmount = AssetAmount.outgoing(
    assetId: valuationAssetId,
    amount: Decimal.parse('12'),
  );

  final timestamp = DateTime.utc(2026, 9, 18, 10);

  return Transaction(
    id: TransactionId.fromString('transaction-snapshot-integration'),
    kind: TransactionKind.expense,
    merchantId: MerchantId.self,
    effectiveAt: timestamp,
    description: 'Snapshot integration transaction',
    note: null,
    state: TransactionState.actual,
    tagIds: const [],
    splits: [
      TransactionSplit(
        transactionAmount: transactionAmount,
        valuationAmount: valuationAmount,
        jarId: jar.id,
      ),
    ],
    ledgerEntries: [
      LedgerEntry(
        accountId: account.id,
        transactionAmount: transactionAmount,
        accountAmount: transactionAmount,
        valuationAmount: valuationAmount,
        role: LedgerEntryRole.primary,
      ),
    ],
    createdAt: timestamp,
    modifiedAt: timestamp,
    entityVersion: 1,
  );
}
