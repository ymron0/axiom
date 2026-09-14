@Tags(['application'])
library;

import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/application/services/get_jar_progress_service.dart';
import 'package:axiom/src/features/jars/application/use_cases/get_jar_by_id_use_case.dart';
import 'package:axiom/src/features/jars/domain/services/jar_balance_calculator.dart';
import 'package:axiom/src/features/jars/domain/services/jar_progress_calculator.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_not_found_failure.dart';
import 'package:axiom/src/features/settings/application/use_cases/get_settings_use_case.dart';
import 'package:axiom/src/features/settings/domain/entities/settings.dart';
import 'package:axiom/src/features/assets/domain/enums/asset_amount_direction.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/enums/ledger_entry_role.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_kind.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_state.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/ledger_entry.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/transaction_split.dart';
import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/identity/ids/transaction_id.dart';
import 'package:decimal/decimal.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_transactions_by_jar_id_use_case.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_not_found_failure.dart';
import 'package:decimal/decimal.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../fixtures/features/jars/jar_fixtures.dart';
import '../../../mocks/jar_repository_mock.dart';
import '../../../mocks/settings_repository_mock.dart';
import '../../../mocks/transaction_repository_mock.dart';



void main() {
  group('GetJarProgressService', () {
    final now = DateTime.utc(2026, 2, 1);
    final jarId = JarId.fromString('jar-1');
    final currencyId = AssetId.fromString('currency-chf');
    late MockJarRepository jarRepository;
    late MockSettingsRepository settingsRepository;
    late MockTransactionRepository transactionRepository;
    late GetJarProgressService service;

    setUp(() {
      jarRepository = MockJarRepository();
      settingsRepository = MockSettingsRepository();
      transactionRepository = MockTransactionRepository();
      service = GetJarProgressService(
        getJarById: GetJarByIdUseCase(jarRepository),
        getSettings: GetSettingsUseCase(settingsRepository),
        getTransactionsByJarId: GetTransactionsByJarIdUseCase(
          transactionRepository,
        ),
        balanceCalculator: const JarBalanceCalculator(),
        progressCalculator: const JarProgressCalculator(),
        clock: FixedClock(now),
      );
    });

    test('returns not-found when the jar lookup succeeds with null', () async {
      when(() => jarRepository.getById(jarId)).thenAnswer(
        (_) async => const Success(null),
      );

      final result = await service(jarId);

      expect(result.failureOrNull, isA<JarNotFoundFailure>());
    });

    test('propagates transaction lookup failures', () async {
      final jar = jarFixture(id: jarId.value);
      const failure = TransactionNotFoundFailure(message: 'lookup failed');
      when(() => jarRepository.getById(jarId)).thenAnswer((_) async => Success(jar));
      when(() => settingsRepository.get()).thenAnswer(
        (_) async => Success(Settings(valuationCurrencyId: currencyId)),
      );
      when(() => transactionRepository.getTransactionsByJarId(jarId)).thenAnswer(
        (_) async => failure,
      );

      final result = await service(jarId);

      expect(result.failureOrNull, same(failure));
    });

    test('returns zero progress when there are no eligible allocations', () async {
      final jar = jarFixture(id: jarId.value);
      when(() => jarRepository.getById(jarId)).thenAnswer((_) async => Success(jar));
      when(() => settingsRepository.get()).thenAnswer(
        (_) async => Success(Settings(valuationCurrencyId: currencyId)),
      );
      when(() => transactionRepository.getTransactionsByJarId(jarId)).thenAnswer(
        (_) async => const Success([]),
      );

      final result = await service(jarId);

      expect(result, isA<Success>());
      expect(result.valueOrNull?.balance.amount, Decimal.zero);
      verify(() => transactionRepository.getTransactionsByJarId(jarId)).called(1);
    });

    test('includes only actual, effective allocations for the requested jar', () async {
      final jar = jarFixture(id: jarId.value);
      final otherJarId = JarId.fromString('other-jar');
      when(() => jarRepository.getById(jarId)).thenAnswer((_) async => Success(jar));
      when(() => settingsRepository.get()).thenAnswer(
        (_) async => Success(Settings(valuationCurrencyId: currencyId)),
      );
      when(() => transactionRepository.getTransactionsByJarId(jarId)).thenAnswer(
        (_) async => Success([
          _transaction(
            id: 'planned',
            jarId: jarId,
            state: TransactionState.planned,
            effectiveAt: now,
          ),
          _transaction(
            id: 'future',
            jarId: jarId,
            effectiveAt: now.add(const Duration(days: 1)),
          ),
          _transaction(
            id: 'other-jar',
            jarId: otherJarId,
            effectiveAt: now,
          ),
          _transaction(id: 'eligible', jarId: jarId, effectiveAt: now),
        ]),
      );

      final result = await service(jarId);

      expect(result.valueOrNull?.balance.amount, Decimal.fromInt(10));
    });
  });
}

Transaction _transaction({
  required String id,
  required JarId jarId,
  required DateTime effectiveAt,
  TransactionState state = TransactionState.actual,
}) {
  final amount = AssetAmount(
    assetId: AssetId.fromString('currency-chf'),
    amount: Decimal.fromInt(10),
    direction: AssetAmountDirection.outgoing,
  );
  return Transaction(
    id: TransactionId.fromString(id),
    kind: TransactionKind.expense,
    merchantId: MerchantId.self,
    effectiveAt: effectiveAt,
    description: 'Test transaction',
    note: null,
    state: state,
    deletedAt: null,
    splits: [
      TransactionSplit(
        transactionAmount: amount,
        valuationAmount: amount,
        jarId: jarId,
      ),
    ],
    ledgerEntries: [
      LedgerEntry(
        accountId: AccountId.fromString('account-chf'),
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
