import 'package:test/test.dart' hide TestFailure;

import '../../../fixtures/core/result/test_failure.dart';

void main() {
  group('Failure', () {
    group('construction', () {
      test('preserves the provided message', () {
        // Given
        const message = 'Operation failed.';

        // When
        const failure = TestFailure(message: message);

        // Then
        expect(failure.message, message);
      });
    });

    group('state', () {
      test('exposes only the failure value', () {
        // Given
        const failure = TestFailure();

        // When
        final failureValue = failure.failureOrNull;
        final successValue = failure.valueOrNull;

        // Then
        expect(failure.isFailure, isTrue);
        expect(failure.isSuccess, isFalse);
        expect(failureValue, same(failure));
        expect(successValue, isNull);
      });

      test('retains stable failure information', () {
        // Given
        const failure = TestFailure(message: 'Operation failed.');

        // When
        final failureValue = failure.failureOrNull;

        // Then
        expect(failure.type, TestFailure.typeId);
        expect(failure.message, 'Operation failed.');
        expect(failureValue, same(failure));
      });
    });

    group('equality', () {
      test('compares failures with equal state as equal', () {
        // Given
        const first = TestFailure(message: 'Operation failed.');
        const second = TestFailure(message: 'Operation failed.');

        // Then
        expect(first, equals(second));
      });

      test('distinguishes failures with different state', () {
        // Given
        const first = TestFailure(message: 'Operation failed.');
        const second = TestFailure(message: 'Permission denied.');

        // Then
        expect(first, isNot(equals(second)));
      });
    });

    group('when', () {
      test('invokes the failure callback with itself', () {
        // Given
        const failure = TestFailure();

        // When
        final selectedFailure = failure.when(
          success: (_) => throw StateError('Unexpected success callback.'),
          failure: (value) => value,
        );

        // Then
        expect(selectedFailure, same(failure));
      });
    });
  });
}
