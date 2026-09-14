@Tags(['domain'])
library;

import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/jars/domain/value_objects/jar_progress.dart';
import 'package:axiom/src/features/jars/domain/value_objects/jar_target.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

void main() {
  group('JarProgress', () {
    final chf = AssetId.fromString('currency-chf');
    final otherAssetId = AssetId.fromString('currency-eur');
    final jarId = JarId.fromString('jar-holiday');
    final asOf = CalendarDate(2026, 9, 14);

    AssetAmount amount({
      AssetId? assetId,
      Decimal? value,
      bool outgoing = false,
    }) {
      final resolvedValue = value ?? Decimal.zero;
      return outgoing
          ? AssetAmount.outgoing(
              assetId: assetId ?? chf,
              amount: resolvedValue,
            )
          : AssetAmount.incoming(
              assetId: assetId ?? chf,
              amount: resolvedValue,
            );
    }

    JarTarget target({AssetId? assetId}) {
      return JarTarget(
        amount: amount(assetId: assetId, value: Decimal.fromInt(100)),
        effectiveFrom: CalendarDate(2026, 1, 1),
      );
    }

    JarProgress create({
      AssetAmount? balance,
      AssetAmount? savedAmount,
      JarTarget? target,
      AssetAmount? remainingAmount,
      Decimal? progressRatio,
      bool isTargetReached = false,
    }) {
      return JarProgress(
        jarId: jarId,
        asOf: asOf,
        balance: balance ?? amount(value: Decimal.fromInt(50)),
        savedAmount: savedAmount ?? amount(value: Decimal.fromInt(50)),
        target: target,
        remainingAmount: remainingAmount,
        progressRatio: progressRatio,
        isTargetReached: isTargetReached,
      );
    }

    test('rejects an unknown balance', () {
      expect(
        () => create(balance: amount(value: Decimal.fromInt(-1))),
        throwsArgumentError,
      );
    });

    test('rejects an unknown saved amount', () {
      expect(
        () => create(savedAmount: amount(value: Decimal.fromInt(-1))),
        throwsArgumentError,
      );
    });

    test('rejects a saved amount with a different asset', () {
      expect(
        () => create(savedAmount: amount(assetId: otherAssetId)),
        throwsArgumentError,
      );
    });

    test('rejects an outgoing saved amount', () {
      expect(
        () => create(savedAmount: amount(outgoing: true)),
        throwsArgumentError,
      );
    });

    test('rejects progress fields when no target is effective', () {
      expect(
        () => create(progressRatio: Decimal.zero),
        throwsArgumentError,
      );
      expect(
        () => create(remainingAmount: amount()),
        throwsArgumentError,
      );
      expect(
        () => create(isTargetReached: true),
        throwsArgumentError,
      );
    });

    test('rejects a target with a different asset', () {
      expect(
        () => create(target: target(assetId: otherAssetId)),
        throwsArgumentError,
      );
    });

    test('rejects missing remaining amount for a target', () {
      expect(
        () => create(target: target(), progressRatio: Decimal.zero),
        throwsArgumentError,
      );
    });

    test('rejects a remaining amount with a different asset', () {
      expect(
        () => create(
          target: target(),
          remainingAmount: amount(assetId: otherAssetId),
          progressRatio: Decimal.zero,
        ),
        throwsArgumentError,
      );
    });

    test('rejects an unknown remaining amount', () {
      expect(
        () => create(
          target: target(),
          remainingAmount: amount(value: Decimal.fromInt(-1)),
          progressRatio: Decimal.zero,
        ),
        throwsArgumentError,
      );
    });

    test('rejects an outgoing remaining amount', () {
      expect(
        () => create(
          target: target(),
          remainingAmount: amount(outgoing: true),
          progressRatio: Decimal.zero,
        ),
        throwsArgumentError,
      );
    });

    test('rejects missing progress ratio for a target', () {
      expect(
        () => create(target: target(), remainingAmount: amount()),
        throwsArgumentError,
      );
    });

    test('rejects a progress ratio below zero', () {
      expect(
        () => create(
          target: target(),
          remainingAmount: amount(),
          progressRatio: Decimal.parse('-0.1'),
        ),
        throwsArgumentError,
      );
    });

    test('rejects a progress ratio above one', () {
      expect(
        () => create(
          target: target(),
          remainingAmount: amount(),
          progressRatio: Decimal.parse('1.1'),
        ),
        throwsArgumentError,
      );
    });
  });
}
