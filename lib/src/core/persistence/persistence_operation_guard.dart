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
