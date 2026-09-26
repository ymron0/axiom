import 'package:axiom/src/core/persistence/mapping/persistence_record_exception.dart';
import 'package:axiom/src/core/persistence/persistence_operation_guard.dart';
import 'package:axiom/src/core/persistence/sembast_record_keys.dart';
import 'package:axiom/src/core/persistence/sembast_stores.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/onboarding/domain/entities/onboarding_status.dart';
import 'package:axiom/src/features/onboarding/domain/failures/onboarding_failure.dart';
import 'package:axiom/src/features/onboarding/domain/failures/onboarding_repository_failure.dart';
import 'package:axiom/src/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:sembast/sembast.dart';

/// Stores the singleton onboarding-completion record in Sembast.
///
/// ## Semantics
///
/// A missing record means onboarding is pending.
///
/// Completion is idempotent. Once a completion timestamp exists, subsequent
/// calls return it without replacing it.
///
/// ## Contract
///
/// Expected persistence problems and malformed records are translated to
/// [OnboardingRepositoryFailure].
final class SembastOnboardingRepositoryImpl implements OnboardingRepository {
  static const String _completedAtField = 'completedAtUtcMicros';

  static final _record = SembastStores.onboarding.record(
    SembastRecordKeys.onboarding,
  );

  final Database _database;

  /// Creates a persistent onboarding repository.
  SembastOnboardingRepositoryImpl({required Database database})
    : _database = database; // ignore: prefer_initializing_formals

  @override
  Future<Result<OnboardingStatus, OnboardingFailure>> getStatus() {
    return guardPersistenceOperation<OnboardingStatus, OnboardingFailure>(
      operation: () async {
        final record = await _record.get(_database);

        if (record == null) {
          return const Success(OnboardingStatus.pending());
        }

        return Success(_statusFromRecord(record));
      },
      persistenceFailure: _persistenceFailure,
      failureMessage: 'Unable to read onboarding state.',
    );
  }

  @override
  Future<Result<OnboardingStatus, OnboardingFailure>> complete(
    DateTime completedAt,
  ) {
    return guardPersistenceOperation<OnboardingStatus, OnboardingFailure>(
      operation: () {
        return _database
            .transaction<Result<OnboardingStatus, OnboardingFailure>>((
              transaction,
            ) async {
              final existingRecord = await _record.get(transaction);

              if (existingRecord != null) {
                final existing = _statusFromRecord(existingRecord);

                if (existing.isCompleted) {
                  return Success(existing);
                }
              }

              final status = OnboardingStatus.completed(completedAt);

              await _record.put(transaction, <String, Object?>{
                _completedAtField: status.completedAt!.microsecondsSinceEpoch,
              });

              return Success(status);
            });
      },
      persistenceFailure: _persistenceFailure,
      failureMessage: 'Unable to complete onboarding.',
    );
  }

  OnboardingStatus _statusFromRecord(Map<String, Object?> record) {
    final completedAt = record[_completedAtField];

    if (completedAt is! int) {
      throw const PersistenceRecordException(
        field: _completedAtField,
        reason: 'Expected an integer UTC timestamp.',
      );
    }

    return OnboardingStatus.completed(
      DateTime.fromMicrosecondsSinceEpoch(completedAt, isUtc: true),
    );
  }

  static OnboardingRepositoryFailure _persistenceFailure(String message) {
    return OnboardingRepositoryFailure(message: message);
  }
}
