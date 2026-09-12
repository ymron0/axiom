import 'package:axiom/src/features/rates/domain/failures/rate_not_found_failure.dart';
import 'package:test/test.dart';

void main() {
  group('RateNotFoundFailure', () {
    // Invoke constructors at runtime so coverage records their execution.
    final createFailure = RateNotFoundFailure.new;

    test('can be instantiated without a diagnostic message', () {
      // Given
      final failure = createFailure();

      // Then
      expect(failure.message, isNull);
    });

    test('preserves the provided diagnostic message', () {
      // Given
      const message = 'The requested rate was not found.';

      // When
      final failure = createFailure(message: message);

      // Then
      expect(failure.message, message);
    });

    test('returns its static type identifier from type', () {
      // Given
      const failure = RateNotFoundFailure();

      // Then
      expect(failure.type, RateNotFoundFailure.typeId);
    });

    test('returns itself from failureOrNull', () {
      // Given
      const failure = RateNotFoundFailure();

      // Then
      expect(failure.failureOrNull, same(failure));
    });
  });
}
