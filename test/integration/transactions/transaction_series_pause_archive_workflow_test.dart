@Tags(['integration'])
library;

import 'package:axiom/src/application/services/generate_planned_transactions_service.dart';
import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/transactions/application/use_cases/archive_transaction_series_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/pause_transaction_series_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/resume_transaction_series_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/unarchive_transaction_series_use_case.dart';
import 'package:axiom/src/features/transactions/data/repositories/sembast_transaction_repository_impl.dart';
import 'package:axiom/src/features/transactions/data/repositories/sembast_transaction_series_repository_impl.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction_series.dart';
import 'package:axiom/src/features/transactions/domain/enums/ledger_entry_role.dart';
import 'package:axiom/src/features/transactions/domain/enums/recurrence_frequency.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_kind.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_series_generation_disabled_failure.dart';
import 'package:axiom/src/features/transactions/domain/services/resize_planned_transaction_template_service.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/ledger_entry.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/recurrence_end.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/recurrence_rule.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/transaction_template.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

import '../../fixtures/core/persistence/persistence_test_environment.dart';

void main() {
  group('Transaction series pause and archive workflow', () {
    test(
      'archive pauses, unarchive stays paused, and generated transactions survive',
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
          clock: FixedClock(DateTime.utc(2026, 9, 21)),
          resizeTemplate: const ResizePlannedTransactionTemplateService(),
        );

        final series = TransactionSeries.create(
          template: _template(),
          recurrenceRule: RecurrenceRule(
            startsOn: CalendarDate(2026, 9, 21),
            frequency: RecurrenceFrequency.monthly,
            end: RecurrenceEnd(count: 2),
          ),
          clock: FixedClock(DateTime.utc(2026, 9, 21)),
        );

        expect((await seriesRepository.create(series)).isSuccess, isTrue);

        final generated = generator(
          series: series,
          scheduledFrom: CalendarDate(2026, 9, 21),
          scheduledUntil: CalendarDate(2026, 12, 1),
        ).valueOrNull!;

        expect(generated, hasLength(2));

        expect(
          generated.map(
            (transaction) => transaction.recurrenceOrigin?.seriesId,
          ),
          everyElement(series.id),
        );

        expect(
          (await transactionRepository.createAll(generated)).isSuccess,
          isTrue,
        );

        final transactionIdsBeforeLifecycleChanges =
            (await transactionRepository.getAll()).valueOrNull!
                .map((transaction) => transaction.id)
                .toList(growable: false);

        // Pause.
        final pauseUseCase = PauseTransactionSeriesUseCase(
          repository: seriesRepository,
          clock: FixedClock(DateTime.utc(2026, 9, 22)),
        );

        final pauseResult = await pauseUseCase(series.id);
        final paused = pauseResult.valueOrNull!;

        expect(paused.isPaused, isTrue);
        expect(paused.isArchived, isFalse);
        expect(paused.isGenerationEnabled, isFalse);

        expect(
          generator(
            series: paused,
            scheduledFrom: CalendarDate(2026, 9, 21),
            scheduledUntil: CalendarDate(2026, 12, 1),
          ).failureOrNull,
          isA<TransactionSeriesGenerationDisabledFailure>(),
        );

        // Explicitly resume before testing archival.
        final firstResumeUseCase = ResumeTransactionSeriesUseCase(
          repository: seriesRepository,
          clock: FixedClock(DateTime.utc(2026, 9, 23)),
        );

        final firstResumeResult = await firstResumeUseCase(series.id);
        final resumed = firstResumeResult.valueOrNull!;

        expect(resumed.isPaused, isFalse);
        expect(resumed.isArchived, isFalse);
        expect(resumed.isGenerationEnabled, isTrue);

        // Archive. This must automatically pause.
        final archiveUseCase = ArchiveTransactionSeriesUseCase(
          repository: seriesRepository,
          clock: FixedClock(DateTime.utc(2026, 9, 24)),
        );

        final archiveResult = await archiveUseCase(series.id);
        final archived = archiveResult.valueOrNull!;

        expect(archived.isArchived, isTrue);
        expect(archived.isPaused, isTrue);
        expect(archived.isGenerationEnabled, isFalse);

        // Already-generated transactions remain untouched.
        final transactionsAfterArchive =
            (await transactionRepository.getAll()).valueOrNull!;

        expect(
          transactionsAfterArchive.map((transaction) => transaction.id),
          transactionIdsBeforeLifecycleChanges,
        );

        expect(transactionsAfterArchive, hasLength(2));

        // Unarchive. It must remain paused.
        final unarchiveUseCase = UnarchiveTransactionSeriesUseCase(
          repository: seriesRepository,
          clock: FixedClock(DateTime.utc(2026, 9, 25)),
        );

        final unarchiveResult = await unarchiveUseCase(series.id);
        final unarchived = unarchiveResult.valueOrNull!;

        expect(unarchived.isArchived, isFalse);
        expect(unarchived.isPaused, isTrue);
        expect(unarchived.isGenerationEnabled, isFalse);

        expect(
          generator(
            series: unarchived,
            scheduledFrom: CalendarDate(2026, 9, 21),
            scheduledUntil: CalendarDate(2026, 12, 1),
          ).failureOrNull,
          isA<TransactionSeriesGenerationDisabledFailure>(),
        );

        // Only an explicit resume enables generation again.
        final secondResumeUseCase = ResumeTransactionSeriesUseCase(
          repository: seriesRepository,
          clock: FixedClock(DateTime.utc(2026, 9, 26)),
        );

        final secondResumeResult = await secondResumeUseCase(series.id);
        final resumedAfterUnarchive = secondResumeResult.valueOrNull!;

        expect(resumedAfterUnarchive.isArchived, isFalse);
        expect(resumedAfterUnarchive.isPaused, isFalse);
        expect(resumedAfterUnarchive.isGenerationEnabled, isTrue);

        // Transactions still remain untouched after the complete lifecycle.
        final transactionsAtEnd =
            (await transactionRepository.getAll()).valueOrNull!;

        expect(
          transactionsAtEnd.map((transaction) => transaction.id),
          transactionIdsBeforeLifecycleChanges,
        );
      },
    );
  });
}

TransactionTemplate _template() {
  final amount = AssetAmount.outgoing(
    assetId: AssetId.fromString('asset-chf'),
    amount: Decimal.parse('100'),
  );

  return TransactionTemplate(
    kind: TransactionKind.expense,
    merchantId: MerchantId.self,
    description: 'Recurring expense',
    splits: const [],
    ledgerEntries: [
      LedgerEntry(
        accountId: AccountId.fromString('account-chf'),
        transactionAmount: amount,
        accountAmount: amount,
        valuationAmount: amount,
        role: LedgerEntryRole.primary,
      ),
    ],
  );
}
