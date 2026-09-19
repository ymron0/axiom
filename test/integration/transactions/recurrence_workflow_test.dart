@Tags(['integration'])
library;

import 'package:axiom/src/application/services/generate_planned_transactions_service.dart';
import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/identity/ids/transaction_series_id.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/transactions/data/repositories/sembast_transaction_repository_impl.dart';
import 'package:axiom/src/features/transactions/data/repositories/sembast_transaction_series_repository_impl.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction_series.dart';
import 'package:axiom/src/features/transactions/domain/enums/ledger_entry_role.dart';
import 'package:axiom/src/features/transactions/domain/enums/recurrence_amount_completion.dart';
import 'package:axiom/src/features/transactions/domain/enums/recurrence_frequency.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_kind.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_state.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_series_generation_disabled_failure.dart';
import 'package:axiom/src/features/transactions/domain/services/resize_planned_transaction_template_service.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/ledger_entry.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/recurrence_amount_end.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/recurrence_end.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/recurrence_exception.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/recurrence_rule.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/transaction_template.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

import '../../fixtures/core/persistence/persistence_test_environment.dart';

void main() {
  group('Recurrence workflow', () {
    test(
      'persists, reloads, generates, and stores planned occurrences',
      () async {
        // Given
        final sembastDatabase = await createTestSembastDatabase();
        final database = await sembastDatabase.open();
        addTearDown(database.close);

        final seriesRepository = SembastTransactionSeriesRepositoryImpl(
          database: database,
        );

        final transactionRepository = SembastTransactionRepositoryImpl(
          database: database,
        );

        final generator = GeneratePlannedTransactionsService(
          clock: FixedClock(DateTime.utc(2026, 9, 19)),
          resizeTemplate: const ResizePlannedTransactionTemplateService(),
        );

        final replacementTemplate = _template(
          amount: '60',
          description: 'Reduced February installment',
        );

        final series = _series(
          recurrenceRule: RecurrenceRule(
            startsOn: CalendarDate(2026, 1, 1),
            frequency: RecurrenceFrequency.monthly,
            end: RecurrenceEnd(
              amount: RecurrenceAmountEnd(
                targetAmount: AssetAmount.outgoing(
                  assetId: AssetId.fromString('asset-chf'),
                  amount: Decimal.parse('300'),
                ),
                completion: RecurrenceAmountCompletion.exactTarget,
              ),
            ),
          ),
          exceptions: [
            RecurrenceException.replace(
              scheduledOn: CalendarDate(2026, 2, 1),
              replacementOn: CalendarDate(2026, 2, 5),
              replacementTemplate: replacementTemplate,
            ),
          ],
        );

        final expectedGeneration = generator(
          series: series,
          scheduledFrom: CalendarDate(2026, 1, 1),
          scheduledUntil: CalendarDate(2026, 6, 1),
        ).valueOrNull!;

        // When
        final createSeriesResult = await seriesRepository.create(series);

        expect(createSeriesResult.isSuccess, isTrue);

        final reloadedSeriesResult = await seriesRepository.getById(series.id);
        final reloadedSeries = reloadedSeriesResult.valueOrNull!;

        final generationResult = generator(
          series: reloadedSeries,
          scheduledFrom: CalendarDate(2026, 1, 1),
          scheduledUntil: CalendarDate(2026, 6, 1),
        );

        final generated = generationResult.valueOrNull!;

        final createTransactionsResult = await transactionRepository.createAll(
          generated,
        );

        // Then
        expect(reloadedSeries.id, series.id);
        expect(reloadedSeries.amountEnd, isNotNull);
        expect(reloadedSeries.exceptions, hasLength(1));

        expect(generated, hasLength(3));

        expect(generated.map((transaction) => transaction.effectiveAt), [
          DateTime.utc(2026, 1, 1),
          DateTime.utc(2026, 2, 5),
          DateTime.utc(2026, 3, 1),
        ]);

        expect(generated.map(_primaryAmount), [
          Decimal.parse('120'),
          Decimal.parse('60'),
          Decimal.parse('120'),
        ]);

        expect(
          generated.map((transaction) => transaction.state),
          everyElement(TransactionState.planned),
        );

        expect(
          generated.map((transaction) => transaction.effectiveAt),
          expectedGeneration.map((transaction) => transaction.effectiveAt),
        );

        expect(
          generated.map(_primaryAmount),
          expectedGeneration.map(_primaryAmount),
        );

        expect(createTransactionsResult.isSuccess, isTrue);

        final storedResult = await transactionRepository.getAll();
        final stored = storedResult.valueOrNull!;

        expect(stored, hasLength(3));

        expect(
          stored.map((transaction) => transaction.id),
          generated.map((transaction) => transaction.id),
        );

        expect(stored.map((transaction) => transaction.effectiveAt), [
          DateTime.utc(2026, 1, 1),
          DateTime.utc(2026, 2, 5),
          DateTime.utc(2026, 3, 1),
        ]);

        expect(stored.map(_primaryAmount), [
          Decimal.parse('120'),
          Decimal.parse('60'),
          Decimal.parse('120'),
        ]);
      },
    );

    test('archiving a series disables future generation without changing '
        'persisted transactions', () async {
      // Given
      final sembastDatabase = await createTestSembastDatabase();
      final database = await sembastDatabase.open();
      addTearDown(database.close);

      final seriesRepository = SembastTransactionSeriesRepositoryImpl(
        database: database,
      );

      final transactionRepository = SembastTransactionRepositoryImpl(
        database: database,
      );

      final generator = GeneratePlannedTransactionsService(
        clock: FixedClock(DateTime.utc(2026, 9, 19)),
        resizeTemplate: const ResizePlannedTransactionTemplateService(),
      );

      final series = _series(
        recurrenceRule: RecurrenceRule(
          startsOn: CalendarDate(2026, 1, 1),
          frequency: RecurrenceFrequency.monthly,
          end: RecurrenceEnd(count: 2),
        ),
      );

      expect((await seriesRepository.create(series)).isSuccess, isTrue);

      final generated = generator(
        series: series,
        scheduledFrom: CalendarDate(2026, 1, 1),
        scheduledUntil: CalendarDate(2026, 3, 1),
      ).valueOrNull!;

      expect(
        (await transactionRepository.createAll(generated)).isSuccess,
        isTrue,
      );

      final idsBeforeArchive = (await transactionRepository.getAll())
          .valueOrNull!
          .map((transaction) => transaction.id)
          .toList(growable: false);

      // When
      final archiveResult = await seriesRepository.archive(
        series.id,
        DateTime.utc(2026, 9, 20),
      );

      final archivedSeries = archiveResult.valueOrNull!;

      final generationAfterArchive = generator(
        series: archivedSeries,
        scheduledFrom: CalendarDate(2026, 3, 1),
        scheduledUntil: CalendarDate(2026, 4, 1),
      );

      final transactionsAfterArchive =
          (await transactionRepository.getAll()).valueOrNull!;

      // Then
      expect(archivedSeries.isArchived, isTrue);
      expect(archivedSeries.isGenerationEnabled, isFalse);

      expect(
        generationAfterArchive.failureOrNull,
        isA<TransactionSeriesGenerationDisabledFailure>(),
      );

      expect(
        transactionsAfterArchive.map((transaction) => transaction.id),
        idsBeforeArchive,
      );

      expect(transactionsAfterArchive, hasLength(2));
    });

    test('deleting a series does not delete transactions previously generated '
        'from it', () async {
      // Given
      final sembastDatabase = await createTestSembastDatabase();
      final database = await sembastDatabase.open();
      addTearDown(database.close);

      final seriesRepository = SembastTransactionSeriesRepositoryImpl(
        database: database,
      );

      final transactionRepository = SembastTransactionRepositoryImpl(
        database: database,
      );

      final generator = GeneratePlannedTransactionsService(
        clock: FixedClock(DateTime.utc(2026, 9, 19)),
        resizeTemplate: const ResizePlannedTransactionTemplateService(),
      );

      final series = _series(
        recurrenceRule: RecurrenceRule(
          startsOn: CalendarDate(2026, 1, 1),
          frequency: RecurrenceFrequency.monthly,
          end: RecurrenceEnd(count: 2),
        ),
      );

      expect((await seriesRepository.create(series)).isSuccess, isTrue);

      final generated = generator(
        series: series,
        scheduledFrom: CalendarDate(2026, 1, 1),
        scheduledUntil: CalendarDate(2026, 3, 1),
      ).valueOrNull!;

      expect(generated, hasLength(2));

      expect(
        (await transactionRepository.createAll(generated)).isSuccess,
        isTrue,
      );

      final generatedIds = generated
          .map((transaction) => transaction.id)
          .toList(growable: false);

      // When
      final deleteResult = await seriesRepository.delete(series.id);

      final persistedSeries = await seriesRepository.getById(series.id);
      final persistedTransactions = await transactionRepository.getAll();

      // Then
      expect(deleteResult.isSuccess, isTrue);
      expect(deleteResult.valueOrNull!.isDeleted, isTrue);

      expect(persistedSeries.valueOrNull, isNull);

      final remainingTransactions = persistedTransactions.valueOrNull!;

      expect(remainingTransactions, hasLength(2));

      expect(
        remainingTransactions.map((transaction) => transaction.id),
        generatedIds,
      );

      expect(
        remainingTransactions.map((transaction) => transaction.state),
        everyElement(TransactionState.planned),
      );
    });
  });
}

TransactionSeries _series({
  required RecurrenceRule recurrenceRule,
  List<RecurrenceException> exceptions = const [],
}) {
  final createdAt = DateTime.utc(2026, 1, 1);

  return TransactionSeries(
    id: TransactionSeriesId.fromString('recurrence-integration-series'),
    template: _template(),
    recurrenceRule: recurrenceRule,
    exceptions: exceptions,
    createdAt: createdAt,
    modifiedAt: createdAt,
    entityVersion: 1,
  );
}

TransactionTemplate _template({
  String amount = '120',
  String description = 'Recurring expense',
}) {
  final primaryAmount = AssetAmount.outgoing(
    assetId: AssetId.fromString('asset-chf'),
    amount: Decimal.parse(amount),
  );

  return TransactionTemplate(
    kind: TransactionKind.expense,
    merchantId: MerchantId.self,
    description: description,
    splits: const [],
    ledgerEntries: [
      LedgerEntry(
        accountId: AccountId.fromString('account-chf'),
        transactionAmount: primaryAmount,
        accountAmount: primaryAmount,
        valuationAmount: primaryAmount,
        role: LedgerEntryRole.primary,
      ),
    ],
  );
}

Decimal _primaryAmount(Transaction transaction) {
  return transaction.ledgerEntries
      .singleWhere((entry) => entry.role == LedgerEntryRole.primary)
      .transactionAmount
      .amount;
}
