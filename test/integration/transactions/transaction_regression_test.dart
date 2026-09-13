import 'package:axiom/src/application/services/create_transaction_service.dart';
import 'package:axiom/src/application/services/update_transaction_service.dart';
import 'package:axiom/src/application/services/validate_transaction_allocations_service.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/categories/application/use_cases/get_category_by_id_use_case.dart';
import 'package:axiom/src/features/categories/data/repositories/in_memory_category_repository_impl.dart';
import 'package:axiom/src/features/transactions/application/commands/create_transaction_command.dart';
import 'package:axiom/src/features/transactions/application/use_cases/create_transaction_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/update_transaction_use_case.dart';
import 'package:axiom/src/features/transactions/data/repositories/in_memory_transaction_repository_impl.dart';
import 'package:axiom/src/features/transactions/domain/enums/ledger_entry_role.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_kind.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_state.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/ledger_entry.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

void main() {
  group('Transaction regression', () {
    final timestamp = DateTime.utc(2026, 1, 1);
    late InMemoryTransactionRepositoryImpl repository;
    late CreateTransactionService createService;
    late UpdateTransactionService updateService;

    setUp(() {
      repository = InMemoryTransactionRepositoryImpl(
        initialTransactions: const [],
      );
      final validateAllocations = ValidateTransactionAllocationsService(
        getCategoryById: GetCategoryByIdUseCase(
          InMemoryCategoryRepositoryImpl(initialCategories: const []),
        ),
      );
      createService = CreateTransactionService(
        clock: FixedClock(timestamp),
        createTransaction: CreateTransactionUseCase(repository: repository),
        validateAllocations: validateAllocations,
      );
      updateService = UpdateTransactionService(
        updateTransaction: UpdateTransactionUseCase(repository),
        validateAllocations: validateAllocations,
      );
    });

    for (final kind in TransactionKind.values) {
      test('creates and persists an unallocated ${kind.name}', () async {
        // Given
        final command = CreateTransactionCommand(
          kind: kind,
          merchantId: MerchantId.self,
          effectiveAt: timestamp,
          description: kind.name,
          state: TransactionState.actual,
          splits: const [],
          ledgerEntries: _ledgerEntriesFor(kind),
        );

        // When
        final result = await createService(command);

        // Then
        expect(result.isSuccess, isTrue);
        final transaction = result.valueOrNull!;
        expect(transaction.kind, kind);
        expect(transaction.splits, isEmpty);
        expect(
          (await repository.getById(transaction.id)).valueOrNull,
          same(transaction),
        );
      });
    }

    test('updates and persists an unallocated transaction', () async {
      // Given
      final created = (await createService(
        CreateTransactionCommand(
          kind: TransactionKind.expense,
          merchantId: MerchantId.self,
          effectiveAt: timestamp,
          description: 'Original',
          state: TransactionState.actual,
          splits: const [],
          ledgerEntries: _ledgerEntriesFor(TransactionKind.expense),
        ),
      )).valueOrNull!;
      final updated = created.copyWith(description: 'Updated');

      // When
      final result = await updateService(updated);

      // Then
      expect(result.isSuccess, isTrue);
      final persisted = (await repository.getById(created.id)).valueOrNull!;
      expect(persisted.description, 'Updated');
      expect(persisted.splits, isEmpty);
      expect(persisted.ledgerEntries, created.ledgerEntries);
    });
  });
}

List<LedgerEntry> _ledgerEntriesFor(TransactionKind kind) {
  final outgoing = _amount(incoming: false);
  final incoming = _amount(incoming: true);

  return switch (kind) {
    TransactionKind.expense => [_entry('account-expense', outgoing)],
    TransactionKind.income => [_entry('account-income', incoming)],
    TransactionKind.balanceCorrection => [
      _entry('account-correction', outgoing),
    ],
    TransactionKind.transfer => [
      _entry('account-from', outgoing),
      _entry('account-to', incoming),
    ],
  };
}

LedgerEntry _entry(String accountId, AssetAmount amount) {
  return LedgerEntry(
    accountId: AccountId.fromString(accountId),
    transactionAmount: amount,
    accountAmount: amount,
    valuationAmount: amount,
    role: LedgerEntryRole.primary,
  );
}

AssetAmount _amount({required bool incoming}) {
  final assetId = AssetId.fromString('asset-eur');
  final amount = Decimal.fromInt(10);
  return incoming
      ? AssetAmount.incoming(assetId: assetId, amount: amount)
      : AssetAmount.outgoing(assetId: assetId, amount: amount);
}
