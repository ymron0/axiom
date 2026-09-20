@Tags(['application'])
library;

import 'package:axiom/src/application/failures/transaction_would_make_jar_balance_negative_failure.dart';
import 'package:axiom/src/application/services/validate_transaction_jar_balances_service.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/identity/ids/transaction_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/jars/domain/services/jar_balance_calculator.dart';
import 'package:axiom/src/features/settings/application/use_cases/get_settings_use_case.dart';
import 'package:axiom/src/features/settings/domain/entities/settings.dart';
import 'package:axiom/src/features/settings/domain/failures/settings_repository_failure.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_transactions_by_jar_id_use_case.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/enums/ledger_entry_role.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_kind.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_state.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_repository_failure.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/ledger_entry.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/transaction_split.dart';
import 'package:decimal/decimal.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../mocks/settings_repository_mock.dart';
import '../../../mocks/transaction_repository_mock.dart';

void main() {
  group('ValidateTransactionJarBalancesService', () {
    final chf = AssetId.fromString('asset-chf');
    final jarId = JarId.fromString('holiday');

    late MockSettingsRepository settingsRepository;
    late MockTransactionRepository transactionRepository;
    late ValidateTransactionJarBalancesService service;

    setUpAll(() {
      registerFallbackValue(JarId.fromString('fallback-jar'));
    });

    setUp(() {
      settingsRepository = MockSettingsRepository();
      transactionRepository = MockTransactionRepository();

      service = ValidateTransactionJarBalancesService(
        getSettings: GetSettingsUseCase(settingsRepository),
        getTransactionsByJarId: GetTransactionsByJarIdUseCase(
          transactionRepository,
        ),
        calculator: const JarBalanceCalculator(),
      );

      when(() => settingsRepository.get()).thenAnswer(
        (_) async => Success<Settings?>(
          Settings(valuationCurrencyId: chf, allowNegativeJarBalances: false),
        ),
      );
    });

    test('allows negative balances when the setting is enabled', () async {
      final candidate = _transaction(
        id: 'candidate',
        jarId: jarId,
        assetId: chf,
        amount: '100',
      );

      when(() => settingsRepository.get()).thenAnswer(
        (_) async => Success<Settings?>(
          Settings(valuationCurrencyId: chf, allowNegativeJarBalances: true),
        ),
      );

      final result = await service(candidate);

      expect(result.isSuccess, isTrue);

      verifyNever(() => transactionRepository.getTransactionsByJarId(any()));
    });

    test('rejects an expense that makes a positive balance negative', () async {
      final existingIncome = _transaction(
        id: 'income',
        jarId: jarId,
        assetId: chf,
        amount: '10',
        kind: TransactionKind.income,
        effectiveAt: DateTime.utc(2026, 1, 1),
      );

      final candidate = _transaction(
        id: 'expense',
        jarId: jarId,
        assetId: chf,
        amount: '11',
        effectiveAt: DateTime.utc(2026, 1, 2),
      );

      when(
        () => transactionRepository.getTransactionsByJarId(jarId),
      ).thenAnswer((_) async => Success<List<Transaction>>([existingIncome]));

      final result = await service(candidate);

      expect(
        result.failureOrNull,
        isA<TransactionWouldMakeJarBalanceNegativeFailure>(),
      );

      expect(result.failureOrNull?.message, contains('Current balance: 10'));

      expect(result.failureOrNull?.message, contains('Projected balance: -1'));
    });

    test('allows reducing the balance exactly to zero', () async {
      final existingIncome = _transaction(
        id: 'income',
        jarId: jarId,
        assetId: chf,
        amount: '10',
        kind: TransactionKind.income,
        effectiveAt: DateTime.utc(2026, 1, 1),
      );

      final candidate = _transaction(
        id: 'expense',
        jarId: jarId,
        assetId: chf,
        amount: '10',
        effectiveAt: DateTime.utc(2026, 1, 2),
      );

      when(
        () => transactionRepository.getTransactionsByJarId(jarId),
      ).thenAnswer((_) async => Success<List<Transaction>>([existingIncome]));

      final result = await service(candidate);

      expect(result.isSuccess, isTrue);
    });

    test('allows improving an existing negative balance', () async {
      final existingExpense = _transaction(
        id: 'existing-expense',
        jarId: jarId,
        assetId: chf,
        amount: '10',
        effectiveAt: DateTime.utc(2026, 1, 1),
      );

      final candidate = _transaction(
        id: 'refund',
        jarId: jarId,
        assetId: chf,
        amount: '4',
        kind: TransactionKind.income,
        effectiveAt: DateTime.utc(2026, 1, 2),
      );

      when(
        () => transactionRepository.getTransactionsByJarId(jarId),
      ).thenAnswer((_) async => Success<List<Transaction>>([existingExpense]));

      final result = await service(candidate);

      expect(result.isSuccess, isTrue);
    });

    test('rejects worsening an existing negative balance', () async {
      final existingExpense = _transaction(
        id: 'existing-expense',
        jarId: jarId,
        assetId: chf,
        amount: '10',
        effectiveAt: DateTime.utc(2026, 1, 1),
      );

      final candidate = _transaction(
        id: 'candidate',
        jarId: jarId,
        assetId: chf,
        amount: '1',
        effectiveAt: DateTime.utc(2026, 1, 2),
      );

      when(
        () => transactionRepository.getTransactionsByJarId(jarId),
      ).thenAnswer((_) async => Success<List<Transaction>>([existingExpense]));

      final result = await service(candidate);

      expect(
        result.failureOrNull,
        isA<TransactionWouldMakeJarBalanceNegativeFailure>(),
      );

      expect(result.failureOrNull?.message, contains('Projected balance: -11'));
    });

    test(
      'rejects a backdated transaction that creates a negative history',
      () async {
        final laterIncome = _transaction(
          id: 'later-income',
          jarId: jarId,
          assetId: chf,
          amount: '10',
          kind: TransactionKind.income,
          effectiveAt: DateTime.utc(2026, 1, 2),
        );

        final candidate = _transaction(
          id: 'backdated-expense',
          jarId: jarId,
          assetId: chf,
          amount: '1',
          effectiveAt: DateTime.utc(2026, 1, 1),
        );

        when(
          () => transactionRepository.getTransactionsByJarId(jarId),
        ).thenAnswer((_) async => Success<List<Transaction>>([laterIncome]));

        final result = await service(candidate);

        expect(
          result.failureOrNull,
          isA<TransactionWouldMakeJarBalanceNegativeFailure>(),
        );

        expect(result.failureOrNull?.message, contains('2026-01-01'));
      },
    );

    test(
      'rejects an update that removes income required by a later expense',
      () async {
        final previous = _transaction(
          id: 'same',
          jarId: jarId,
          assetId: chf,
          amount: '10',
          kind: TransactionKind.income,
          effectiveAt: DateTime.utc(2026, 1, 1),
        );

        final laterExpense = _transaction(
          id: 'expense',
          jarId: jarId,
          assetId: chf,
          amount: '8',
          effectiveAt: DateTime.utc(2026, 1, 2),
        );

        final replacement = _transaction(
          id: 'same',
          jarId: null,
          assetId: chf,
          amount: '10',
          kind: TransactionKind.income,
          effectiveAt: DateTime.utc(2026, 1, 1),
        );

        when(
          () => transactionRepository.getTransactionsByJarId(jarId),
        ).thenAnswer(
          (_) async => Success<List<Transaction>>([previous, laterExpense]),
        );

        final result = await service(replacement, previous: previous);

        expect(
          result.failureOrNull,
          isA<TransactionWouldMakeJarBalanceNegativeFailure>(),
        );

        expect(
          result.failureOrNull?.message,
          contains('Projected balance: -8'),
        );
      },
    );

    test('allows an update that improves a negative balance', () async {
      final previous = _transaction(
        id: 'same',
        jarId: jarId,
        assetId: chf,
        amount: '10',
        effectiveAt: DateTime.utc(2026, 1, 1),
      );

      final replacement = _transaction(
        id: 'same',
        jarId: jarId,
        assetId: chf,
        amount: '5',
        effectiveAt: DateTime.utc(2026, 1, 1),
      );

      when(
        () => transactionRepository.getTransactionsByJarId(jarId),
      ).thenAnswer((_) async => Success<List<Transaction>>([previous]));

      final result = await service(replacement, previous: previous);

      expect(result.isSuccess, isTrue);
    });

    test('groups transactions sharing the same effective instant', () async {
      final income = _transaction(
        id: 'income',
        jarId: jarId,
        assetId: chf,
        amount: '10',
        kind: TransactionKind.income,
        effectiveAt: DateTime.utc(2026, 1, 1),
      );

      final expense = _transaction(
        id: 'expense',
        jarId: jarId,
        assetId: chf,
        amount: '10',
        effectiveAt: DateTime.utc(2026, 1, 1),
      );

      when(
        () => transactionRepository.getTransactionsByJarId(jarId),
      ).thenAnswer((_) async => Success<List<Transaction>>([income]));

      final result = await service(expense);

      expect(result.isSuccess, isTrue);
    });

    test('does not enforce jar balances for a planned creation', () async {
      final planned = _transaction(
        id: 'planned',
        jarId: jarId,
        assetId: chf,
        amount: '100',
        state: TransactionState.planned,
      );

      final result = await service(planned);

      expect(result.isSuccess, isTrue);

      verifyNever(() => settingsRepository.get());

      verifyNever(() => transactionRepository.getTransactionsByJarId(any()));
    });

    test(
      'validates removal when an actual transaction becomes planned',
      () async {
        final previous = _transaction(
          id: 'same',
          jarId: jarId,
          assetId: chf,
          amount: '10',
          kind: TransactionKind.income,
          effectiveAt: DateTime.utc(2026, 1, 1),
        );

        final expense = _transaction(
          id: 'expense',
          jarId: jarId,
          assetId: chf,
          amount: '5',
          effectiveAt: DateTime.utc(2026, 1, 2),
        );

        final replacement = _transaction(
          id: 'same',
          jarId: jarId,
          assetId: chf,
          amount: '10',
          kind: TransactionKind.income,
          state: TransactionState.planned,
          effectiveAt: DateTime.utc(2026, 1, 1),
        );

        when(
          () => transactionRepository.getTransactionsByJarId(jarId),
        ).thenAnswer(
          (_) async => Success<List<Transaction>>([previous, expense]),
        );

        final result = await service(replacement, previous: previous);

        expect(
          result.failureOrNull,
          isA<TransactionWouldMakeJarBalanceNegativeFailure>(),
        );
      },
    );

    test('returns settings-not-initialized failure', () async {
      final candidate = _transaction(
        id: 'candidate',
        jarId: jarId,
        assetId: chf,
        amount: '1',
      );

      when(
        () => settingsRepository.get(),
      ).thenAnswer((_) async => const Success<Settings?>(null));

      final result = await service(candidate);

      expect(result.failureOrNull, isNotNull);
    });

    test('propagates settings failures', () async {
      final candidate = _transaction(
        id: 'candidate',
        jarId: jarId,
        assetId: chf,
        amount: '1',
      );

      const failure = SettingsRepositoryFailure(message: 'settings failed');

      when(() => settingsRepository.get()).thenAnswer((_) async => failure);

      final result = await service(candidate);

      expect(result.failureOrNull, same(failure));
    });

    test('propagates transaction lookup failures', () async {
      final candidate = _transaction(
        id: 'candidate',
        jarId: jarId,
        assetId: chf,
        amount: '1',
      );

      const failure = TransactionRepositoryFailure(
        message: 'transactions failed',
      );

      when(
        () => transactionRepository.getTransactionsByJarId(jarId),
      ).thenAnswer((_) async => failure);

      final result = await service(candidate);

      expect(result.failureOrNull, same(failure));
    });

    test('rejects mismatched previous transaction identity', () {
      final previous = _transaction(
        id: 'previous',
        jarId: jarId,
        assetId: chf,
        amount: '1',
      );

      final replacement = _transaction(
        id: 'replacement',
        jarId: jarId,
        assetId: chf,
        amount: '1',
      );

      expect(
        () => service(replacement, previous: previous),
        throwsArgumentError,
      );
    });
  });
}

Transaction _transaction({
  required String id,
  required AssetId assetId,
  required String amount,
  JarId? jarId,
  TransactionKind kind = TransactionKind.expense,
  TransactionState state = TransactionState.actual,
  DateTime? effectiveAt,
}) {
  if (kind != TransactionKind.expense && kind != TransactionKind.income) {
    throw ArgumentError.value(
      kind,
      'kind',
      'Jar-balance tests support expense and income transactions only.',
    );
  }

  final value = Decimal.parse(amount);

  final AssetAmount assetAmount = kind == TransactionKind.income
      ? AssetAmount.incoming(assetId: assetId, amount: value)
      : AssetAmount.outgoing(assetId: assetId, amount: value);

  final timestamp = DateTime.utc(2026, 1, 1);

  return Transaction(
    id: TransactionId.fromString(id),
    kind: kind,
    merchantId: MerchantId.self,
    effectiveAt: effectiveAt ?? DateTime.utc(2026, 1, 15),
    description: 'Jar balance test transaction',
    state: state,
    splits: jarId == null
        ? const []
        : [
            TransactionSplit(
              transactionAmount: assetAmount,
              valuationAmount: assetAmount,
              jarId: jarId,
            ),
          ],
    ledgerEntries: [
      LedgerEntry(
        accountId: AccountId.fromString('account-$id'),
        transactionAmount: assetAmount,
        accountAmount: assetAmount,
        valuationAmount: assetAmount,
        role: LedgerEntryRole.primary,
      ),
    ],
    createdAt: timestamp,
    modifiedAt: timestamp,
    entityVersion: 1,
  );
}
