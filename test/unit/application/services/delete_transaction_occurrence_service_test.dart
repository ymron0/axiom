@Tags(['application'])
library;

import 'package:axiom/src/application/failures/transaction_occurrence_operation_failure.dart';
import 'package:axiom/src/application/services/delete_transaction_occurrence_service.dart';
import 'package:axiom/src/application/services/generate_planned_transactions_service.dart';
import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/core/identity/ids/transaction_id.dart';
import 'package:axiom/src/core/identity/ids/transaction_series_id.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/application/use_cases/create_transaction_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/delete_transaction_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_transaction_by_id_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_transaction_series_by_id_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/restore_transaction_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/update_transaction_series_use_case.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction_series.dart';
import 'package:axiom/src/features/transactions/domain/enums/recurrence_frequency.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_occurrence_deletion_mode.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_state.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_already_exists_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_not_found_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_series_generation_disabled_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_series_not_found_failure.dart';
import 'package:axiom/src/features/transactions/domain/services/resize_planned_transaction_template_service.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/recurrence_exception.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/recurrence_rule.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/transaction_occurrence_origin.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../fixtures/features/transactions/transaction_fixtures.dart';
import '../../../fixtures/features/transactions/transaction_series_failure_fixture.dart';
import '../../../fixtures/features/transactions/transaction_series_fixtures.dart';
import '../../../mocks/transaction_repository_mock.dart';
import '../../../mocks/transaction_series_repository_mock.dart';

void main() {
  group('DeleteTransactionOccurrenceService', () {
    final now = DateTime.utc(2026, 9, 21);
    final clock = FixedClock(now);

    late MockTransactionRepository transactionRepository;
    late MockTransactionSeriesRepository seriesRepository;
    late DeleteTransactionOccurrenceService service;

    setUpAll(() {
      registerFallbackValue(TransactionId.fromString('fallback-tx-id'));
      registerFallbackValue(
        TransactionSeriesId.fromString('fallback-series-id'),
      );
      registerFallbackValue(transactionFixture(id: 'fallback-tx'));
      registerFallbackValue(transactionSeriesFixture(id: 'fallback-series'));
    });

    setUp(() {
      transactionRepository = MockTransactionRepository();
      seriesRepository = MockTransactionSeriesRepository();

      service = DeleteTransactionOccurrenceService(
        getTransactionById: GetTransactionByIdUseCase(transactionRepository),
        getSeriesById: GetTransactionSeriesByIdUseCase(
          repository: seriesRepository,
        ),
        updateSeries: UpdateTransactionSeriesUseCase(
          repository: seriesRepository,
        ),
        deleteTransaction: DeleteTransactionUseCase(transactionRepository),
        restoreTransaction: RestoreTransactionUseCase(transactionRepository),
        createTransaction: CreateTransactionUseCase(
          repository: transactionRepository,
        ),
        generate: GeneratePlannedTransactionsService(
          clock: clock,
          resizeTemplate: const ResizePlannedTransactionTemplateService(),
        ),
        clock: clock,
      );
    });

    Transaction createOccurrenceTransaction({
      String id = 'tx-1',
      String seriesId = 'series-1',
      CalendarDate? scheduledOn,
      bool withRecurrenceOrigin = true,
      DateTime? createdAt,
    }) {
      final date = scheduledOn ?? CalendarDate(2026, 1, 1);
      final created = createdAt ?? DateTime.utc(2026, 1, 1);
      final base = transactionFixture(id: id);
      return Transaction(
        id: base.id,
        kind: base.kind,
        merchantId: base.merchantId,
        effectiveAt: date.toDateTimeUtc(),
        description: base.description,
        note: base.note,
        state: TransactionState.planned,
        offset: null,
        recurrenceOrigin: withRecurrenceOrigin
            ? TransactionOccurrenceOrigin(
                seriesId: TransactionSeriesId.fromString(seriesId),
                scheduledOn: date,
              )
            : null,
        deletedAt: null,
        tagIds: base.tagIds,
        splits: base.splits,
        ledgerEntries: base.ledgerEntries,
        createdAt: created,
        modifiedAt: created,
        entityVersion: base.entityVersion,
      );
    }

    TransactionSeries createSeries({
      String id = 'series-1',
      CalendarDate? startsOn,
      List<RecurrenceException> exceptions = const [],
      DateTime? archivedAt,
      DateTime? deletedAt,
    }) {
      final base = transactionSeriesFixture(
        id: id,
        archivedAt: archivedAt,
        deletedAt: deletedAt,
      );
      return TransactionSeries(
        id: base.id,
        template: base.template,
        recurrenceRule: RecurrenceRule(
          startsOn: startsOn ?? CalendarDate(2026, 1, 1),
          frequency: RecurrenceFrequency.monthly,
        ),
        exceptions: exceptions,
        archivedAt: base.archivedAt,
        deletedAt: base.deletedAt,
        createdAt: base.createdAt,
        modifiedAt: base.modifiedAt,
        entityVersion: base.entityVersion,
      );
    }

    group('validation and precondition checks', () {
      test('propagates transaction lookup failure', () async {
        // Given
        final txId = TransactionId.fromString('tx-1');
        const failure = TransactionAlreadyExistsFailure(
          message: 'Lookup failed.',
        );
        when(
          () => transactionRepository.getById(txId),
        ).thenAnswer((_) async => failure);

        // When
        final result = await service(
          id: txId,
          mode: TransactionOccurrenceDeletionMode.skip,
        );

        // Then
        expect(result.failureOrNull, equals(failure));
        verify(() => transactionRepository.getById(txId)).called(1);
        verifyZeroInteractions(seriesRepository);
      });

      test(
        'returns TransactionNotFoundFailure when transaction does not exist',
        () async {
          // Given
          final txId = TransactionId.fromString('tx-1');
          when(
            () => transactionRepository.getById(txId),
          ).thenAnswer((_) async => const Success(null));

          // When
          final result = await service(
            id: txId,
            mode: TransactionOccurrenceDeletionMode.skip,
          );

          // Then
          expect(result.failureOrNull, isA<TransactionNotFoundFailure>());
          expect(
            result.failureOrNull?.message,
            'Transaction ID was not found: ${txId.value}',
          );
          verify(() => transactionRepository.getById(txId)).called(1);
          verifyZeroInteractions(seriesRepository);
        },
      );

      test(
        'returns TransactionOccurrenceOperationFailure when transaction is not recurring',
        () async {
          // Given
          final transaction = createOccurrenceTransaction(
            withRecurrenceOrigin: false,
          );
          when(
            () => transactionRepository.getById(transaction.id),
          ).thenAnswer((_) async => Success(transaction));

          // When
          final result = await service(
            id: transaction.id,
            mode: TransactionOccurrenceDeletionMode.skip,
          );

          // Then
          expect(
            result.failureOrNull,
            isA<TransactionOccurrenceOperationFailure>(),
          );
          expect(
            result.failureOrNull?.message,
            'Transaction is not a generated recurrence occurrence: ${transaction.id.value}',
          );
          verify(() => transactionRepository.getById(transaction.id)).called(1);
          verifyZeroInteractions(seriesRepository);
        },
      );

      test('propagates series lookup failure', () async {
        // Given
        final transaction = createOccurrenceTransaction();
        const failure = TestTransactionSeriesFailure(
          message: 'Series lookup error.',
        );
        when(
          () => transactionRepository.getById(transaction.id),
        ).thenAnswer((_) async => Success(transaction));
        when(
          () =>
              seriesRepository.getById(transaction.recurrenceOrigin!.seriesId),
        ).thenAnswer((_) async => failure);

        // When
        final result = await service(
          id: transaction.id,
          mode: TransactionOccurrenceDeletionMode.skip,
        );

        // Then
        expect(result.failureOrNull, equals(failure));
        verify(() => transactionRepository.getById(transaction.id)).called(1);
        verify(
          () =>
              seriesRepository.getById(transaction.recurrenceOrigin!.seriesId),
        ).called(1);
      });

      test(
        'returns TransactionSeriesNotFoundFailure when series does not exist',
        () async {
          // Given
          final transaction = createOccurrenceTransaction();
          when(
            () => transactionRepository.getById(transaction.id),
          ).thenAnswer((_) async => Success(transaction));
          when(
            () => seriesRepository.getById(
              transaction.recurrenceOrigin!.seriesId,
            ),
          ).thenAnswer((_) async => const Success(null));

          // When
          final result = await service(
            id: transaction.id,
            mode: TransactionOccurrenceDeletionMode.skip,
          );

          // Then
          expect(result.failureOrNull, isA<TransactionSeriesNotFoundFailure>());
          expect(
            result.failureOrNull?.message,
            'Transaction series ID was not found: ${transaction.recurrenceOrigin!.seriesId.value}',
          );
        },
      );

      test(
        'returns TransactionOccurrenceOperationFailure when occurrence is not defined by series',
        () async {
          // Given
          final transaction = createOccurrenceTransaction(
            scheduledOn: CalendarDate(2026, 1, 15),
          );
          final series = createSeries(
            id: transaction.recurrenceOrigin!.seriesId.value,
            startsOn: CalendarDate(2026, 1, 1),
          );
          when(
            () => transactionRepository.getById(transaction.id),
          ).thenAnswer((_) async => Success(transaction));
          when(
            () => seriesRepository.getById(series.id),
          ).thenAnswer((_) async => Success(series));

          // When
          final result = await service(
            id: transaction.id,
            mode: TransactionOccurrenceDeletionMode.skip,
          );

          // Then
          expect(
            result.failureOrNull,
            isA<TransactionOccurrenceOperationFailure>(),
          );
          expect(
            result.failureOrNull?.message,
            'The transaction recurrence slot is not defined by its series: 2026-01-15.',
          );
        },
      );
    });

    group('skip mode', () {
      test(
        'updates series with non-extending skip exception and deletes transaction',
        () async {
          // Given
          final scheduledOn = CalendarDate(2026, 1, 1);
          final transaction = createOccurrenceTransaction(
            scheduledOn: scheduledOn,
          );
          final series = createSeries(
            id: transaction.recurrenceOrigin!.seriesId.value,
            startsOn: scheduledOn,
          );

          TransactionSeries? updatedSeries;
          when(
            () => transactionRepository.getById(transaction.id),
          ).thenAnswer((_) async => Success(transaction));
          when(
            () => seriesRepository.getById(series.id),
          ).thenAnswer((_) async => Success(series));
          when(() => seriesRepository.update(any())).thenAnswer((
            invocation,
          ) async {
            final arg = invocation.positionalArguments.firstOrNull;
            if (arg case final TransactionSeries s) {
              updatedSeries = s;
            }
            return const Success(null);
          });
          when(
            () => transactionRepository.delete(transaction.id),
          ).thenAnswer((_) async => const Success(null));

          // When
          final result = await service(
            id: transaction.id,
            mode: TransactionOccurrenceDeletionMode.skip,
          );

          // Then
          expect(result.isSuccess, isTrue);
          expect(updatedSeries, isNotNull);
          expect(updatedSeries?.exceptions, hasLength(1));
          final exception = updatedSeries!.exceptions.single;
          expect(exception.scheduledOn, scheduledOn);
          expect(exception.isSkipped, isTrue);
          expect(exception.extendsSeries, isFalse);
          expect(updatedSeries?.modifiedAt, now);

          verify(() => seriesRepository.update(updatedSeries!)).called(1);
          verify(() => transactionRepository.delete(transaction.id)).called(1);
        },
      );

      test(
        'preserves existing exceptions on other dates and replaces matching date exception',
        () async {
          // Given
          final scheduledOn = CalendarDate(2026, 1, 1);
          final otherDate = CalendarDate(2026, 2, 1);
          final transaction = createOccurrenceTransaction(
            scheduledOn: scheduledOn,
          );
          final otherException = RecurrenceException.skip(
            scheduledOn: otherDate,
            extendsSeries: true,
          );
          final oldException = RecurrenceException.skip(
            scheduledOn: scheduledOn,
            extendsSeries: true,
          );
          final series = createSeries(
            id: transaction.recurrenceOrigin!.seriesId.value,
            startsOn: scheduledOn,
            exceptions: [otherException, oldException],
          );

          TransactionSeries? updatedSeries;
          when(
            () => transactionRepository.getById(transaction.id),
          ).thenAnswer((_) async => Success(transaction));
          when(
            () => seriesRepository.getById(series.id),
          ).thenAnswer((_) async => Success(series));
          when(() => seriesRepository.update(any())).thenAnswer((
            invocation,
          ) async {
            final arg = invocation.positionalArguments.firstOrNull;
            if (arg case final TransactionSeries s) {
              updatedSeries = s;
            }
            return const Success(null);
          });
          when(
            () => transactionRepository.delete(transaction.id),
          ).thenAnswer((_) async => const Success(null));

          // When
          final result = await service(
            id: transaction.id,
            mode: TransactionOccurrenceDeletionMode.skip,
          );

          // Then
          expect(result.isSuccess, isTrue);
          expect(updatedSeries?.exceptions, hasLength(2));
          final replacedException = updatedSeries?.exceptionFor(scheduledOn);
          expect(replacedException?.isSkipped, isTrue);
          expect(replacedException?.extendsSeries, isFalse);
          final retainedException = updatedSeries?.exceptionFor(otherDate);
          expect(retainedException, equals(otherException));
        },
      );

      test(
        'returns failure when updating series fails without deleting transaction',
        () async {
          // Given
          final transaction = createOccurrenceTransaction();
          final series = createSeries(
            id: transaction.recurrenceOrigin!.seriesId.value,
          );
          const failure = TestTransactionSeriesFailure(
            message: 'Update series failed.',
          );

          when(
            () => transactionRepository.getById(transaction.id),
          ).thenAnswer((_) async => Success(transaction));
          when(
            () => seriesRepository.getById(series.id),
          ).thenAnswer((_) async => Success(series));
          when(
            () => seriesRepository.update(any()),
          ).thenAnswer((_) async => failure);

          // When
          final result = await service(
            id: transaction.id,
            mode: TransactionOccurrenceDeletionMode.skip,
          );

          // Then
          expect(result.failureOrNull, equals(failure));
          verifyNever(() => transactionRepository.delete(any()));
        },
      );

      test(
        'rolls back series update when deleting transaction fails',
        () async {
          // Given
          final transaction = createOccurrenceTransaction();
          final series = createSeries(
            id: transaction.recurrenceOrigin!.seriesId.value,
          );
          const failure = TransactionAlreadyExistsFailure(
            message: 'Delete failed.',
          );

          when(
            () => transactionRepository.getById(transaction.id),
          ).thenAnswer((_) async => Success(transaction));
          when(
            () => seriesRepository.getById(series.id),
          ).thenAnswer((_) async => Success(series));
          when(
            () => seriesRepository.update(any()),
          ).thenAnswer((_) async => const Success(null));
          when(
            () => transactionRepository.delete(transaction.id),
          ).thenAnswer((_) async => failure);

          // When
          final result = await service(
            id: transaction.id,
            mode: TransactionOccurrenceDeletionMode.skip,
          );

          // Then
          expect(result.failureOrNull, equals(failure));
          verify(() => seriesRepository.update(series)).called(1);
        },
      );
    });

    group('skipAndAppend mode', () {
      test(
        'updates series with extending skip exception and deletes transaction',
        () async {
          // Given
          final scheduledOn = CalendarDate(2026, 1, 1);
          final transaction = createOccurrenceTransaction(
            scheduledOn: scheduledOn,
          );
          final series = createSeries(
            id: transaction.recurrenceOrigin!.seriesId.value,
            startsOn: scheduledOn,
          );

          TransactionSeries? updatedSeries;
          when(
            () => transactionRepository.getById(transaction.id),
          ).thenAnswer((_) async => Success(transaction));
          when(
            () => seriesRepository.getById(series.id),
          ).thenAnswer((_) async => Success(series));
          when(() => seriesRepository.update(any())).thenAnswer((
            invocation,
          ) async {
            final arg = invocation.positionalArguments.firstOrNull;
            if (arg case final TransactionSeries s) {
              updatedSeries = s;
            }
            return const Success(null);
          });
          when(
            () => transactionRepository.delete(transaction.id),
          ).thenAnswer((_) async => const Success(null));

          // When
          final result = await service(
            id: transaction.id,
            mode: TransactionOccurrenceDeletionMode.skipAndAppend,
          );

          // Then
          expect(result.isSuccess, isTrue);
          expect(updatedSeries, isNotNull);
          expect(updatedSeries?.exceptions, hasLength(1));
          final exception = updatedSeries!.exceptions.single;
          expect(exception.scheduledOn, scheduledOn);
          expect(exception.isSkipped, isTrue);
          expect(exception.extendsSeries, isTrue);
        },
      );
    });

    group('regenerate mode', () {
      test(
        'successfully generates replacement, deletes original, and creates replacement',
        () async {
          // Given
          final scheduledOn = CalendarDate(2026, 1, 1);
          final transaction = createOccurrenceTransaction(
            scheduledOn: scheduledOn,
          );
          final series = createSeries(
            id: transaction.recurrenceOrigin!.seriesId.value,
            startsOn: scheduledOn,
          );

          Transaction? createdReplacement;
          when(
            () => transactionRepository.getById(transaction.id),
          ).thenAnswer((_) async => Success(transaction));
          when(
            () => seriesRepository.getById(series.id),
          ).thenAnswer((_) async => Success(series));
          when(
            () => transactionRepository.delete(transaction.id),
          ).thenAnswer((_) async => const Success(null));
          when(() => transactionRepository.create(any())).thenAnswer((
            invocation,
          ) async {
            final arg = invocation.positionalArguments.firstOrNull;
            if (arg case final Transaction t) {
              createdReplacement = t;
            }
            return const Success(null);
          });

          // When
          final result = await service(
            id: transaction.id,
            mode: TransactionOccurrenceDeletionMode.regenerate,
          );

          // Then
          expect(result.isSuccess, isTrue);
          expect(createdReplacement, isNotNull);
          expect(
            createdReplacement?.recurrenceOrigin?.seriesId,
            transaction.recurrenceOrigin?.seriesId,
          );
          expect(
            createdReplacement?.recurrenceOrigin?.scheduledOn,
            scheduledOn,
          );
          verify(() => transactionRepository.delete(transaction.id)).called(1);
          verify(
            () => transactionRepository.create(createdReplacement!),
          ).called(1);
        },
      );

      test('returns failure when series generation is disabled', () async {
        // Given
        final scheduledOn = CalendarDate(2026, 1, 1);
        final transaction = createOccurrenceTransaction(
          scheduledOn: scheduledOn,
        );
        final archivedSeries = createSeries(
          id: transaction.recurrenceOrigin!.seriesId.value,
          startsOn: scheduledOn,
          archivedAt: DateTime.utc(2026, 1, 1),
        );

        when(
          () => transactionRepository.getById(transaction.id),
        ).thenAnswer((_) async => Success(transaction));
        when(
          () => seriesRepository.getById(archivedSeries.id),
        ).thenAnswer((_) async => Success(archivedSeries));

        // When
        final result = await service(
          id: transaction.id,
          mode: TransactionOccurrenceDeletionMode.regenerate,
        );

        // Then
        expect(
          result.failureOrNull,
          isA<TransactionSeriesGenerationDisabledFailure>(),
        );
        verifyNever(() => transactionRepository.delete(any()));
        verifyNever(() => transactionRepository.create(any()));
      });

      test(
        'returns TransactionOccurrenceOperationFailure when generation produces no transactions',
        () async {
          // Given
          final scheduledOn = CalendarDate(2026, 1, 1);
          final transaction = createOccurrenceTransaction(
            scheduledOn: scheduledOn,
          );
          final seriesWithSkip = createSeries(
            id: transaction.recurrenceOrigin!.seriesId.value,
            startsOn: scheduledOn,
            exceptions: [RecurrenceException.skip(scheduledOn: scheduledOn)],
          );

          when(
            () => transactionRepository.getById(transaction.id),
          ).thenAnswer((_) async => Success(transaction));
          when(
            () => seriesRepository.getById(seriesWithSkip.id),
          ).thenAnswer((_) async => Success(seriesWithSkip));

          // When
          final result = await service(
            id: transaction.id,
            mode: TransactionOccurrenceDeletionMode.regenerate,
          );

          // Then
          expect(
            result.failureOrNull,
            isA<TransactionOccurrenceOperationFailure>(),
          );
          expect(
            result.failureOrNull?.message,
            'The recurrence slot could not produce exactly one replacement transaction.',
          );
          verifyNever(() => transactionRepository.delete(any()));
          verifyNever(() => transactionRepository.create(any()));
        },
      );

      test(
        'returns failure when deleting transaction fails without creating replacement',
        () async {
          // Given
          final scheduledOn = CalendarDate(2026, 1, 1);
          final transaction = createOccurrenceTransaction(
            scheduledOn: scheduledOn,
          );
          final series = createSeries(
            id: transaction.recurrenceOrigin!.seriesId.value,
            startsOn: scheduledOn,
          );
          const failure = TransactionAlreadyExistsFailure(
            message: 'Delete error.',
          );

          when(
            () => transactionRepository.getById(transaction.id),
          ).thenAnswer((_) async => Success(transaction));
          when(
            () => seriesRepository.getById(series.id),
          ).thenAnswer((_) async => Success(series));
          when(
            () => transactionRepository.delete(transaction.id),
          ).thenAnswer((_) async => failure);

          // When
          final result = await service(
            id: transaction.id,
            mode: TransactionOccurrenceDeletionMode.regenerate,
          );

          // Then
          expect(result.failureOrNull, equals(failure));
          verifyNever(() => transactionRepository.create(any()));
        },
      );

      test(
        'rolls back and restores transaction when creating replacement fails',
        () async {
          // Given
          final scheduledOn = CalendarDate(2026, 1, 1);
          final transaction = createOccurrenceTransaction(
            scheduledOn: scheduledOn,
          );
          final series = createSeries(
            id: transaction.recurrenceOrigin!.seriesId.value,
            startsOn: scheduledOn,
          );
          const failure = TransactionAlreadyExistsFailure(
            message: 'Creation failed.',
          );

          Transaction? restoredTransaction;
          when(
            () => transactionRepository.getById(transaction.id),
          ).thenAnswer((_) async => Success(transaction));
          when(
            () => seriesRepository.getById(series.id),
          ).thenAnswer((_) async => Success(series));
          when(
            () => transactionRepository.delete(transaction.id),
          ).thenAnswer((_) async => const Success(null));
          when(
            () => transactionRepository.create(any()),
          ).thenAnswer((_) async => failure);
          when(() => transactionRepository.restore(any())).thenAnswer((
            invocation,
          ) async {
            final arg = invocation.positionalArguments.firstOrNull;
            if (arg case final Transaction t) {
              restoredTransaction = t;
            }
            return const Success(null);
          });

          // When
          final result = await service(
            id: transaction.id,
            mode: TransactionOccurrenceDeletionMode.regenerate,
          );

          // Then
          expect(result.failureOrNull, equals(failure));
          expect(restoredTransaction, isNotNull);
          expect(restoredTransaction?.id, transaction.id);
          expect(restoredTransaction?.deletedAt, now);
          verify(
            () => transactionRepository.restore(restoredTransaction!),
          ).called(1);
        },
      );
    });
  });
}
