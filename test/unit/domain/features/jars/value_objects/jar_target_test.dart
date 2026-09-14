import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/features/assets/domain/enums/asset_amount_direction.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/jars/domain/value_objects/jar_target.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

void main() {
  group('JarTarget', () {
    test('accepts a positive amount and target date on its effective date', () {
      final effectiveFrom = CalendarDate(2026, 1, 1);
      final target = _target(
        effectiveFrom: effectiveFrom,
        targetDate: effectiveFrom,
      );

      expect(target.amount.amount, Decimal.parse('100'));
      expect(target.effectiveFrom, effectiveFrom);
      expect(target.effectiveUntil, isNull);
      expect(target.targetDate, effectiveFrom);
    });

    test('rejects zero and unknown target amounts', () {
      expect(
        () => _target(amount: Decimal.zero),
        throwsA(isA<ArgumentError>().having((error) => error.name, 'name', 'amount')),
      );
      expect(
        () => _target(amount: Decimal.fromInt(-1)),
        throwsA(isA<ArgumentError>().having((error) => error.name, 'name', 'amount')),
      );
    });

    test('rejects an effective end equal to or before its start', () {
      final effectiveFrom = CalendarDate(2026, 1, 1);

      expect(
        () => _target(
          effectiveFrom: effectiveFrom,
          effectiveUntil: effectiveFrom,
        ),
        throwsA(
          isA<ArgumentError>()
              .having((error) => error.name, 'name', 'effectiveUntil'),
        ),
      );
      expect(
        () => _target(
          effectiveFrom: effectiveFrom,
          effectiveUntil: CalendarDate(2025, 12, 31),
        ),
        throwsA(
          isA<ArgumentError>()
              .having((error) => error.name, 'name', 'effectiveUntil'),
        ),
      );
    });

    test('rejects a target date before its effective start', () {
      expect(
        () => _target(targetDate: CalendarDate(2025, 12, 31)),
        throwsA(isA<ArgumentError>().having((error) => error.name, 'name', 'targetDate')),
      );
    });

    test('applies from its inclusive start through its exclusive end', () {
      final target = _target(effectiveUntil: CalendarDate(2026, 4, 1));

      expect(target.appliesOn(CalendarDate(2025, 12, 31)), isFalse);
      expect(target.appliesOn(CalendarDate(2026, 1, 1)), isTrue);
      expect(target.appliesOn(CalendarDate(2026, 3, 31)), isTrue);
      expect(target.appliesOn(CalendarDate(2026, 4, 1)), isFalse);
      expect(target.appliesOn(CalendarDate(2026, 4, 2)), isFalse);
    });

    test('with no effective end remains applicable indefinitely', () {
      final target = _target();

      expect(target.appliesOn(CalendarDate(2099, 12, 31)), isTrue);
    });
  });
}

JarTarget _target({
  Decimal? amount,
  AssetId? assetId,
  CalendarDate? effectiveFrom,
  CalendarDate? effectiveUntil,
  CalendarDate? targetDate,
}) {
  return JarTarget(
    amount: AssetAmount(
      assetId: assetId ?? AssetId.fromString('asset-chf'),
      amount: amount ?? Decimal.parse('100'),
      direction: AssetAmountDirection.incoming,
    ),
    effectiveFrom: effectiveFrom ?? CalendarDate(2026, 1, 1),
    effectiveUntil: effectiveUntil,
    targetDate: targetDate,
  );
}
