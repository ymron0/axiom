import 'package:axiom/src/core/result/result.dart';
import 'package:test/test.dart';

void main() {
  group('Success', () {
    group('construction', () {
      test('preserves the provided value', () {
        // Given
        final value = Object();

        // When
        final success = Success(value);

        // Then
        expect(success.value, same(value));
      });
    });

    group('state', () {
      test('exposes only the successful value', () {
        // Given
        final value = Object();
        final success = Success(value);

        // When
        final successValue = success.valueOrNull;
        final failureValue = success.failureOrNull;

        // Then
        expect(success.isSuccess, isTrue);
        expect(success.isFailure, isFalse);
        expect(successValue, same(value));
        expect(failureValue, isNull);
      });
    });

    group('when', () {
      test('invokes the success callback with the wrapped value', () {
        // Given
        final value = Object();
        final success = Success(value);

        // When
        final selectedValue = success.when<Object>(
          success: (value) => value,
          failure: (_) => throw StateError('Unexpected failure callback.'),
        );

        // Then
        expect(selectedValue, same(value));
      });
    });
  });
}
