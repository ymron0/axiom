import 'package:axiom/src/core/persistence/persistence_operation_guard.dart';
import 'package:axiom/src/core/persistence/sembast_record_keys.dart';
import 'package:axiom/src/core/persistence/sembast_stores.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/settings/data/models/settings_persistence_model.dart';
import 'package:axiom/src/features/settings/domain/entities/settings.dart';
import 'package:axiom/src/features/settings/domain/failures/settings_already_initialized_failure.dart';
import 'package:axiom/src/features/settings/domain/failures/settings_failure.dart';
import 'package:axiom/src/features/settings/domain/failures/settings_not_initialized_failure.dart';
import 'package:axiom/src/features/settings/domain/failures/settings_repository_failure.dart';
import 'package:axiom/src/features/settings/domain/repositories/settings_repository.dart';
import 'package:sembast/sembast.dart';

/// Stores the application's singleton settings record in Sembast.
///
/// This repository implements the storage-independent [SettingsRepository]
/// contract while keeping all Sembast-specific behavior inside the Data
/// layer.
///
/// Exactly one settings record may exist. Its storage identity is the stable
/// [SembastRecordKeys.settings] key in [SembastStores.settings].
///
/// ## Failure semantics
///
/// - [get] returns a successful `null` value when settings have not yet been
///   initialized.
/// - [create] returns [SettingsAlreadyInitializedFailure] when the singleton
///   record already exists.
/// - [update] returns [SettingsNotInitializedFailure] when the singleton record
///   does not exist.
/// - persistence access and malformed-record failures are translated into
///   [SettingsRepositoryFailure].
///
/// Unexpected programmer errors are intentionally allowed to propagate.
///
/// ## Atomicity
///
/// [create] and [update] perform their existence check and write inside the
/// same Sembast transaction. This prevents a check-then-write race from
/// violating the singleton settings invariant.
final class SembastSettingsRepositoryImpl implements SettingsRepository {
  /// Canonical Sembast reference for the application's singleton settings
  /// record.
  ///
  /// Store and record names are centralized in the core persistence
  /// infrastructure and must never be redeclared as local string literals.
  static final _settingsRecord = SembastStores.settings.record(
    SembastRecordKeys.settings,
  );

  final Database _database;

  /// Creates a persistent settings repository backed by [database].
  ///
  /// Database lifecycle ownership remains outside this repository. The caller
  /// is responsible for supplying the open database instance.
  SembastSettingsRepositoryImpl({required Database database})
    : _database = database; // ignore: prefer_initializing_formals

  @override
  Future<Result<Settings, SettingsFailure>> create(Settings settings) =>
      guardPersistenceOperation<Settings, SettingsFailure>(
        operation: () =>
            _database.transaction<Result<Settings, SettingsFailure>>((
              transaction,
            ) async {
              final existingRecord = await _settingsRecord.get(transaction);

              if (existingRecord != null) {
                return const SettingsAlreadyInitializedFailure(
                  message: 'Settings have already been initialized.',
                );
              }

              final model = SettingsPersistenceModel.fromEntity(settings);

              await _settingsRecord.put(transaction, model.toRecord());

              return Success<Settings>(settings);
            }),
        persistenceFailure: _persistenceFailure,
        failureMessage: 'Unable to create settings in persistent storage.',
      );

  @override
  Future<Result<Settings?, SettingsFailure>> get() =>
      guardPersistenceOperation<Settings?, SettingsFailure>(
        operation: () async {
          final record = await _settingsRecord.get(_database);

          if (record == null) {
            return const Success<Settings?>(null);
          }

          return Success<Settings?>(_settingsFromRecord(record));
        },
        persistenceFailure: _persistenceFailure,
        failureMessage: 'Unable to read settings from persistent storage.',
      );

  @override
  Future<Result<Settings, SettingsFailure>> update(Settings settings) =>
      guardPersistenceOperation<Settings, SettingsFailure>(
        operation: () =>
            _database.transaction<Result<Settings, SettingsFailure>>((
              transaction,
            ) async {
              final existingRecord = await _settingsRecord.get(transaction);

              if (existingRecord == null) {
                return const SettingsNotInitializedFailure(
                  message: 'Settings have not been initialized.',
                );
              }

              final model = SettingsPersistenceModel.fromEntity(settings);

              await _settingsRecord.put(transaction, model.toRecord());

              return Success<Settings>(settings);
            }),
        persistenceFailure: _persistenceFailure,
        failureMessage: 'Unable to update settings in persistent storage.',
      );

  /// Reconstructs immutable domain settings from a persisted Sembast record.
  ///
  /// Malformed persistence data results in [PersistenceRecordException] from
  /// the persistence model. [guardPersistenceOperation] translates that
  /// exception into [SettingsRepositoryFailure] before it can escape this
  /// repository.
  Settings _settingsFromRecord(Map<String, Object?> record) {
    return SettingsPersistenceModel.fromRecord(record).toEntity();
  }

  /// Creates the feature-specific failure used for expected persistence
  /// infrastructure problems.
  static SettingsRepositoryFailure _persistenceFailure(String message) {
    return SettingsRepositoryFailure(message: message);
  }
}
