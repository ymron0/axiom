@Tags(['application'])
library;

import 'package:axiom/src/application/services/get_jar_balance_service.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/identity/ids/transaction_id.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/domain/enums/asset_amount_direction.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/jars/application/use_cases/get_jar_by_id_use_case.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_not_found_failure.dart';
import 'package:axiom/src/features/jars/domain/services/jar_balance_calculator.dart';
import 'package:axiom/src/features/settings/application/use_cases/get_settings_use_case.dart';
import 'package:axiom/src/features/settings/domain/entities/settings.dart';
import 'package:axiom/src/features/settings/domain/failures/settings_not_initialized_failure.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_transactions_by_jar_id_use_case.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/enums/ledger_entry_role.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_kind.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_state.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_not_found_failure.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/ledger_entry.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/transaction_split.dart';
import 'package:decimal/decimal.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../fixtures/features/jars/jar_fixtures.dart';
import '../../../mocks/jar_repository_mock.dart';
import '../../../mocks/settings_repository_mock.dart';
import '../../../mocks/transaction_repository_mock.dart';

void main() {
  group('GetJarBalanceService', () {
    final now = DateTime.utc(2026, 9, 17, 10);
    final jarId = JarId.fromString('jar-1');
    final otherJarId = JarId.fromString('jar-other');

    final chf = AssetId.fromString('currency-chf');
    final eur = AssetId.fromString('currency-eur');

    late MockJarRepository jarRepository;
    late MockSettingsRepository settingsRepository;
    late MockTransactionRepository transactionRepository;
    late GetJarBalanceService service;

    setUp(() {
      jarRepository = MockJarRepository();
      settingsRepository = MockSettingsRepository();
      transactionRepository = MockTransactionRepository();

      service = GetJarBalanceService(
        getJarById: GetJarByIdUseCase(jarRepository),
        getSettings: GetSettingsUseCase(settingsRepository),
        getTransactionsByJarId: GetTransactionsByJarIdUseCase(
          transactionRepository,
        ),
        balanceCalculator: const JarBalanceCalculator(),
        clock: FixedClock(now),
      );
    });

    void stubJar() {
      final jar = jarFixture(id: jarId.value);

      when(
        () => jarRepository.getById(jarId),
      ).thenAnswer((_) async => Success(jar));
    }

    void stubSettings() {
      when(
        () => settingsRepository.get(),
      ).thenAnswer((_) async => Success(Settings(valuationCurrencyId: chf)));
    }

    void stubTransactions(List<Transaction> transactions) {
      when(
        () => transactionRepository.getTransactionsByJarId(jarId),
      ).thenAnswer((_) async => Success(transactions));
    }

    test(
      'returns jar-not-found when the jar lookup succeeds with null',
      () async {
        // Given
        when(
          () => jarRepository.getById(jarId),
        ).thenAnswer((_) async => const Success(null));

        // When
        final result = await service(jarId);

        // Then
        expect(result.failureOrNull, isA<JarNotFoundFailure>());

        expect(
          result.failureOrNull?.message,
          'Jar ID was not found: ${jarId.value}',
        );

        verifyNever(() => settingsRepository.get());

        verifyNever(() => transactionRepository.getTransactionsByJarId(jarId));
      },
    );

    test('propagates jar lookup failures unchanged', () async {
      // Given
      const failure = JarNotFoundFailure(message: 'jar lookup failed');

      when(() => jarRepository.getById(jarId)).thenAnswer((_) async => failure);

      // When
      final result = await service(jarId);

      // Then
      expect(result.failureOrNull, same(failure));

      verifyNever(() => settingsRepository.get());

      verifyNever(() => transactionRepository.getTransactionsByJarId(jarId));
    });

    test(
      'returns settings-not-initialized when settings do not exist',
      () async {
        // Given
        stubJar();

        when(
          () => settingsRepository.get(),
        ).thenAnswer((_) async => const Success(null));

        // When
        final result = await service(jarId);

        // Then
        expect(result.failureOrNull, isA<SettingsNotInitializedFailure>());

        expect(
          result.failureOrNull?.message,
          'Settings have not been initialized.',
        );

        verifyNever(() => transactionRepository.getTransactionsByJarId(jarId));
      },
    );

    test('propagates settings lookup failures unchanged', () async {
      // Given
      stubJar();

      const failure = SettingsNotInitializedFailure(
        message: 'settings lookup failed',
      );

      when(() => settingsRepository.get()).thenAnswer((_) async => failure);

      // When
      final result = await service(jarId);

      // Then
      expect(result.failureOrNull, same(failure));

      verifyNever(() => transactionRepository.getTransactionsByJarId(jarId));
    });

    test('propagates transaction lookup failures unchanged', () async {
      // Given
      stubJar();
      stubSettings();

      const failure = TransactionNotFoundFailure(
        message: 'transaction lookup failed',
      );

      when(
        () => transactionRepository.getTransactionsByJarId(jarId),
      ).thenAnswer((_) async => failure);

      // When
      final result = await service(jarId);

      // Then
      expect(result.failureOrNull, same(failure));
    });

    test('returns incoming zero in the valuation currency '
        'when there are no allocations', () async {
      // Given
      stubJar();
      stubSettings();
      stubTransactions(const []);

      // When
      final result = await service(jarId);

      // Then
      expect(result.failureOrNull, isNull);

      final balance = result.valueOrNull;

      expect(balance, isNotNull);
      expect(balance!.assetId, chf);
      expect(balance.amount, Decimal.zero);
      expect(balance.isIncoming, isTrue);
      expect(balance.isOutgoing, isFalse);

      verify(
        () => transactionRepository.getTransactionsByJarId(jarId),
      ).called(1);
    });

    test('includes only actual transactions effective at or before now '
        'for the requested jar', () async {
      // Given
      stubJar();
      stubSettings();

      stubTransactions([
        _transaction(
          id: 'planned',
          jarId: jarId,
          effectiveAt: now,
          state: TransactionState.planned,
          valuationAssetId: chf,
          valuationAmount: '100',
          direction: AssetAmountDirection.incoming,
        ),
        _transaction(
          id: 'future',
          jarId: jarId,
          effectiveAt: now.add(const Duration(microseconds: 1)),
          valuationAssetId: chf,
          valuationAmount: '200',
          direction: AssetAmountDirection.incoming,
        ),
        _transaction(
          id: 'other-jar',
          jarId: otherJarId,
          effectiveAt: now,
          valuationAssetId: chf,
          valuationAmount: '300',
          direction: AssetAmountDirection.incoming,
        ),
        _transaction(
          id: 'historical',
          jarId: jarId,
          effectiveAt: now.subtract(const Duration(days: 1)),
          valuationAssetId: chf,
          valuationAmount: '10',
          direction: AssetAmountDirection.incoming,
        ),
        _transaction(
          id: 'exactly-now',
          jarId: jarId,
          effectiveAt: now,
          valuationAssetId: chf,
          valuationAmount: '5',
          direction: AssetAmountDirection.incoming,
        ),
      ]);

      // When
      final result = await service(jarId);

      // Then
      expect(result.failureOrNull, isNull);

      final balance = result.valueOrNull;

      expect(balance, isNotNull);
      expect(balance!.assetId, chf);
      expect(balance.amount, Decimal.parse('15'));
      expect(balance.isIncoming, isTrue);
    });

    test(
      'nets incoming and outgoing allocations using their directions',
      () async {
        // Given
        stubJar();
        stubSettings();

        stubTransactions([
          _transaction(
            id: 'incoming',
            jarId: jarId,
            effectiveAt: now,
            valuationAssetId: chf,
            valuationAmount: '25.75',
            direction: AssetAmountDirection.incoming,
          ),
          _transaction(
            id: 'outgoing',
            jarId: jarId,
            effectiveAt: now,
            valuationAssetId: chf,
            valuationAmount: '10.25',
            direction: AssetAmountDirection.outgoing,
          ),
        ]);

        // When
        final result = await service(jarId);

        // Then
        expect(result.failureOrNull, isNull);

        final balance = result.valueOrNull;

        expect(balance, isNotNull);
        expect(balance!.assetId, chf);
        expect(balance.amount, Decimal.parse('15.50'));
        expect(balance.isIncoming, isTrue);
        expect(balance.isOutgoing, isFalse);
      },
    );

    test(
      'returns outgoing balance when outgoing allocations exceed incoming',
      () async {
        // Given
        stubJar();
        stubSettings();

        stubTransactions([
          _transaction(
            id: 'outgoing',
            jarId: jarId,
            effectiveAt: now,
            valuationAssetId: chf,
            valuationAmount: '30',
            direction: AssetAmountDirection.outgoing,
          ),
          _transaction(
            id: 'incoming',
            jarId: jarId,
            effectiveAt: now,
            valuationAssetId: chf,
            valuationAmount: '12.50',
            direction: AssetAmountDirection.incoming,
          ),
        ]);

        // When
        final result = await service(jarId);

        // Then
        expect(result.failureOrNull, isNull);

        final balance = result.valueOrNull;

        expect(balance, isNotNull);
        expect(balance!.assetId, chf);
        expect(balance.amount, Decimal.parse('17.50'));
        expect(balance.isIncoming, isFalse);
        expect(balance.isOutgoing, isTrue);
      },
    );

    test('uses the historical valuation amount rather than '
        'the transaction amount', () async {
      // Given
      stubJar();
      stubSettings();

      stubTransactions([
        _transaction(
          id: 'foreign-currency',
          jarId: jarId,
          effectiveAt: now,
          transactionAssetId: eur,
          transactionAmount: '100',
          valuationAssetId: chf,
          valuationAmount: '92.35',
          direction: AssetAmountDirection.incoming,
        ),
      ]);

      // When
      final result = await service(jarId);

      // Then
      expect(result.failureOrNull, isNull);

      final balance = result.valueOrNull;

      expect(balance, isNotNull);
      expect(balance!.assetId, chf);
      expect(balance.amount, Decimal.parse('92.35'));
      expect(balance.isIncoming, isTrue);
    });

    test('surfaces an argument error when an allocation uses '
        'a different valuation asset', () async {
      // Given
      stubJar();
      stubSettings();

      stubTransactions([
        _transaction(
          id: 'wrong-valuation-asset',
          jarId: jarId,
          effectiveAt: now,
          valuationAssetId: eur,
          valuationAmount: '10',
          direction: AssetAmountDirection.incoming,
        ),
      ]);

      // When / Then
      await expectLater(service(jarId), throwsA(isA<ArgumentError>()));
    });
  });
}

Transaction _transaction({
  required String id,
  required JarId jarId,
  required DateTime effectiveAt,
  required AssetId valuationAssetId,
  required String valuationAmount,
  required AssetAmountDirection direction,
  TransactionState state = TransactionState.actual,
  AssetId? transactionAssetId,
  String? transactionAmount,
}) {
  final effectiveTransactionAssetId = transactionAssetId ?? valuationAssetId;

  final effectiveTransactionAmount = transactionAmount ?? valuationAmount;

  final transactionAssetAmount = AssetAmount(
    assetId: effectiveTransactionAssetId,
    amount: Decimal.parse(effectiveTransactionAmount),
    direction: direction,
  );

  final valuationAssetAmount = AssetAmount(
    assetId: valuationAssetId,
    amount: Decimal.parse(valuationAmount),
    direction: direction,
  );

  return Transaction(
    id: TransactionId.fromString(id),
    kind: direction == AssetAmountDirection.incoming
        ? TransactionKind.income
        : TransactionKind.expense,
    merchantId: MerchantId.self,
    effectiveAt: effectiveAt,
    description: 'Test transaction',
    note: null,
    state: state,
    deletedAt: null,
    splits: [
      TransactionSplit(
        transactionAmount: transactionAssetAmount,
        valuationAmount: valuationAssetAmount,
        jarId: jarId,
      ),
    ],
    ledgerEntries: [
      LedgerEntry(
        accountId: AccountId.fromString('account-$id'),
        transactionAmount: transactionAssetAmount,
        accountAmount: transactionAssetAmount,
        valuationAmount: valuationAssetAmount,
        role: LedgerEntryRole.primary,
      ),
    ],
    createdAt: DateTime.utc(2026, 1, 1),
    modifiedAt: DateTime.utc(2026, 1, 1),
    entityVersion: 1,
  );
}
