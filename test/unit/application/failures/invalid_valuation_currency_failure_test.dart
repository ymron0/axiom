import 'package:axiom/src/application/failures/invalid_valuation_currency_failure.dart';
import 'package:test/test.dart';

void main() {
  group('InvalidValuationCurrencyFailure', () {
    test('returns its static type identifier from type', () {
      // Given
      const failure = InvalidValuationCurrencyFailure(message: 'Reason');

      // Then
      expect(failure.type, InvalidValuationCurrencyFailure.typeId);
    });
  });
}
