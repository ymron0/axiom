import 'package:axiom/src/features/rates/application/failures/unsupported_persisted_rate_quote_failure.dart';
import 'package:test/test.dart';

void main() {
  group('UnsupportedPersistedRateQuoteFailure', () {
    test('returns its static type identifier from type', () {
      // Given
      const failure = UnsupportedPersistedRateQuoteFailure(message: 'Reason');

      // Then
      expect(failure.type, UnsupportedPersistedRateQuoteFailure.typeId);
    });
  });
}
