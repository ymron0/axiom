@Tags(['domain'])
library;

import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/transactions/domain/enums/recurrence_amount_completion.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/recurrence_amount_end.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/recurrence_end.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

void main() {
  group('RecurrenceEnd', () {
    test('rejects an end without any termination condition', () {
      // When / Then
      expect(() => RecurrenceEnd(), throwsA(isA<ArgumentError>()));
    });

    test('rejects an occurrence count below one', () {
      // When / Then
      expect(
        () => RecurrenceEnd(count: 0),
        throwsA(
          isA<ArgumentError>().having((error) => error.name, 'name', 'count'),
        ),
      );

      expect(
        () => RecurrenceEnd(count: -1),
        throwsA(
          isA<ArgumentError>().having((error) => error.name, 'name', 'count'),
        ),
      );
    });

    test('permits an occurrence exactly on the inclusive until date', () {
      // Given
      final end = RecurrenceEnd(until: CalendarDate(2026, 9, 30));

      // Then
      expect(
        end.allows(date: CalendarDate(2026, 9, 29), occurrenceIndex: 10),
        isTrue,
      );

      expect(
        end.allows(date: CalendarDate(2026, 9, 30), occurrenceIndex: 11),
        isTrue,
      );

      expect(
        end.allows(date: CalendarDate(2026, 10, 1), occurrenceIndex: 12),
        isFalse,
      );
    });

    test('permits exactly count occurrences using zero-based indexes', () {
      // Given
      final end = RecurrenceEnd(count: 3);

      // Then
      expect(
        end.allows(date: CalendarDate(2099, 1, 1), occurrenceIndex: 0),
        isTrue,
      );

      expect(
        end.allows(date: CalendarDate(2099, 1, 1), occurrenceIndex: 2),
        isTrue,
      );

      expect(
        end.allows(date: CalendarDate(2099, 1, 1), occurrenceIndex: 3),
        isFalse,
      );
    });

    test('stops when either date or count condition is exceeded', () {
      // Given
      final end = RecurrenceEnd(until: CalendarDate(2026, 12, 31), count: 2);

      // Then
      expect(
        end.allows(date: CalendarDate(2026, 2, 1), occurrenceIndex: 1),
        isTrue,
      );

      expect(
        end.allows(date: CalendarDate(2026, 3, 1), occurrenceIndex: 2),
        isFalse,
      );

      expect(
        end.allows(date: CalendarDate(2027, 1, 1), occurrenceIndex: 1),
        isFalse,
      );
    });

    test('rejects a negative occurrence index', () {
      // Given
      final end = RecurrenceEnd(count: 5);

      // When / Then
      expect(
        () => end.allows(date: CalendarDate(2026, 1, 1), occurrenceIndex: -1),
        throwsA(
          isA<RangeError>().having(
            (error) => error.name,
            'name',
            'occurrenceIndex',
          ),
        ),
      );
    });

    test('reports whether an amount target is configured', () {
      // Given
      final withoutAmount = RecurrenceEnd(count: 1);

      final withAmount = RecurrenceEnd(amount: _amountEnd());

      // Then
      expect(withoutAmount.hasAmountTarget, isFalse);
      expect(withAmount.hasAmountTarget, isTrue);
    });

    test('amount-only termination does not restrict calendar occurrences', () {
      // Given
      final end = RecurrenceEnd(amount: _amountEnd());

      // When / Then
      expect(
        end.allows(date: CalendarDate(2099, 12, 31), occurrenceIndex: 100000),
        isTrue,
      );
    });

    test(
      'calendar conditions are still enforced when an amount target exists',
      () {
        // Given
        final end = RecurrenceEnd(count: 2, amount: _amountEnd());

        // Then
        expect(
          end.allows(date: CalendarDate(2026, 1, 1), occurrenceIndex: 0),
          isTrue,
        );

        expect(
          end.allows(date: CalendarDate(2026, 2, 1), occurrenceIndex: 1),
          isTrue,
        );

        expect(
          end.allows(date: CalendarDate(2026, 3, 1), occurrenceIndex: 2),
          isFalse,
        );
      },
    );
  });
}

RecurrenceAmountEnd _amountEnd() {
  return RecurrenceAmountEnd(
    targetAmount: AssetAmount.incoming(
      assetId: AssetId.fromString('asset-chf'),
      amount: Decimal.parse('1000'),
    ),
    completion: RecurrenceAmountCompletion.exactTarget,
  );
}
