import 'package:axiom/src/features/assets/domain/enums/asset_amount_direction.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

void main() {
  group('AssetAmount', () {
    final assetId = AssetId.fromString('asset-123');

    test('preserves both direction states and the AssetId type', () {
      final amounts = [
        AssetAmount(
          assetId: assetId,
          amount: Decimal.parse('2'),
          direction: AssetAmountDirection.incoming,
        ),
        AssetAmount(
          assetId: assetId,
          amount: Decimal.parse('2'),
          direction: AssetAmountDirection.outgoing,
        ),
      ];

      expect(amounts[0].assetId, isA<AssetId>());
      expect(amounts[0].assetId, same(assetId));
      expect(amounts[0].direction, AssetAmountDirection.incoming);
      expect(amounts[1].direction, AssetAmountDirection.outgoing);
    });

    test('allows unknown amount -1 with either direction', () {
      for (final direction in AssetAmountDirection.values) {
        final amount = AssetAmount(
          assetId: assetId,
          amount: Decimal.fromInt(-1),
          direction: direction,
        );

        expect(amount.amount, Decimal.fromInt(-1));
        expect(amount.direction, direction);
        expect(amount.isKnownAmount, isFalse);
        expect(amount.isUnknownAmount, isTrue);
      }
    });

    test('preserves genuine zero and positive amounts in both directions', () {
      for (final direction in AssetAmountDirection.values) {
        final zero = AssetAmount(
          assetId: assetId,
          amount: Decimal.zero,
          direction: direction,
        );
        final positive = AssetAmount(
          assetId: assetId,
          amount: Decimal.parse('12.5'),
          direction: direction,
        );

        expect(zero.amount, Decimal.zero);
        expect(zero.isKnownAmount, isTrue);
        expect(zero.isUnknownAmount, isFalse);
        expect(positive.amount, Decimal.parse('12.5'));
        expect(positive.isKnownAmount, isTrue);
        expect(positive.isUnknownAmount, isFalse);
      }
    });

    test('preserves exact decimal values including eighteen decimals', () {
      final values = ['1', '1.00', '0.123456789012345678'];

      for (final value in values) {
        final amount = AssetAmount.incoming(
          assetId: assetId,
          amount: Decimal.parse(value),
        );

        expect(amount.amount, Decimal.parse(value));
      }
    });

    test('compares equal when all value fields are equal', () {
      final first = AssetAmount.outgoing(
        assetId: assetId,
        amount: Decimal.parse('12.50'),
      );
      final same = AssetAmount.outgoing(
        assetId: AssetId.fromString('asset-123'),
        amount: Decimal.parse('12.50'),
      );
      final differentDirection = AssetAmount.incoming(
        assetId: assetId,
        amount: Decimal.parse('12.50'),
      );

      expect(first, same);
      expect(first, isNot(differentDirection));
    });

    test('round trips through dart_mappable serialization', () {
      final amounts = [
        AssetAmount.outgoing(assetId: assetId, amount: Decimal.parse('12.50')),
        AssetAmount.incoming(assetId: assetId, amount: Decimal.fromInt(-1)),
      ];

      for (final amount in amounts) {
        final decoded = AssetAmountMapper.fromJson(amount.toJson());

        expect(decoded, amount);
      }
    });

    test('rejects negative amounts other than exactly -1', () {
      for (final value in ['-0.01', '-1.01']) {
        final amount = Decimal.parse(value);

        expect(
          () => AssetAmount.incoming(assetId: assetId, amount: amount),
          throwsA(
            isA<ArgumentError>()
                .having((error) => error.invalidValue, 'invalidValue', amount)
                .having((error) => error.name, 'name', 'amount'),
          ),
        );
      }
    });

    test('reports incoming and outgoing states', () {
      final incoming = AssetAmount.incoming(
        assetId: assetId,
        amount: Decimal.one,
      );
      final outgoing = AssetAmount.outgoing(
        assetId: assetId,
        amount: Decimal.one,
      );

      expect(incoming.isIncoming, isTrue);
      expect(incoming.isOutgoing, isFalse);
      expect(outgoing.isIncoming, isFalse);
      expect(outgoing.isOutgoing, isTrue);
    });

    test('adds signed amounts', () {
      final incomingTwo = AssetAmount.incoming(
        assetId: assetId,
        amount: Decimal.parse('2'),
      );
      final outgoingFour = AssetAmount.outgoing(
        assetId: assetId,
        amount: Decimal.parse('4'),
      );

      final positiveResult = incomingTwo.add(incomingTwo);
      final negativeResult = incomingTwo.add(outgoingFour);

      expect(positiveResult.amount, Decimal.parse('4'));
      expect(positiveResult.direction, AssetAmountDirection.incoming);
      expect(negativeResult.amount, Decimal.parse('2'));
      expect(negativeResult.direction, AssetAmountDirection.outgoing);
    });

    test('subtracts signed amounts', () {
      final incomingOne = AssetAmount.incoming(
        assetId: assetId,
        amount: Decimal.one,
      );
      final outgoingTwo = AssetAmount.outgoing(
        assetId: assetId,
        amount: Decimal.parse('2'),
      );

      final zeroResult = incomingOne.subtract(incomingOne);
      final positiveResult = incomingOne.subtract(outgoingTwo);

      expect(zeroResult.amount, Decimal.zero);
      expect(zeroResult.direction, AssetAmountDirection.incoming);
      expect(positiveResult.amount, Decimal.parse('3'));
      expect(positiveResult.direction, AssetAmountDirection.incoming);
    });

    test('compares signed amounts for greater-than', () {
      final incomingFour = AssetAmount.incoming(
        assetId: assetId,
        amount: Decimal.parse('4'),
      );
      final incomingTwo = AssetAmount.incoming(
        assetId: assetId,
        amount: Decimal.parse('2'),
      );
      final outgoingOne = AssetAmount.outgoing(
        assetId: assetId,
        amount: Decimal.one,
      );

      expect(incomingFour.isGreaterThan(incomingTwo), isTrue);
      expect(incomingFour.isGreaterThan(outgoingOne), isTrue);
      expect(incomingFour.isGreaterThan(incomingFour), isFalse);
    });

    test('compares signed amounts for less-than', () {
      final incomingFour = AssetAmount.incoming(
        assetId: assetId,
        amount: Decimal.parse('4'),
      );
      final incomingEight = AssetAmount.incoming(
        assetId: assetId,
        amount: Decimal.parse('8'),
      );
      final outgoingOne = AssetAmount.outgoing(
        assetId: assetId,
        amount: Decimal.one,
      );

      expect(incomingFour.isLessThan(incomingEight), isTrue);
      expect(outgoingOne.isLessThan(incomingFour), isTrue);
      expect(incomingFour.isLessThan(incomingFour), isFalse);
    });

    test('compares signed amounts for equality', () {
      final incomingFour = AssetAmount.incoming(
        assetId: assetId,
        amount: Decimal.parse('4'),
      );
      final outgoingFour = AssetAmount.outgoing(
        assetId: assetId,
        amount: Decimal.parse('4'),
      );

      expect(incomingFour.isEqualTo(incomingFour), isTrue);
      expect(outgoingFour.isEqualTo(outgoingFour), isTrue);
      expect(incomingFour.isEqualTo(outgoingFour), isFalse);
    });

    test('rejects different assets for every operation', () {
      final amount = AssetAmount.incoming(
        assetId: assetId,
        amount: Decimal.one,
      );
      final other = AssetAmount.incoming(
        assetId: AssetId.fromString('other-asset'),
        amount: Decimal.one,
      );
      final operations = <Object Function(AssetAmount)>[
        amount.add,
        amount.subtract,
        amount.isGreaterThan,
        amount.isLessThan,
        amount.isEqualTo,
      ];

      for (final operation in operations) {
        expect(() => operation(other), throwsA(isA<ArgumentError>()));
      }
    });

    test('rejects unknown receiver or operand for every operation', () {
      final known = AssetAmount.incoming(assetId: assetId, amount: Decimal.one);
      final unknown = AssetAmount.incoming(
        assetId: assetId,
        amount: Decimal.fromInt(-1),
      );
      final knownOperations = <Object Function(AssetAmount)>[
        known.add,
        known.subtract,
        known.isGreaterThan,
        known.isLessThan,
        known.isEqualTo,
      ];
      final unknownOperations = <Object Function(AssetAmount)>[
        unknown.add,
        unknown.subtract,
        unknown.isGreaterThan,
        unknown.isLessThan,
        unknown.isEqualTo,
      ];

      for (var index = 0; index < knownOperations.length; index++) {
        expect(
          () => knownOperations[index](unknown),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => unknownOperations[index](known),
          throwsA(isA<ArgumentError>()),
        );
      }
    });
  });
}
