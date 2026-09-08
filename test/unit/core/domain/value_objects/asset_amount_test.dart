import 'package:axiom/src/core/domain/enums/asset_amount_direction.dart';
import 'package:axiom/src/core/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_id.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

void main() {
  group('AssetAmount', () {
    final assetId = AssetId.fromString('asset-123');

    group('construction', () {
      test('preserves the asset, amount, and direction', () {
        final value = Decimal.parse('12.5');

        final amount = AssetAmount(
          assetId: assetId,
          amount: value,
          direction: AssetAmountDirection.incoming,
        );

        expect(amount.assetId, assetId);
        expect(amount.amount, value);
        expect(amount.direction, AssetAmountDirection.incoming);
      });

      test('allows unknown, zero, and positive amounts', () {
        final allowedValues = [
          Decimal.fromInt(-1),
          Decimal.zero,
          Decimal.parse('0.00000001'),
        ];

        for (final value in allowedValues) {
          final amount = AssetAmount(
            assetId: assetId,
            amount: value,
            direction: AssetAmountDirection.incoming,
          );

          expect(amount.amount, value);
        }
      });

      test('rejects negative amounts other than exactly minus one', () {
        final invalidValues = [
          Decimal.parse('-0.5'),
          Decimal.parse('-1.1'),
          Decimal.fromInt(-2),
        ];

        for (final value in invalidValues) {
          expect(
            () => AssetAmount(
              assetId: assetId,
              amount: value,
              direction: AssetAmountDirection.incoming,
            ),
            throwsA(
              isA<ArgumentError>()
                  .having((error) => error.invalidValue, 'invalidValue', value)
                  .having((error) => error.name, 'name', 'amount'),
            ),
            reason: 'Expected $value to be rejected.',
          );
        }
      });
    });

    group('incoming', () {
      test('creates an incoming amount', () {
        final value = Decimal.parse('12.5');

        final amount = AssetAmount.incoming(assetId: assetId, amount: value);

        expect(amount.assetId, assetId);
        expect(amount.amount, value);
        expect(amount.direction, AssetAmountDirection.incoming);
        expect(amount.isIncoming, isTrue);
        expect(amount.isOutgoing, isFalse);
      });
    });

    group('outgoing', () {
      test('creates an outgoing amount', () {
        final value = Decimal.parse('12.5');

        final amount = AssetAmount.outgoing(assetId: assetId, amount: value);

        expect(amount.assetId, assetId);
        expect(amount.amount, value);
        expect(amount.direction, AssetAmountDirection.outgoing);
        expect(amount.isOutgoing, isTrue);
        expect(amount.isIncoming, isFalse);
      });
    });

    group('amount state', () {
      test('identifies known and unknown amounts', () {
        final unknown = AssetAmount.incoming(
          assetId: assetId,
          amount: Decimal.fromInt(-1),
        );
        final known = AssetAmount.incoming(
          assetId: assetId,
          amount: Decimal.zero,
        );

        expect(unknown.isKnownAmount, isFalse);
        expect(unknown.isUnknownAmount, isTrue);
        expect(known.isKnownAmount, isTrue);
        expect(known.isUnknownAmount, isFalse);
      });
    });

    group('arithmetic', () {
      test('adds same-asset amounts using their directions', () {
        final incoming = AssetAmount.incoming(
          assetId: assetId,
          amount: Decimal.parse('10'),
        );
        final outgoing = AssetAmount.outgoing(
          assetId: assetId,
          amount: Decimal.parse('3'),
        );

        final result = incoming.add(outgoing);

        expect(result.amount, Decimal.parse('7'));
        expect(result.direction, AssetAmountDirection.incoming);
      });

      test('subtracts same-asset amounts using their directions', () {
        final outgoing = AssetAmount.outgoing(
          assetId: assetId,
          amount: Decimal.parse('3'),
        );
        final incoming = AssetAmount.incoming(
          assetId: assetId,
          amount: Decimal.parse('10'),
        );

        final result = outgoing.subtract(incoming);

        expect(result.amount, Decimal.parse('13'));
        expect(result.direction, AssetAmountDirection.outgoing);
      });

      test('supports same-direction addition and signed subtraction', () {
        final incoming = AssetAmount.incoming(
          assetId: assetId,
          amount: Decimal.parse('10'),
        );
        final outgoing = AssetAmount.outgoing(
          assetId: assetId,
          amount: Decimal.parse('3'),
        );

        final incomingSum = incoming.add(incoming);
        final outgoingSum = outgoing.add(outgoing);
        final incomingDifference = incoming.subtract(outgoing);

        expect(incomingSum.amount, Decimal.parse('20'));
        expect(incomingSum.direction, AssetAmountDirection.incoming);
        expect(outgoingSum.amount, Decimal.parse('6'));
        expect(outgoingSum.direction, AssetAmountDirection.outgoing);
        expect(incomingDifference.amount, Decimal.parse('13'));
        expect(incomingDifference.direction, AssetAmountDirection.incoming);
      });

      test('preserves the receiver direction when a known result is zero', () {
        final incoming = AssetAmount.incoming(
          assetId: assetId,
          amount: Decimal.parse('5'),
        );
        final outgoing = AssetAmount.outgoing(
          assetId: assetId,
          amount: Decimal.parse('5'),
        );

        final result = incoming.add(outgoing);

        expect(result.amount, Decimal.zero);
        expect(result.direction, AssetAmountDirection.incoming);
      });

      test('propagates unknown amounts without treating minus one as a value', () {
        final unknown = AssetAmount.incoming(
          assetId: assetId,
          amount: Decimal.fromInt(-1),
        );
        final known = AssetAmount.incoming(
          assetId: assetId,
          amount: Decimal.parse('5'),
        );

        final result = unknown.add(known);

        expect(result.isUnknownAmount, isTrue);
        expect(result.direction, AssetAmountDirection.incoming);

        final resultWithUnknownOther = known.add(unknown);

        expect(resultWithUnknownOther.isUnknownAmount, isTrue);
        expect(resultWithUnknownOther.direction, AssetAmountDirection.incoming);

        final subtractionWithUnknown = unknown.subtract(known);
        final subtractionWithUnknownOther = known.subtract(unknown);

        expect(subtractionWithUnknown.isUnknownAmount, isTrue);
        expect(subtractionWithUnknown.direction, AssetAmountDirection.incoming);
        expect(subtractionWithUnknownOther.isUnknownAmount, isTrue);
        expect(
          subtractionWithUnknownOther.direction,
          AssetAmountDirection.incoming,
        );
      });

      test('rejects different assets for addition and subtraction', () {
        final amount = AssetAmount.incoming(
          assetId: assetId,
          amount: Decimal.one,
        );
        final other = AssetAmount.incoming(
          assetId: AssetId.fromString('other-asset'),
          amount: Decimal.one,
        );

        expect(
          () => amount.add(other),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => amount.subtract(other),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('compares same-asset amounts by signed balance change', () {
        final incoming = AssetAmount.incoming(
          assetId: assetId,
          amount: Decimal.parse('10'),
        );
        final outgoing = AssetAmount.outgoing(
          assetId: assetId,
          amount: Decimal.parse('3'),
        );
        final equivalentIncoming = AssetAmount.incoming(
          assetId: assetId,
          amount: Decimal.parse('10'),
        );

        expect(incoming.isGreaterThan(outgoing), isTrue);
        expect(outgoing.isLessThan(incoming), isTrue);
        expect(incoming.isEqualTo(equivalentIncoming), isTrue);
        expect(incoming.isEqualTo(outgoing), isFalse);
      });

      test('rejects comparisons involving unknown amounts', () {
        final unknown = AssetAmount.incoming(
          assetId: assetId,
          amount: Decimal.fromInt(-1),
        );
        final known = AssetAmount.incoming(
          assetId: assetId,
          amount: Decimal.parse('5'),
        );

        expect(
          () => unknown.isGreaterThan(known),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => known.isLessThan(unknown),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => unknown.isEqualTo(unknown),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('rejects comparisons between different assets', () {
        final amount = AssetAmount.incoming(
          assetId: assetId,
          amount: Decimal.one,
        );
        final other = AssetAmount.incoming(
          assetId: AssetId.fromString('other-asset'),
          amount: Decimal.one,
        );

        expect(
          () => amount.isGreaterThan(other),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => amount.isLessThan(other),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => amount.isEqualTo(other),
          throwsA(isA<ArgumentError>()),
        );
      });
    });
  });
}
