import 'package:axiom/src/core/domain/mappers/decimal_mapper.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

void main() {
  group('DecimalMapper', () {
    const mapper = DecimalMapper();

    group('encode', () {
      test('serializes a decimal as its exact string representation', () {
        final value = Decimal.parse('123456789.0123456789');

        final encoded = mapper.encode(value);

        expect(encoded, '123456789.0123456789');
      });
    });

    group('decode', () {
      test('reconstructs a decimal from its string representation', () {
        final decoded = mapper.decode('123456789.0123456789');

        expect(decoded, Decimal.parse('123456789.0123456789'));
      });

      test('throws FormatException for an invalid decimal string', () {
        expect(
          () => mapper.decode('not-a-decimal'),
          throwsA(isA<FormatException>()),
        );
      });
    });
  });
}
