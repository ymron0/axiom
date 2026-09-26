import 'dart:io';

import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_exception.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:sembast/sembast_io.dart';

/// Executes a persistence operation and translates expected persistence
/// exceptions into a feature-specific failure result.
///
/// [F] represents the failure contract exposed by the caller, such as
/// `AssetFailure`. The concrete failure returned by [persistenceFailure] may
/// be a subtype implementing that contract.
///
/// Programmer errors and unexpected exceptions are deliberately allowed to
/// propagate rather than being disguised as persistence failures.
Future<Result<T, F>>
guardPersistenceOperation<T extends Object?, F extends BaseFailure>({
  required Future<Result<T, F>> Function() operation,
  required Result<T, F> Function(String message) persistenceFailure,
  required String failureMessage,
}) async {
  try {
    return await operation();
  } on PersistenceRecordException {
    return persistenceFailure(
      'Persisted data is invalid or cannot be reconstructed.',
    );
  } on FileSystemException {
    return persistenceFailure(failureMessage);
  } on DatabaseException {
    return persistenceFailure(failureMessage);
  }
}

/// Watches a persistence operation and translates expected persistence
/// exceptions into feature-specific failure results.
///
/// The stream remains strongly typed: expected persistence problems are emitted
/// as [Result] failures rather than exposed as stream errors.
///
/// Programmer errors and unexpected exceptions deliberately propagate.
Stream<Result<T, F>>
guardPersistenceStream<T extends Object?, F extends BaseFailure>({
  required Stream<Result<T, F>> Function() operation,
  required Result<T, F> Function(String message) persistenceFailure,
  required String failureMessage,
}) async* {
  try {
    await for (final result in operation()) {
      yield result;
    }
  } on PersistenceRecordException {
    yield persistenceFailure(
      'Persisted data is invalid or cannot be reconstructed.',
    );
  } on FileSystemException {
    yield persistenceFailure(failureMessage);
  } on DatabaseException {
    yield persistenceFailure(failureMessage);
  }
}
