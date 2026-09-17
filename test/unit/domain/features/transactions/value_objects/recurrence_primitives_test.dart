@Tags(['domain'])
library;

import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/transactions/domain/enums/recurrence_amount_completion.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/recurrence_amount_end.dart';
import 'package:axiom/src/features/transactions/domain/enums/recurrence_frequency.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/recurrence_end.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

void main() {
  group('RecurrenceFrequency', () {
    test('contains the supported calendar frequencies', () {
      expect(RecurrenceFrequency.values, [
        RecurrenceFrequency.daily,
        RecurrenceFrequency.weekly,
        RecurrenceFrequency.monthly,
        RecurrenceFrequency.yearly,
      ]);
    });
  });

  group('RecurrenceEnd', () {
    test('rejects an end without any termination condition', () {
      expect(() => RecurrenceEnd(), throwsA(isA<ArgumentError>()));
    });

    test('rejects a non-positive occurrence count', () {
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

    test('permits dates through the inclusive until date', () {
      final end = RecurrenceEnd(until: CalendarDate(2026, 9, 30));

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
      final end = RecurrenceEnd(count: 3);

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

    test('stops when either configured condition is exceeded', () {
      final end = RecurrenceEnd(until: CalendarDate(2026, 12, 31), count: 2);

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
      final end = RecurrenceEnd(count: 5);

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
      final withoutAmount = RecurrenceEnd(count: 1);
      final withAmount = RecurrenceEnd(
        amount: RecurrenceAmountEnd(
          targetAmount: AssetAmount.incoming(
            assetId: AssetId.fromString('asset-123'),
            amount: Decimal.fromInt(100),
          ),
          completion: RecurrenceAmountCompletion.fullOccurrence,
        ),
      );

      expect(withoutAmount.hasAmountTarget, isFalse);
      expect(withAmount.hasAmountTarget, isTrue);
    });
  });
}
