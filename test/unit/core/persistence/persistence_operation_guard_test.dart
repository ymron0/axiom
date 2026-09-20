@Tags(['core', 'data', 'persistence'])
library;

import 'dart:io';

import 'package:axiom/src/core/persistence/mapping/persistence_record_exception.dart';
import 'package:axiom/src/core/persistence/persistence_operation_guard.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:sembast/sembast_io.dart';
import 'package:test/test.dart' hide TestFailure;

import '../../../fixtures/core/result/test_failure.dart';

void main() {
  group('guardPersistenceOperation', () {
    test('returns the operation result unchanged when it succeeds', () async {
      const expected = Success<String>('saved');

      final result = await guardPersistenceOperation<String, TestFailure>(
        operation: () async => expected,
        persistenceFailure: (message) => TestFailure(message: message),
        failureMessage: 'Persistence failed.',
      );

      expect(result, same(expected));
    });

    test(
      'returns the operation result unchanged when it returns a failure',
      () async {
        const expected = TestFailure(message: 'already failed');

        final result = await guardPersistenceOperation<String, TestFailure>(
          operation: () async => expected,
          persistenceFailure: (message) => TestFailure(message: message),
          failureMessage: 'Persistence failed.',
        );

        expect(result, same(expected));
      },
    );

    test(
      'translates PersistenceRecordException to the fixed message',
      () async {
        final result = await guardPersistenceOperation<String, TestFailure>(
          operation: () async {
            throw const PersistenceRecordException(reason: 'invalid record');
          },
          persistenceFailure: (message) => TestFailure(message: message),
          failureMessage: 'Persistence failed.',
        );

        expect(
          result.failureOrNull?.message,
          'Persisted data is invalid or cannot be reconstructed.',
        );
      },
    );

    for (final exception in <Object>[
      const FileSystemException('write failed'),
      DatabaseException.closed('database is closed'),
    ]) {
      test(
        'translates ${exception.runtimeType} to the supplied message',
        () async {
          final result = await guardPersistenceOperation<String, TestFailure>(
            operation: () async => throw exception,
            persistenceFailure: (message) => TestFailure(message: message),
            failureMessage: 'Write failed.',
          );

          expect(result.failureOrNull?.message, 'Write failed.');
        },
      );
    }

    test('propagates unexpected exceptions', () async {
      await expectLater(
        guardPersistenceOperation<String, TestFailure>(
          operation: () async => throw StateError('unexpected'),
          persistenceFailure: (message) => TestFailure(message: message),
          failureMessage: 'Persistence failed.',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}
