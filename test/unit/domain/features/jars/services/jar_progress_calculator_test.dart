@Tags(['domain'])
library;

import 'package:axiom/src/core/domain/enums/entity_color.dart';
import 'package:axiom/src/core/domain/enums/entity_icon.dart';
import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/jars/domain/entities/jar.dart';
import 'package:axiom/src/features/jars/domain/enums/jar_kind.dart';
import 'package:axiom/src/features/jars/domain/services/jar_progress_calculator.dart';
import 'package:axiom/src/features/jars/domain/value_objects/jar_target.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

void main() {
  group('JarProgressCalculator', () {
    const calculator = JarProgressCalculator();

    final chf = AssetId.fromString('currency-chf');
    final eur = AssetId.fromString('currency-eur');

    Jar createJar({List<JarTarget> targets = const []}) {
      return Jar(
        id: JarId.fromString('jar-holiday'),
        name: 'Holiday',
        kind: JarKind.savingsGoal,
        targets: targets,
        icon: EntityIcon.savings,
        color: EntityColor.blue,
        sortOrder: 0,
        createdAt: DateTime.utc(2026, 1, 1),
        modifiedAt: DateTime.utc(2026, 1, 1),
        entityVersion: 1,
      );
    }

    JarTarget target({
      String amount = '1000',
      AssetId? assetId,
      CalendarDate? effectiveFrom,
      CalendarDate? effectiveUntil,
    }) {
      return JarTarget(
        amount: AssetAmount.incoming(
          assetId: assetId ?? chf,
          amount: Decimal.parse(amount),
        ),
        effectiveFrom: effectiveFrom ?? CalendarDate(2026, 1, 1),
        effectiveUntil: effectiveUntil,
      );
    }

    test('returns balance without progress when jar has no target', () {
      final jar = createJar();

      final result = calculator.calculate(
        jar: jar,
        balance: AssetAmount.incoming(
          assetId: chf,
          amount: Decimal.parse('400'),
        ),
        asOf: CalendarDate(2026, 9, 14),
      );

      expect(result.balance.amount, Decimal.parse('400'));
      expect(result.savedAmount.amount, Decimal.parse('400'));
      expect(result.hasTarget, isFalse);
      expect(result.target, isNull);
      expect(result.remainingAmount, isNull);
      expect(result.progressRatio, isNull);
      expect(result.isTargetReached, isFalse);
    });

    test('rejects an unknown balance', () {
      expect(
        () => calculator.calculate(
          jar: createJar(),
          balance: AssetAmount.incoming(
            assetId: chf,
            amount: Decimal.fromInt(-1),
          ),
          asOf: CalendarDate(2026, 9, 14),
        ),
        throwsArgumentError,
      );
    });

    test('calculates partial target progress', () {
      final jar = createJar(targets: [target()]);

      final result = calculator.calculate(
        jar: jar,
        balance: AssetAmount.incoming(
          assetId: chf,
          amount: Decimal.parse('400'),
        ),
        asOf: CalendarDate(2026, 9, 14),
      );

      expect(result.savedAmount.amount, Decimal.parse('400'));
      expect(result.remainingAmount!.amount, Decimal.parse('600'));
      expect(result.progressRatio, Decimal.parse('0.4'));
      expect(result.isTargetReached, isFalse);
    });

    test('returns complete progress when target is reached exactly', () {
      final jar = createJar(targets: [target()]);

      final result = calculator.calculate(
        jar: jar,
        balance: AssetAmount.incoming(
          assetId: chf,
          amount: Decimal.parse('1000'),
        ),
        asOf: CalendarDate(2026, 9, 14),
      );

      expect(result.savedAmount.amount, Decimal.parse('1000'));
      expect(result.remainingAmount!.amount, Decimal.zero);
      expect(result.progressRatio, Decimal.one);
      expect(result.isTargetReached, isTrue);
    });

    test('caps progress at one when jar is overfunded', () {
      final jar = createJar(targets: [target()]);

      final result = calculator.calculate(
        jar: jar,
        balance: AssetAmount.incoming(
          assetId: chf,
          amount: Decimal.parse('1250'),
        ),
        asOf: CalendarDate(2026, 9, 14),
      );

      expect(result.savedAmount.amount, Decimal.parse('1250'));
      expect(result.remainingAmount!.amount, Decimal.zero);
      expect(result.progressRatio, Decimal.one);
      expect(result.isTargetReached, isTrue);
    });

    test('negative balance produces zero saved progress', () {
      final jar = createJar(targets: [target()]);

      final result = calculator.calculate(
        jar: jar,
        balance: AssetAmount.outgoing(
          assetId: chf,
          amount: Decimal.parse('100'),
        ),
        asOf: CalendarDate(2026, 9, 14),
      );

      expect(result.balance.amount, Decimal.parse('100'));
      expect(result.balance.isOutgoing, isTrue);

      expect(result.savedAmount.amount, Decimal.zero);
      expect(result.remainingAmount!.amount, Decimal.parse('1100'));
      expect(result.progressRatio, Decimal.zero);
      expect(result.isTargetReached, isFalse);
    });

    test('uses target effective on requested date', () {
      final jar = createJar(
        targets: [
          target(
            amount: '1000',
            effectiveFrom: CalendarDate(2026, 1, 1),
            effectiveUntil: CalendarDate(2026, 7, 1),
          ),
          target(amount: '1500', effectiveFrom: CalendarDate(2026, 7, 1)),
        ],
      );

      final result = calculator.calculate(
        jar: jar,
        balance: AssetAmount.incoming(
          assetId: chf,
          amount: Decimal.parse('750'),
        ),
        asOf: CalendarDate(2026, 9, 14),
      );

      expect(result.target!.amount.amount, Decimal.parse('1500'));
      expect(result.remainingAmount!.amount, Decimal.parse('750'));
      expect(result.progressRatio, Decimal.parse('0.5'));
    });

    test('rejects target and balance using different currencies', () {
      final jar = createJar(targets: [target(assetId: eur)]);

      expect(
        () => calculator.calculate(
          jar: jar,
          balance: AssetAmount.incoming(
            assetId: chf,
            amount: Decimal.parse('500'),
          ),
          asOf: CalendarDate(2026, 9, 14),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
