@Tags(['application'])
library;

import 'package:axiom/src/application/services/generate_planned_transactions_service.dart';
import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/identity/ids/transaction_series_id.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/features/assets/domain/enums/asset_amount_direction.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/settings/domain/enums/planned_transaction_generation_horizon.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction_series.dart';
import 'package:axiom/src/features/transactions/domain/enums/ledger_entry_role.dart';
import 'package:axiom/src/features/transactions/domain/enums/recurrence_amount_completion.dart';
import 'package:axiom/src/features/transactions/domain/enums/recurrence_frequency.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_kind.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_state.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_series_generation_disabled_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_template_instantiation_failure.dart';
import 'package:axiom/src/features/transactions/domain/services/resize_planned_transaction_template_service.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/ledger_entry.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/recurrence_amount_end.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/recurrence_end.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/recurrence_exception.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/recurrence_rule.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/transaction_template.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

void main() {
  group('GeneratePlannedTransactionsService', () {
    final generatedAt = DateTime.utc(2026, 9, 19);

    late GeneratePlannedTransactionsService service;

    setUp(() {
      service = GeneratePlannedTransactionsService(
        clock: FixedClock(generatedAt),
        resizeTemplate: const ResizePlannedTransactionTemplateService(),
      );
    });

    test('generates ordinary planned transactions inside the range', () {
      // Given
      final series = _series(
        recurrenceRule: RecurrenceRule(
          startsOn: CalendarDate(2026, 1, 1),
          frequency: RecurrenceFrequency.monthly,
          end: RecurrenceEnd(count: 3),
        ),
      );

      // When
      final result = service(
        series: series,
        scheduledFrom: CalendarDate(2026, 1, 1),
        scheduledUntil: CalendarDate(2026, 4, 1),
      );

      // Then
      final transactions = result.valueOrNull!;

      expect(transactions, hasLength(3));

      expect(
        transactions.map((transaction) => transaction.state),
        everyElement(TransactionState.planned),
      );

      expect(transactions.map((transaction) => transaction.effectiveAt), [
        DateTime.utc(2026, 1, 1),
        DateTime.utc(2026, 2, 1),
        DateTime.utc(2026, 3, 1),
      ]);

      expect(
        transactions.map((transaction) => transaction.createdAt),
        everyElement(generatedAt),
      );

      expect(
        transactions.map((transaction) => transaction.id).toSet(),
        hasLength(3),
      );

      expect(() => transactions.clear(), throwsUnsupportedError);
    });

    test('applies skip and replacement exceptions', () {
      // Given
      final replacement = _template(amount: '75');

      final series = _series(
        recurrenceRule: RecurrenceRule(
          startsOn: CalendarDate(2026, 1, 1),
          frequency: RecurrenceFrequency.monthly,
          end: RecurrenceEnd(count: 3),
        ),
        exceptions: [
          RecurrenceException.skip(scheduledOn: CalendarDate(2026, 2, 1)),
          RecurrenceException.replace(
            scheduledOn: CalendarDate(2026, 3, 1),
            replacementOn: CalendarDate(2026, 3, 5),
            replacementTemplate: replacement,
          ),
        ],
      );

      // When
      final result = service(
        series: series,
        scheduledFrom: CalendarDate(2026, 1, 1),
        scheduledUntil: CalendarDate(2026, 4, 1),
      );

      // Then
      final transactions = result.valueOrNull!;

      expect(transactions, hasLength(2));

      expect(transactions[0].effectiveAt, DateTime.utc(2026, 1, 1));

      expect(transactions[1].effectiveAt, DateTime.utc(2026, 3, 5));

      expect(_primaryAmount(transactions[1]), Decimal.parse('75'));
    });

    test('generates an exact final amount occurrence', () {
      // Given
      final series = _series(
        recurrenceRule: _amountRule(
          target: '1000',
          completion: RecurrenceAmountCompletion.exactTarget,
        ),
      );

      // When
      final result = service(
        series: series,
        scheduledFrom: CalendarDate(2026, 1, 1),
        scheduledUntil: CalendarDate(2026, 12, 1),
      );

      // Then
      final transactions = result.valueOrNull!;

      expect(transactions, hasLength(9));

      expect(
        transactions.take(8).map(_primaryAmount),
        everyElement(Decimal.parse('120')),
      );

      expect(_primaryAmount(transactions.last), Decimal.parse('40'));

      expect(_totalPrimaryAmount(transactions), Decimal.parse('1000'));
    });

    test(
      'keeps the full final occurrence when completion allows overshoot',
      () {
        // Given
        final series = _series(
          recurrenceRule: _amountRule(
            target: '1000',
            completion: RecurrenceAmountCompletion.fullOccurrence,
          ),
        );

        // When
        final result = service(
          series: series,
          scheduledFrom: CalendarDate(2026, 1, 1),
          scheduledUntil: CalendarDate(2026, 12, 1),
        );

        // Then
        final transactions = result.valueOrNull!;

        expect(transactions, hasLength(9));

        expect(
          transactions.map(_primaryAmount),
          everyElement(Decimal.parse('120')),
        );

        expect(_totalPrimaryAmount(transactions), Decimal.parse('1080'));
      },
    );

    test('a skipped occurrence contributes no amount progress', () {
      // Given
      final series = _series(
        recurrenceRule: _amountRule(
          target: '300',
          completion: RecurrenceAmountCompletion.exactTarget,
        ),
        exceptions: [
          RecurrenceException.skip(scheduledOn: CalendarDate(2026, 2, 1)),
        ],
      );

      // When
      final result = service(
        series: series,
        scheduledFrom: CalendarDate(2026, 1, 1),
        scheduledUntil: CalendarDate(2026, 6, 1),
      );

      // Then
      final transactions = result.valueOrNull!;

      expect(transactions, hasLength(3));

      expect(transactions.map((transaction) => transaction.effectiveAt), [
        DateTime.utc(2026, 1, 1),
        DateTime.utc(2026, 3, 1),
        DateTime.utc(2026, 4, 1),
      ]);

      expect(transactions.map(_primaryAmount), [
        Decimal.parse('120'),
        Decimal.parse('120'),
        Decimal.parse('60'),
      ]);

      expect(_totalPrimaryAmount(transactions), Decimal.parse('300'));
    });

    test('a replacement occurrence contributes its replacement amount', () {
      // Given
      final replacementTemplate = _template(amount: '60');

      final series = _series(
        recurrenceRule: _amountRule(
          target: '300',
          completion: RecurrenceAmountCompletion.exactTarget,
        ),
        exceptions: [
          RecurrenceException.replace(
            scheduledOn: CalendarDate(2026, 2, 1),
            replacementTemplate: replacementTemplate,
          ),
        ],
      );

      // When
      final result = service(
        series: series,
        scheduledFrom: CalendarDate(2026, 1, 1),
        scheduledUntil: CalendarDate(2026, 6, 1),
      );

      // Then
      final transactions = result.valueOrNull!;

      expect(transactions, hasLength(3));

      expect(transactions.map(_primaryAmount), [
        Decimal.parse('120'),
        Decimal.parse('60'),
        Decimal.parse('120'),
      ]);

      expect(_totalPrimaryAmount(transactions), Decimal.parse('300'));
    });

    test('evaluates amount progress before scheduledFrom', () {
      // Given
      final series = _series(
        recurrenceRule: _amountRule(
          target: '300',
          completion: RecurrenceAmountCompletion.exactTarget,
        ),
      );

      // January and February contribute CHF 240 before the requested range.

      // When
      final result = service(
        series: series,
        scheduledFrom: CalendarDate(2026, 3, 1),
        scheduledUntil: CalendarDate(2026, 6, 1),
      );

      // Then
      final transactions = result.valueOrNull!;

      expect(transactions, hasLength(1));

      expect(transactions.single.effectiveAt, DateTime.utc(2026, 3, 1));

      expect(_primaryAmount(transactions.single), Decimal.parse('60'));
    });

    test('count termination stops generation before a later amount target', () {
      // Given
      final series = _series(
        recurrenceRule: RecurrenceRule(
          startsOn: CalendarDate(2026, 1, 1),
          frequency: RecurrenceFrequency.monthly,
          end: RecurrenceEnd(
            count: 2,
            amount: RecurrenceAmountEnd(
              targetAmount: AssetAmount.outgoing(
                assetId: AssetId.fromString('asset-chf'),
                amount: Decimal.parse('1000'),
              ),
              completion: RecurrenceAmountCompletion.exactTarget,
            ),
          ),
        ),
      );

      // When
      final result = service(
        series: series,
        scheduledFrom: CalendarDate(2026, 1, 1),
        scheduledUntil: CalendarDate(2027, 1, 1),
      );

      // Then
      final transactions = result.valueOrNull!;

      expect(transactions, hasLength(2));

      expect(_totalPrimaryAmount(transactions), Decimal.parse('240'));
    });

    test('date termination stops generation before a later amount target', () {
      // Given
      final series = _series(
        recurrenceRule: RecurrenceRule(
          startsOn: CalendarDate(2026, 1, 1),
          frequency: RecurrenceFrequency.monthly,
          end: RecurrenceEnd(
            until: CalendarDate(2026, 2, 1),
            amount: RecurrenceAmountEnd(
              targetAmount: AssetAmount.outgoing(
                assetId: AssetId.fromString('asset-chf'),
                amount: Decimal.parse('1000'),
              ),
              completion: RecurrenceAmountCompletion.exactTarget,
            ),
          ),
        ),
      );

      // When
      final result = service(
        series: series,
        scheduledFrom: CalendarDate(2026, 1, 1),
        scheduledUntil: CalendarDate(2027, 1, 1),
      );

      // Then
      final transactions = result.valueOrNull!;

      expect(transactions, hasLength(2));

      expect(transactions.map((transaction) => transaction.effectiveAt), [
        DateTime.utc(2026, 1, 1),
        DateTime.utc(2026, 2, 1),
      ]);
    });

    test(
      'range membership uses the original scheduled slot after replacement',
      () {
        // Given
        final series = _series(
          recurrenceRule: RecurrenceRule(
            startsOn: CalendarDate(2026, 1, 1),
            frequency: RecurrenceFrequency.monthly,
            end: RecurrenceEnd(count: 2),
          ),
          exceptions: [
            RecurrenceException.replace(
              scheduledOn: CalendarDate(2026, 2, 1),
              replacementOn: CalendarDate(2026, 3, 15),
            ),
          ],
        );

        // The February slot is inside [January 1, March 1), even though the
        // replacement transaction itself becomes effective on March 15.

        // When
        final result = service(
          series: series,
          scheduledFrom: CalendarDate(2026, 1, 1),
          scheduledUntil: CalendarDate(2026, 3, 1),
        );

        // Then
        final transactions = result.valueOrNull!;

        expect(transactions, hasLength(2));

        expect(transactions[0].effectiveAt, DateTime.utc(2026, 1, 1));

        expect(transactions[1].effectiveAt, DateTime.utc(2026, 3, 15));
      },
    );

    test('treats scheduledUntil as exclusive', () {
      // Given
      final series = _series(
        recurrenceRule: RecurrenceRule(
          startsOn: CalendarDate(2026, 1, 1),
          frequency: RecurrenceFrequency.monthly,
        ),
      );

      // When
      final result = service(
        series: series,
        scheduledFrom: CalendarDate(2026, 2, 1),
        scheduledUntil: CalendarDate(2026, 3, 1),
      );

      // Then
      final transactions = result.valueOrNull!;

      expect(transactions, hasLength(1));

      expect(transactions.single.effectiveAt, DateTime.utc(2026, 2, 1));
    });

    test('returns typed failure for archived series', () {
      // Given
      final series = _series(archived: true);

      // When
      final result = service(
        series: series,
        scheduledFrom: CalendarDate(2026, 1, 1),
        scheduledUntil: CalendarDate(2026, 2, 1),
      );

      // Then
      expect(
        result.failureOrNull,
        isA<TransactionSeriesGenerationDisabledFailure>(),
      );
    });

    test('returns typed failure for deleted series', () {
      // Given
      final series = _series(deleted: true);

      // When
      final result = service(
        series: series,
        scheduledFrom: CalendarDate(2026, 1, 1),
        scheduledUntil: CalendarDate(2026, 2, 1),
      );

      // Then
      expect(
        result.failureOrNull,
        isA<TransactionSeriesGenerationDisabledFailure>(),
      );
    });

    test('propagates template instantiation failures', () {
      // Given
      final invalidTemplate = TransactionTemplate(
        kind: TransactionKind.expense,
        merchantId: MerchantId.self,
        splits: const [],
        ledgerEntries: const [],
      );

      final series = _series(template: invalidTemplate);

      // When
      final result = service(
        series: series,
        scheduledFrom: CalendarDate(2026, 1, 1),
        scheduledUntil: CalendarDate(2026, 2, 1),
      );

      // Then
      expect(
        result.failureOrNull,
        isA<TransactionTemplateInstantiationFailure>(),
      );
    });

    test('rejects an empty generation range', () {
      // Given
      final series = _series();

      // When / Then
      expect(
        () => service(
          series: series,
          scheduledFrom: CalendarDate(2026, 2, 1),
          scheduledUntil: CalendarDate(2026, 2, 1),
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.name,
            'name',
            'scheduledUntil',
          ),
        ),
      );
    });

    test('rejects a reversed generation range', () {
      // Given
      final series = _series();

      // When / Then
      expect(
        () => service(
          series: series,
          scheduledFrom: CalendarDate(2026, 2, 2),
          scheduledUntil: CalendarDate(2026, 2, 1),
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.name,
            'name',
            'scheduledUntil',
          ),
        ),
      );
    });

    test('never generates beyond the rolling two-year hard cap', () {
      // Given
      final cappedService = GeneratePlannedTransactionsService(
        clock: FixedClock(DateTime.utc(2026, 9, 21)),
        resizeTemplate: const ResizePlannedTransactionTemplateService(),
      );

      final series = _series(
        recurrenceRule: RecurrenceRule(
          startsOn: CalendarDate(2026, 9, 21),
          frequency: RecurrenceFrequency.monthly,
        ),
      );

      // When
      final result = cappedService(
        series: series,
        scheduledFrom: CalendarDate(2026, 9, 21),
        scheduledUntil: CalendarDate(2036, 1, 1),
        generationHorizon: PlannedTransactionGenerationHorizon.twoYears,
      );

      // Then
      final transactions = result.valueOrNull!;

      expect(transactions, hasLength(25));
      expect(transactions.first.effectiveAt, DateTime.utc(2026, 9, 21));
      expect(transactions.last.effectiveAt, DateTime.utc(2028, 9, 21));

      expect(
        transactions.any(
          (transaction) =>
              transaction.effectiveAt.isAfter(DateTime.utc(2028, 9, 21)),
        ),
        isFalse,
      );
    });

    test('one-year preference generates through the one-year anniversary', () {
      // Given
      final horizonService = GeneratePlannedTransactionsService(
        clock: FixedClock(DateTime.utc(2026, 9, 21)),
        resizeTemplate: const ResizePlannedTransactionTemplateService(),
      );

      final series = _series(
        recurrenceRule: RecurrenceRule(
          startsOn: CalendarDate(2026, 9, 21),
          frequency: RecurrenceFrequency.monthly,
        ),
      );

      // When
      final result = horizonService(
        series: series,
        scheduledFrom: CalendarDate(2026, 9, 21),
        scheduledUntil: CalendarDate(2036, 1, 1),
        generationHorizon: PlannedTransactionGenerationHorizon.oneYear,
      );

      // Then
      final transactions = result.valueOrNull!;

      expect(transactions, hasLength(13));
      expect(transactions.first.effectiveAt, DateTime.utc(2026, 9, 21));
      expect(transactions.last.effectiveAt, DateTime.utc(2027, 9, 21));
    });

    test(
      'next-occurrence preference generates only one eligible occurrence',
      () {
        // Given
        final horizonService = GeneratePlannedTransactionsService(
          clock: FixedClock(DateTime.utc(2026, 9, 21)),
          resizeTemplate: const ResizePlannedTransactionTemplateService(),
        );

        final series = _series(
          recurrenceRule: RecurrenceRule(
            startsOn: CalendarDate(2026, 10, 1),
            frequency: RecurrenceFrequency.monthly,
          ),
        );

        // When
        final result = horizonService(
          series: series,
          scheduledFrom: CalendarDate(2026, 9, 21),
          scheduledUntil: CalendarDate(2036, 1, 1),
          generationHorizon: PlannedTransactionGenerationHorizon.nextOccurrence,
        );

        // Then
        final transactions = result.valueOrNull!;

        expect(transactions, hasLength(1));
        expect(transactions.single.effectiveAt, DateTime.utc(2026, 10, 1));
      },
    );

    test('next-occurrence preference skips skipped occurrences', () {
      // Given
      final horizonService = GeneratePlannedTransactionsService(
        clock: FixedClock(DateTime.utc(2026, 9, 21)),
        resizeTemplate: const ResizePlannedTransactionTemplateService(),
      );

      final series = _series(
        recurrenceRule: RecurrenceRule(
          startsOn: CalendarDate(2026, 10, 1),
          frequency: RecurrenceFrequency.monthly,
        ),
        exceptions: [
          RecurrenceException.skip(scheduledOn: CalendarDate(2026, 10, 1)),
        ],
      );

      // When
      final result = horizonService(
        series: series,
        scheduledFrom: CalendarDate(2026, 9, 21),
        scheduledUntil: CalendarDate(2036, 1, 1),
        generationHorizon: PlannedTransactionGenerationHorizon.nextOccurrence,
      );

      // Then
      final transactions = result.valueOrNull!;

      expect(transactions, hasLength(1));
      expect(transactions.single.effectiveAt, DateTime.utc(2026, 11, 1));
    });

    test(
      'returns no transactions when requested range starts beyond hard cap',
      () {
        // Given
        final cappedService = GeneratePlannedTransactionsService(
          clock: FixedClock(DateTime.utc(2026, 9, 21)),
          resizeTemplate: const ResizePlannedTransactionTemplateService(),
        );

        final series = _series(
          recurrenceRule: RecurrenceRule(
            startsOn: CalendarDate(2026, 1, 1),
            frequency: RecurrenceFrequency.monthly,
          ),
        );

        // When
        final result = cappedService(
          series: series,
          scheduledFrom: CalendarDate(2029, 1, 1),
          scheduledUntil: CalendarDate(2030, 1, 1),
        );

        // Then
        expect(result.valueOrNull, isEmpty);
      },
    );
  });
}

TransactionSeries _series({
  TransactionTemplate? template,
  RecurrenceRule? recurrenceRule,
  List<RecurrenceException> exceptions = const [],
  bool archived = false,
  bool deleted = false,
}) {
  final createdAt = DateTime.utc(2026, 1, 1);
  final lifecycleAt = DateTime.utc(2026, 1, 2);

  return TransactionSeries(
    id: TransactionSeriesId.fromString('series'),
    template: template ?? _template(),
    recurrenceRule:
        recurrenceRule ??
        RecurrenceRule(
          startsOn: CalendarDate(2026, 1, 1),
          frequency: RecurrenceFrequency.monthly,
        ),
    exceptions: exceptions,
    archivedAt: archived ? lifecycleAt : null,
    deletedAt: deleted ? lifecycleAt : null,
    createdAt: createdAt,
    modifiedAt: archived || deleted ? lifecycleAt : createdAt,
    entityVersion: 1,
  );
}

RecurrenceRule _amountRule({
  required String target,
  required RecurrenceAmountCompletion completion,
}) {
  return RecurrenceRule(
    startsOn: CalendarDate(2026, 1, 1),
    frequency: RecurrenceFrequency.monthly,
    end: RecurrenceEnd(
      amount: RecurrenceAmountEnd(
        targetAmount: AssetAmount(
          assetId: AssetId.fromString('asset-chf'),
          amount: Decimal.parse(target),
          direction: AssetAmountDirection.outgoing,
        ),
        completion: completion,
      ),
    ),
  );
}

TransactionTemplate _template({String amount = '120'}) {
  final primaryAmount = AssetAmount.outgoing(
    assetId: AssetId.fromString('asset-chf'),
    amount: Decimal.parse(amount),
  );

  return TransactionTemplate(
    kind: TransactionKind.expense,
    merchantId: MerchantId.self,
    description: 'Recurring expense',
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

Decimal _primaryAmount(dynamic transaction) {
  return transaction.ledgerEntries
      .singleWhere((entry) => entry.role == LedgerEntryRole.primary)
      .transactionAmount
      .amount;
}

Decimal _totalPrimaryAmount(Iterable<dynamic> transactions) {
  return transactions.fold<Decimal>(
    Decimal.zero,
    (total, transaction) => total + _primaryAmount(transaction),
  );
}
