import 'dart:io';

import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:dart_mappable/dart_mappable.dart';
import 'package:sembast/sembast.dart' hide Field;

import 'sembast_stores.dart';

part 'application_data_service.mapper.dart';

/// Typed failure boundary for application-level persistence management.
abstract interface class ApplicationDataFailure implements BaseFailure {}

/// Indicates that an application-data operation could not complete.
@MappableClass()
final class ApplicationDataOperationFailure
    extends Failure<ApplicationDataOperationFailure>
    with ApplicationDataOperationFailureMappable
    implements ApplicationDataFailure {
  /// Creates an application-data operation failure.
  const ApplicationDataOperationFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'persistence.applicationDataOperation';

  @override
  ApplicationDataOperationFailure get failureOrNull => this;

  @override
  String get type => typeId;
}

/// Record counts for application-owned persistence.
final class ApplicationDataSummary {
  /// Creates an immutable data summary.
  ApplicationDataSummary({
    required Map<String, int> resettableCounts,
    required Map<String, int> referenceDataCounts,
  }) : resettableCounts = Map.unmodifiable(resettableCounts),
       referenceDataCounts = Map.unmodifiable(referenceDataCounts);

  /// User/application data removed during reset.
  final Map<String, int> resettableCounts;

  /// Reference data retained during reset.
  final Map<String, int> referenceDataCounts;

  /// Total resettable records.
  int get resettableTotal =>
      resettableCounts.values.fold(0, (sum, value) => sum + value);

  /// Total reference records.
  int get referenceDataTotal =>
      referenceDataCounts.values.fold(0, (sum, value) => sum + value);

  /// Total application-owned records.
  int get totalRecords => resettableTotal + referenceDataTotal;
}

/// Reads application-level persistence diagnostics.
final class GetApplicationDataSummaryService {
  /// Creates the service.
  const GetApplicationDataSummaryService({required Database database})
    : _database = database; // ignore: prefer_initializing_formals

  final Database _database;

  /// Counts application records grouped by reset semantics.
  Future<Result<ApplicationDataSummary, ApplicationDataFailure>> call() async {
    try {
      final resettableCounts = <String, int>{};
      final referenceCounts = <String, int>{};

      for (var index = 0; index < SembastStores.resettable.length; index++) {
        final store = SembastStores.resettable[index];
        final name = SembastStores.resettableNames[index];

        resettableCounts[name] = await store.count(_database);
      }

      for (var index = 0; index < SembastStores.referenceData.length; index++) {
        final store = SembastStores.referenceData[index];
        final name = SembastStores.referenceDataNames[index];

        referenceCounts[name] = await store.count(_database);
      }

      return Success(
        ApplicationDataSummary(
          resettableCounts: resettableCounts,
          referenceDataCounts: referenceCounts,
        ),
      );
    } on FileSystemException {
      return const ApplicationDataOperationFailure(
        message: 'Unable to inspect application data.',
      );
    } on DatabaseException {
      return const ApplicationDataOperationFailure(
        message: 'Unable to inspect application data.',
      );
    }
  }
}

/// Atomically resets user financial data.
///
/// ## Semantics
///
/// The reset removes:
///
/// - Settings;
/// - merchants;
/// - transactions and transaction series;
/// - accounts and custodians;
/// - categories and jars;
/// - tags;
/// - balance snapshots.
///
/// Assets and rates are deliberately retained. Their stable identities allow
/// the user to select a new valuation currency immediately after reset.
///
/// ## Contract
///
/// All resettable stores are cleared in one Sembast transaction. A persistence
/// failure rolls the transaction back.
final class ResetApplicationService {
  /// Creates the reset service.
  const ResetApplicationService({required Database database})
    : _database = database; // ignore: prefer_initializing_formals

  final Database _database;

  /// Clears resettable application data atomically.
  Future<Result<void, ApplicationDataFailure>> call() async {
    try {
      await _database.transaction((transaction) async {
        for (final store in SembastStores.resettable) {
          await store.delete(transaction);
        }
      });

      return const Success<void>(null);
    } on FileSystemException {
      return const ApplicationDataOperationFailure(
        message: 'Unable to reset application data.',
      );
    } on DatabaseException {
      return const ApplicationDataOperationFailure(
        message: 'Unable to reset application data.',
      );
    }
  }
}
