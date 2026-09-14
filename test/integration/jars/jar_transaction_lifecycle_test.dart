@Tags(['integration'])
library;

import 'package:axiom/src/application/services/delete_jar_service.dart';
import 'package:axiom/src/core/domain/enums/entity_color.dart';
import 'package:axiom/src/core/domain/enums/entity_icon.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/identity/ids/transaction_id.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/jars/application/use_cases/archive_jar_use_case.dart';
import 'package:axiom/src/features/jars/application/use_cases/delete_jar_use_case.dart';
import 'package:axiom/src/features/jars/application/use_cases/restore_jar_use_case.dart';
import 'package:axiom/src/features/jars/data/repositories/in_memory_jar_repository_impl.dart';
import 'package:axiom/src/features/jars/domain/entities/jar.dart';
import 'package:axiom/src/features/jars/domain/enums/jar_kind.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_in_use_failure.dart';
import 'package:axiom/src/features/transactions/application/use_cases/create_transaction_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/transactions_exist_by_jar_id_use_case.dart';
import 'package:axiom/src/features/transactions/data/repositories/in_memory_transaction_repository_impl.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/enums/ledger_entry_role.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_kind.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_state.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/ledger_entry.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/transaction_split.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

void main() {
  group('Jar transaction lifecycle', () {
    final timestamp = DateTime.utc(2026, 9, 14);

    test('protects referenced jars and restores archived deleted snapshots',
        () async {
      // Given
      final jarRepository = InMemoryJarRepositoryImpl(initialJars: const []);
      final transactionRepository = InMemoryTransactionRepositoryImpl(
        initialTransactions: const [],
      );
      final deleteJar = DeleteJarUseCase(jarRepository);
      final deleteJarService = DeleteJarService(
        transactionsExistByJarId: TransactionsExistByJarIdUseCase(
          transactionRepository,
        ),
        deleteJar: deleteJar,
      );
      final archiveJar = ArchiveJarUseCase(
        repository: jarRepository,
        clock: FixedClock(timestamp),
      );
      final restoreJar = RestoreJarUseCase(jarRepository);
      final referencedJar = _jar('referenced-jar', timestamp);
      final unreferencedJar = _jar('unreferenced-jar', timestamp);
      await jarRepository.create(referencedJar);
      await jarRepository.create(unreferencedJar);
      await CreateTransactionUseCase(repository: transactionRepository)(
        _transactionReferencing(referencedJar.id, timestamp),
      );

      // When
      final referencedDeletion = await deleteJarService(referencedJar.id);
      final referencedArchive = await archiveJar(referencedJar.id);
      final unreferencedArchive = await archiveJar(unreferencedJar.id);
      final deletedSnapshot = await deleteJarService(unreferencedJar.id);
      final absentAfterDelete = await jarRepository.getById(unreferencedJar.id);
      final restoreResult = await restoreJar(deletedSnapshot.valueOrNull!);
      final restored = await jarRepository.getById(unreferencedJar.id);

      // Then
      expect(referencedDeletion.failureOrNull, isA<JarInUseFailure>());
      expect((await jarRepository.getById(referencedJar.id)).valueOrNull, isNotNull);
      expect(referencedArchive.isSuccess, isTrue);
      expect(referencedArchive.valueOrNull!.archivedAt, timestamp);

      expect(unreferencedArchive.isSuccess, isTrue);
      expect(deletedSnapshot.isSuccess, isTrue);
      expect(deletedSnapshot.valueOrNull!.archivedAt, timestamp);
      expect(deletedSnapshot.valueOrNull!.deletedAt, isNotNull);
      expect(absentAfterDelete.valueOrNull, isNull);

      expect(restoreResult.isSuccess, isTrue);
      expect(restored.valueOrNull!.deletedAt, isNull);
      expect(restored.valueOrNull!.archivedAt, timestamp);
    });
  });
}

Jar _jar(String id, DateTime timestamp) {
  return Jar(
    id: JarId.fromString(id),
    name: 'Jar $id',
    kind: JarKind.savingsGoal,
    icon: EntityIcon.savings,
    color: EntityColor.blue,
    sortOrder: 0,
    createdAt: timestamp,
    modifiedAt: timestamp,
    entityVersion: 1,
  );
}

Transaction _transactionReferencing(JarId jarId, DateTime timestamp) {
  final amount = AssetAmount.outgoing(
    assetId: AssetId.fromString('asset-chf'),
    amount: Decimal.one,
  );

  return Transaction(
    id: TransactionId.fromString('transaction-referencing-jar'),
    kind: TransactionKind.expense,
    merchantId: MerchantId.self,
    effectiveAt: timestamp,
    description: 'Jar allocation',
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
        accountId: AccountId.fromString('account-chf'),
        transactionAmount: amount,
        accountAmount: amount,
        valuationAmount: amount,
        role: LedgerEntryRole.primary,
      ),
    ],
    createdAt: timestamp,
    modifiedAt: timestamp,
    entityVersion: 1,
  );
}
