@Tags(['integration'])
library;

import 'dart:io';

import 'package:axiom/src/application/di/services/create_transaction_offset_service_provider.dart';
import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/core/di/database_lifecycle_service_provider.dart';
import 'package:axiom/src/core/di/database_root_path_provider.dart';
import 'package:axiom/src/core/persistence/database_lifecycle_service.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/features/transactions/di/get_transaction_offset_summary_use_case_provider.dart';
import 'package:axiom/src/features/transactions/di/transaction_repository_provider.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/enums/ledger_entry_role.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_offset_kind.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_offset_exceeds_available_amount_failure.dart';
import 'package:decimal/decimal.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

import '../../fixtures/features/transactions/transaction_offset_fixtures.dart';

void main() {
  group('Transaction offset workflow', () {
    late ProviderContainer container;
    late DatabaseLifecycleService lifecycleService;
    late Directory rootDirectory;

    setUp(() async {
      final rootPath = _uniqueRootPath();
      rootDirectory = Directory(rootPath);

      container = ProviderContainer(
        overrides: [
          databaseRootPathProvider.overrideWithValue(rootPath),
          clockProvider.overrideWithValue(FixedClock(DateTime.utc(2026, 1, 2))),
        ],
      );

      lifecycleService = container.read(databaseLifecycleServiceProvider);

      final openResult = await lifecycleService.open();

      expect(openResult.isSuccess, isTrue);
    });

    tearDown(() async {
      await lifecycleService.close();
      container.dispose();

      if (await rootDirectory.exists()) {
        await rootDirectory.delete(recursive: true);
      }
    });

    test(
      'persists a CHF 20 refund against CHF 100 and derives CHF 80 net',
      () async {
        // Given
        final repository = container.read(transactionRepositoryProvider);

        final original = offsetOriginalTransactionFixture(
          id: 'refund-original',
          amount: Decimal.fromInt(100),
        );

        final originalCreateResult = await repository.create(original);

        expect(originalCreateResult.isSuccess, isTrue);

        final command = transactionOffsetCommandFixture(
          originalTransactionId: original.id,
          amount: Decimal.fromInt(20),
          offsetKind: TransactionOffsetKind.refund,
        );

        final service = container.read(createTransactionOffsetServiceProvider);

        // When
        final createResult = await service(command);

        // Then
        expect(createResult.isSuccess, isTrue);

        final refund = createResult.valueOrNull!;

        expect(refund.isOffset, isTrue);
        expect(refund.offset?.originalTransactionId, original.id);
        expect(refund.offset?.kind, TransactionOffsetKind.refund);

        final persistedRefund = (await repository.getById(
          refund.id,
        )).valueOrNull;

        expect(persistedRefund, isNotNull);
        expect(persistedRefund!.id, refund.id);
        expect(persistedRefund.offset?.originalTransactionId, original.id);

        final persistedOriginal = (await repository.getById(
          original.id,
        )).valueOrNull!;

        // The original transaction remains immutable financial history.
        expect(_primaryAmount(persistedOriginal), Decimal.fromInt(100));

        final offsets = (await repository.getOffsetsForTransaction(
          original.id,
        )).valueOrNull!;

        expect(offsets, hasLength(1));
        expect(offsets.single.id, refund.id);

        final summaryResult = await container.read(
          getTransactionOffsetSummaryUseCaseProvider,
        )(original.id);

        expect(summaryResult.isSuccess, isTrue);

        final summary = summaryResult.valueOrNull!;

        expect(summary.grossAmount, Decimal.fromInt(100));
        expect(summary.refundAmount, Decimal.fromInt(20));
        expect(summary.reimbursementAmount, Decimal.zero);
        expect(summary.cashbackAmount, Decimal.zero);
        expect(summary.totalOffsetAmount, Decimal.fromInt(20));
        expect(summary.netAmount, Decimal.fromInt(80));
        expect(summary.isPartiallyOffset, isTrue);
        expect(summary.isFullyOffset, isFalse);
      },
    );

    test(
      'allows offsets exactly to full amount and atomically rejects excess',
      () async {
        // Given
        final repository = container.read(transactionRepositoryProvider);

        final original = offsetOriginalTransactionFixture(
          id: 'full-refund-original',
          amount: Decimal.fromInt(100),
        );

        expect((await repository.create(original)).isSuccess, isTrue);

        final service = container.read(createTransactionOffsetServiceProvider);

        final firstCommand = transactionOffsetCommandFixture(
          originalTransactionId: original.id,
          amount: Decimal.fromInt(60),
          offsetKind: TransactionOffsetKind.refund,
        );

        final secondCommand = transactionOffsetCommandFixture(
          originalTransactionId: original.id,
          amount: Decimal.fromInt(40),
          offsetKind: TransactionOffsetKind.refund,
        );

        final excessiveCommand = transactionOffsetCommandFixture(
          originalTransactionId: original.id,
          amount: Decimal.parse('0.01'),
          offsetKind: TransactionOffsetKind.refund,
        );

        // When
        final firstResult = await service(firstCommand);
        final secondResult = await service(secondCommand);
        final excessiveResult = await service(excessiveCommand);

        // Then
        expect(firstResult.isSuccess, isTrue);
        expect(secondResult.isSuccess, isTrue);

        expect(
          excessiveResult.failureOrNull,
          isA<TransactionOffsetExceedsAvailableAmountFailure>(),
        );

        final offsets = (await repository.getOffsetsForTransaction(
          original.id,
        )).valueOrNull!;

        // Failed creation must not leave a partially persisted transaction.
        expect(offsets, hasLength(2));

        final summaryResult = await container.read(
          getTransactionOffsetSummaryUseCaseProvider,
        )(original.id);

        final summary = summaryResult.valueOrNull!;

        expect(summary.grossAmount, Decimal.fromInt(100));
        expect(summary.refundAmount, Decimal.fromInt(100));
        expect(summary.totalOffsetAmount, Decimal.fromInt(100));
        expect(summary.netAmount, Decimal.zero);
        expect(summary.isFullyOffset, isTrue);
      },
    );

    test('removing a refund restores the original net amount without changing '
        'the original transaction', () async {
      // Given
      final repository = container.read(transactionRepositoryProvider);

      final original = offsetOriginalTransactionFixture(
        id: 'deleted-refund-original',
        amount: Decimal.fromInt(100),
      );

      expect((await repository.create(original)).isSuccess, isTrue);

      final service = container.read(createTransactionOffsetServiceProvider);

      final refundResult = await service(
        transactionOffsetCommandFixture(
          originalTransactionId: original.id,
          amount: Decimal.fromInt(20),
          offsetKind: TransactionOffsetKind.refund,
        ),
      );

      expect(refundResult.isSuccess, isTrue);

      final refund = refundResult.valueOrNull!;

      final beforeDelete = (await container.read(
        getTransactionOffsetSummaryUseCaseProvider,
      )(original.id)).valueOrNull!;

      expect(beforeDelete.netAmount, Decimal.fromInt(80));

      // When
      final deleteResult = await repository.delete(refund.id);

      // Then
      expect(deleteResult.isSuccess, isTrue);

      final afterDelete = (await container.read(
        getTransactionOffsetSummaryUseCaseProvider,
      )(original.id)).valueOrNull!;

      expect(afterDelete.refundAmount, Decimal.zero);
      expect(afterDelete.totalOffsetAmount, Decimal.zero);
      expect(afterDelete.netAmount, Decimal.fromInt(100));
      expect(afterDelete.hasOffsets, isFalse);

      final persistedOriginal = (await repository.getById(
        original.id,
      )).valueOrNull!;

      expect(_primaryAmount(persistedOriginal), Decimal.fromInt(100));
    });
  });
}

Decimal _primaryAmount(Transaction transaction) {
  return transaction.ledgerEntries
      .singleWhere((entry) => entry.role == LedgerEntryRole.primary)
      .transactionAmount
      .amount;
}

String _uniqueRootPath() {
  return p.join(
    Directory.systemTemp.path,
    'transaction-offset-workflow-'
    '${DateTime.now().microsecondsSinceEpoch}',
  );
}
