import 'package:axiom/src/core/domain/enums/asset_amount_direction.dart';
import 'package:axiom/src/core/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/core/domain/value_objects/asset_id.dart';
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
        final invalidValues = [Decimal.parse('-0.5'), Decimal.fromInt(-2)];

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

    group('isUnknown', () {
      test('is true only when the amount is exactly minus one', () {
        final unknown = AssetAmount.incoming(
          assetId: assetId,
          amount: Decimal.fromInt(-1),
        );
        final known = AssetAmount.incoming(
          assetId: assetId,
          amount: Decimal.zero,
        );

        expect(unknown.isUnknown, isTrue);
        expect(known.isUnknown, isFalse);
      });
    });
  });
}
