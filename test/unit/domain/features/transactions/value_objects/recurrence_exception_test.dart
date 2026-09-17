@Tags(['domain'])
library;

import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/transactions/domain/enums/ledger_entry_role.dart';
import 'package:axiom/src/features/transactions/domain/enums/recurrence_exception_kind.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_kind.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/ledger_entry.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/recurrence_exception.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/transaction_template.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

void main() {
  group('RecurrenceException', () {
    group('skip', () {
      test('creates a skipped recurrence occurrence', () {
        // Given
        final scheduledOn = CalendarDate(2026, 10, 1);

        // When
        final exception = RecurrenceException.skip(scheduledOn: scheduledOn);

        // Then
        expect(exception.scheduledOn, scheduledOn);
        expect(exception.kind, RecurrenceExceptionKind.skip);
        expect(exception.replacementOn, isNull);
        expect(exception.replacementTemplate, isNull);
        expect(exception.isSkipped, isTrue);
        expect(exception.isReplacement, isFalse);
        expect(exception.effectiveDate, isNull);
      });

      test('resolves no template for a skipped occurrence', () {
        // Given
        final exception = RecurrenceException.skip(
          scheduledOn: CalendarDate(2026, 10, 1),
        );

        // When
        final resolved = exception.resolveTemplate(_template('normal'));

        // Then
        expect(resolved, isNull);
      });

      test('rejects a replacement date on a skip exception', () {
        // Given
        final replacementOn = CalendarDate(2026, 10, 2);

        // When
        RecurrenceException construct() {
          return RecurrenceException(
            scheduledOn: CalendarDate(2026, 10, 1),
            kind: RecurrenceExceptionKind.skip,
            replacementOn: replacementOn,
          );
        }

        // Then
        expect(
          construct,
          throwsA(
            isA<ArgumentError>()
                .having((error) => error.name, 'name', 'replacementOn')
                .having(
                  (error) => error.invalidValue,
                  'invalidValue',
                  replacementOn,
                ),
          ),
        );
      });

      test('rejects a replacement template on a skip exception', () {
        // Given
        final replacementTemplate = _template('replacement');

        // When
        RecurrenceException construct() {
          return RecurrenceException(
            scheduledOn: CalendarDate(2026, 10, 1),
            kind: RecurrenceExceptionKind.skip,
            replacementTemplate: replacementTemplate,
          );
        }

        // Then
        expect(
          construct,
          throwsA(
            isA<ArgumentError>()
                .having((error) => error.name, 'name', 'replacementTemplate')
                .having(
                  (error) => error.invalidValue,
                  'invalidValue',
                  replacementTemplate,
                ),
          ),
        );
      });
    });

    group('replacement', () {
      test('moves an occurrence while keeping the normal template', () {
        // Given
        final scheduledOn = CalendarDate(2026, 10, 1);
        final replacementOn = CalendarDate(2026, 10, 3);
        final seriesTemplate = _template('normal');

        // When
        final exception = RecurrenceException.replace(
          scheduledOn: scheduledOn,
          replacementOn: replacementOn,
        );

        // Then
        expect(exception.kind, RecurrenceExceptionKind.replacement);
        expect(exception.isReplacement, isTrue);
        expect(exception.isSkipped, isFalse);
        expect(exception.effectiveDate, replacementOn);
        expect(exception.resolveTemplate(seriesTemplate), same(seriesTemplate));
      });

      test(
        'replaces the template while keeping the original scheduled date',
        () {
          // Given
          final scheduledOn = CalendarDate(2026, 10, 1);
          final replacementTemplate = _template('special');

          // When
          final exception = RecurrenceException.replace(
            scheduledOn: scheduledOn,
            replacementTemplate: replacementTemplate,
          );

          // Then
          expect(exception.effectiveDate, scheduledOn);
          expect(
            exception.resolveTemplate(_template('normal')),
            same(replacementTemplate),
          );
        },
      );

      test('can replace both date and template', () {
        // Given
        final scheduledOn = CalendarDate(2026, 10, 1);
        final replacementOn = CalendarDate(2026, 9, 30);
        final replacementTemplate = _template('special');

        // When
        final exception = RecurrenceException.replace(
          scheduledOn: scheduledOn,
          replacementOn: replacementOn,
          replacementTemplate: replacementTemplate,
        );

        // Then
        expect(exception.scheduledOn, scheduledOn);
        expect(exception.effectiveDate, replacementOn);
        expect(
          exception.resolveTemplate(_template('normal')),
          same(replacementTemplate),
        );
      });

      test('allows replacement dates before the scheduled occurrence', () {
        // Given / When
        final exception = RecurrenceException.replace(
          scheduledOn: CalendarDate(2026, 10, 1),
          replacementOn: CalendarDate(2026, 9, 29),
        );

        // Then
        expect(exception.effectiveDate, CalendarDate(2026, 9, 29));
      });

      test('allows replacement dates after the scheduled occurrence', () {
        // Given / When
        final exception = RecurrenceException.replace(
          scheduledOn: CalendarDate(2026, 10, 1),
          replacementOn: CalendarDate(2026, 10, 4),
        );

        // Then
        expect(exception.effectiveDate, CalendarDate(2026, 10, 4));
      });

      test('rejects a replacement without any effective change', () {
        // When
        RecurrenceException construct() {
          return RecurrenceException.replace(
            scheduledOn: CalendarDate(2026, 10, 1),
          );
        }

        // Then
        expect(
          construct,
          throwsA(
            isA<ArgumentError>().having((error) => error.name, 'name', 'kind'),
          ),
        );
      });

      test('rejects the same replacement date when no template changes', () {
        // Given
        final scheduledOn = CalendarDate(2026, 10, 1);

        // When
        RecurrenceException construct() {
          return RecurrenceException.replace(
            scheduledOn: scheduledOn,
            replacementOn: CalendarDate(2026, 10, 1),
          );
        }

        // Then
        expect(
          construct,
          throwsA(
            isA<ArgumentError>().having((error) => error.name, 'name', 'kind'),
          ),
        );
      });

      test('allows the same date when the transaction template changes', () {
        // Given
        final scheduledOn = CalendarDate(2026, 10, 1);
        final replacementTemplate = _template('special');

        // When
        final exception = RecurrenceException.replace(
          scheduledOn: scheduledOn,
          replacementOn: CalendarDate(2026, 10, 1),
          replacementTemplate: replacementTemplate,
        );

        // Then
        expect(exception.effectiveDate, scheduledOn);
        expect(
          exception.resolveTemplate(_template('normal')),
          same(replacementTemplate),
        );
      });
    });
  });
}

TransactionTemplate _template(String description) {
  final amount = AssetAmount.outgoing(
    assetId: AssetId.fromString('asset-chf'),
    amount: Decimal.parse('100'),
  );

  return TransactionTemplate(
    kind: TransactionKind.expense,
    merchantId: MerchantId.self,
    description: description,
    splits: const [],
    ledgerEntries: [
      LedgerEntry(
        accountId: AccountId.fromString('account-1'),
        transactionAmount: amount,
        accountAmount: amount,
        valuationAmount: amount,
        role: LedgerEntryRole.primary,
      ),
    ],
  );
}
