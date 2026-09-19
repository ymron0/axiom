@Tags(['application'])
library;

import 'package:axiom/src/application/services/generate_planned_transactions_service.dart';
import 'package:axiom/src/features/transactions/domain/services/resize_planned_transaction_template_service.dart';
import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/identity/ids/transaction_series_id.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/features/assets/domain/enums/asset_amount_direction.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction_series.dart';
import 'package:axiom/src/features/transactions/domain/enums/ledger_entry_role.dart';
import 'package:axiom/src/features/transactions/domain/enums/recurrence_amount_completion.dart';
import 'package:axiom/src/features/transactions/domain/enums/recurrence_frequency.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_kind.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_state.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_series_generation_disabled_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_template_instantiation_failure.dart';
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

      expect(
        transactions[1].ledgerEntries.single.transactionAmount.amount,
        Decimal.parse('75'),
      );
    });

    test('generates an exact final amount occurrence', () {
      // Given
      final target = AssetAmount(
        assetId: AssetId.fromString('asset-chf'),
        amount: Decimal.parse('1000'),
        direction: AssetAmountDirection.outgoing,
      );

      final series = _series(
        recurrenceRule: RecurrenceRule(
          startsOn: CalendarDate(2026, 1, 1),
          frequency: RecurrenceFrequency.monthly,
          end: RecurrenceEnd(
            amount: RecurrenceAmountEnd(
              targetAmount: target,
              completion: RecurrenceAmountCompletion.exactTarget,
            ),
          ),
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
        transactions
            .take(8)
            .map(
              (transaction) =>
                  transaction.ledgerEntries.single.transactionAmount.amount,
            ),
        everyElement(Decimal.parse('120')),
      );

      expect(
        transactions.last.ledgerEntries.single.transactionAmount.amount,
        Decimal.parse('40'),
      );
    });

    test('evaluates amount progress before scheduledFrom', () {
      // Given
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
      expect(
        transactions.single.ledgerEntries.single.transactionAmount.amount,
        Decimal.parse('60'),
      );
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

    test('rejects an empty or reversed generation range', () {
      // Given
      final series = _series();

      // When / Then
      expect(
        () => service(
          series: series,
          scheduledFrom: CalendarDate(2026, 2, 1),
          scheduledUntil: CalendarDate(2026, 2, 1),
        ),
        throwsArgumentError,
      );
    });
  });
}

TransactionSeries _series({
  TransactionTemplate? template,
  RecurrenceRule? recurrenceRule,
  List<RecurrenceException> exceptions = const [],
  bool archived = false,
}) {
  final createdAt = DateTime.utc(2026, 1, 1);
  final archivedAt = archived ? DateTime.utc(2026, 1, 2) : null;

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
    archivedAt: archivedAt,
    createdAt: createdAt,
    modifiedAt: archivedAt ?? createdAt,
    entityVersion: 1,
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
