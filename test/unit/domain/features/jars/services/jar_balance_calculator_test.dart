@Tags(['domain'])
library;

import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/jars/domain/services/jar_balance_calculator.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

void main() {
  group('JarBalanceCalculator', () {
    const calculator = JarBalanceCalculator();

    final chf = AssetId.fromString('currency-chf');
    final eur = AssetId.fromString('currency-eur');

    AssetAmount incoming(String amount) {
      return AssetAmount.incoming(
        assetId: chf,
        amount: Decimal.parse(amount),
      );
    }

    AssetAmount outgoing(String amount) {
      return AssetAmount.outgoing(
        assetId: chf,
        amount: Decimal.parse(amount),
      );
    }

    AssetAmount calculate(Iterable<AssetAmount> allocations) {
      return calculator.calculate(
        valuationCurrencyId: chf,
        allocationAmounts: allocations,
      );
    }

    test('returns canonical incoming zero when there are no allocations', () {
      // When
      final result = calculate(const []);

      // Then
      expect(result.assetId, chf);
      expect(result.amount, Decimal.zero);
      expect(result.isIncoming, isTrue);
      expect(result.isOutgoing, isFalse);
    });

    test('adds incoming allocations', () {
      // Given
      final allocations = [
        incoming('500'),
        incoming('250.50'),
      ];

      // When
      final result = calculate(allocations);

      // Then
      expect(result.assetId, chf);
      expect(result.amount, Decimal.parse('750.50'));
      expect(result.isIncoming, isTrue);
    });

    test('subtracts outgoing allocations', () {
      // Given
      final allocations = [
        incoming('1000'),
        outgoing('300'),
      ];

      // When
      final result = calculate(allocations);

      // Then
      expect(result.assetId, chf);
      expect(result.amount, Decimal.parse('700'));
      expect(result.isIncoming, isTrue);
    });

    test('can produce an outgoing balance', () {
      // Given
      final allocations = [
        incoming('200'),
        outgoing('500'),
      ];

      // When
      final result = calculate(allocations);

      // Then
      expect(result.assetId, chf);
      expect(result.amount, Decimal.parse('300'));
      expect(result.isOutgoing, isTrue);
      expect(result.isIncoming, isFalse);
    });

    test(
      'represents cancelling allocations as canonical incoming zero',
      () {
        // Given
        final allocations = [
          incoming('500'),
          outgoing('500'),
        ];

        // When
        final result = calculate(allocations);

        // Then
        expect(result.assetId, chf);
        expect(result.amount, Decimal.zero);
        expect(result.isIncoming, isTrue);
        expect(result.isOutgoing, isFalse);
      },
    );

    test(
      'represents cancelling allocations identically when order is reversed',
      () {
        // Given
        final incomingAllocation = incoming('500');
        final outgoingAllocation = outgoing('500');

        // When
        final forward = calculate([
          incomingAllocation,
          outgoingAllocation,
        ]);

        final reversed = calculate([
          outgoingAllocation,
          incomingAllocation,
        ]);

        // Then
        expect(forward.assetId, chf);
        expect(forward.amount, Decimal.zero);
        expect(forward.isIncoming, isTrue);

        expect(reversed.assetId, chf);
        expect(reversed.amount, Decimal.zero);
        expect(reversed.isIncoming, isTrue);

        expect(reversed, forward);
      },
    );

    test('preserves exact decimal precision', () {
      // Given
      final allocations = [
        incoming('0.1'),
        incoming('0.2'),
        outgoing('0.15'),
      ];

      // When
      final result = calculate(allocations);

      // Then
      expect(result.amount, Decimal.parse('0.15'));
      expect(result.isIncoming, isTrue);
    });

    test('cancels decimal fractions exactly without floating-point drift', () {
      // Given
      final allocations = [
        incoming('0.1'),
        incoming('0.2'),
        outgoing('0.3'),
      ];

      // When
      final result = calculate(allocations);

      // Then
      expect(result.amount, Decimal.zero);
      expect(result.isIncoming, isTrue);
    });

    test('preserves arbitrary decimal precision without rounding', () {
      // Given
      final allocations = [
        incoming('123456789.123456789'),
        outgoing('0.000000001'),
      ];

      // When
      final result = calculate(allocations);

      // Then
      expect(
        result.amount,
        Decimal.parse('123456789.123456788'),
      );
      expect(result.isIncoming, isTrue);
    });

    test('rejects allocations using another currency', () {
      // Given
      final allocation = AssetAmount.incoming(
        assetId: eur,
        amount: Decimal.parse('100'),
      );

      // Then
      expect(
        () => calculate([allocation]),
        throwsA(
          isA<ArgumentError>()
              .having(
                (error) => error.name,
                'name',
                'allocationAmounts',
              ),
        ),
      );
    });

    test('rejects unknown allocation amounts', () {
      // Given
      final allocation = AssetAmount.incoming(
        assetId: chf,
        amount: Decimal.fromInt(-1),
      );

      // Then
      expect(
        () => calculate([allocation]),
        throwsA(
          isA<ArgumentError>()
              .having(
                (error) => error.name,
                'name',
                'allocationAmounts',
              ),
        ),
      );
    });

    test('produces the same positive balance regardless of allocation order', () {
      // Given
      final first = incoming('100.25');
      final second = outgoing('20.10');
      final third = incoming('5.35');

      // When
      final forward = calculate([
        first,
        second,
        third,
      ]);

      final reversed = calculate([
        third,
        second,
        first,
      ]);

      // Then
      expect(forward.amount, Decimal.parse('85.50'));
      expect(forward.isIncoming, isTrue);

      expect(reversed, forward);
    });

    test('produces the same negative balance regardless of allocation order', () {
      // Given
      final first = incoming('25.25');
      final second = outgoing('100.50');
      final third = incoming('5.25');

      // When
      final forward = calculate([
        first,
        second,
        third,
      ]);

      final reversed = calculate([
        third,
        second,
        first,
      ]);

      // Then
      expect(forward.amount, Decimal.parse('70.00'));
      expect(forward.isOutgoing, isTrue);

      expect(reversed, forward);
    });

    test('zero-valued allocations do not change the result', () {
      // Given
      final allocations = [
        incoming('50'),
        incoming('0'),
        outgoing('0'),
        outgoing('20'),
      ];

      // When
      final result = calculate(allocations);

      // Then
      expect(result.amount, Decimal.parse('30'));
      expect(result.isIncoming, isTrue);
    });
  });
}