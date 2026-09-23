import 'dart:convert';

import 'package:axiom/src/core/persistence/mapping/persistence_record.dart';
import 'package:axiom/src/core/persistence/sembast_record_keys.dart';
import 'package:axiom/src/core/persistence/sembast_stores.dart';
import 'package:axiom/src/features/accounts/data/models/account_persistence_model.dart';
import 'package:axiom/src/features/assets/data/models/asset_persistence_model.dart';
import 'package:axiom/src/features/balance_snapshots/data/models/balance_snapshot_persistence_model.dart';
import 'package:axiom/src/features/balance_snapshots/data/models/balance_snapshot_record_key.dart';
import 'package:axiom/src/features/categories/data/models/category_persistence_model.dart';
import 'package:axiom/src/features/custodians/data/models/custodian_persistence_model.dart';
import 'package:axiom/src/features/jars/data/models/jar_persistence_model.dart';
import 'package:axiom/src/features/merchants/data/models/merchant_persistence_model.dart';
import 'package:axiom/src/features/rates/data/models/rate_persistence_model.dart';
import 'package:axiom/src/features/settings/data/models/settings_persistence_model.dart';
import 'package:axiom/src/features/tags/data/models/tag_persistence_model.dart';
import 'package:axiom/src/features/tags/domain/validation/tag_name_normalization.dart';
import 'package:axiom/src/features/transactions/data/models/transaction_persistence_model.dart';
import 'package:axiom/src/features/transactions/data/models/transaction_series_persistence_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sembast/sembast.dart';

typedef _CanonicalizeRecord =
    PersistenceRecord Function(String recordKey, PersistenceRecord record);

typedef _NormalizeRecord =
    void Function(PersistenceRecord record, int index, String path);

/// Loads development fixtures from JSON assets.
///
/// Fixture JSON mirrors the Sembast persistence representation rather than
/// introducing a second fixture-specific Dart object model.
///
/// Collection fixtures contain an array of objects. Each object contains an
/// `id` field used as its Sembast record key. The `id` field itself is not
/// persisted.
///
/// Settings are represented by a single JSON object because settings are a
/// singleton.
///
/// Balance snapshots use their natural subject/date identity and therefore do
/// not require an `id`.
///
/// Every record is parsed through its existing persistence model before it is
/// stored. This validates both persistence structure and current domain
/// invariants.
///
/// ## Contract
///
/// This loader does not clear existing data. Destructive reset behavior belongs
/// to the development reset service.
///
/// Malformed fixture data throws and aborts loading. When this loader is called
/// inside the reset service's Sembast transaction, the complete reset/reload
/// operation therefore rolls back.
final class DevelopmentFixtureLoader {
  final AssetBundle _bundle;

  /// Root asset directory containing fixture JSON files.
  final String fixtureRoot;

  /// Creates a JSON fixture loader.
  DevelopmentFixtureLoader({
    AssetBundle? bundle,
    this.fixtureRoot = 'assets/fixtures',
  }) : _bundle = bundle ?? rootBundle;

  /// Loads every fixture file into [database].
  ///
  /// The order keeps foundational and referenced data ahead of data that
  /// normally depends on it.
  Future<void> load(DatabaseClient database) async {
    await _loadEntityCollection(
      database: database,
      fileName: 'assets.json',
      store: SembastStores.assets,
      canonicalize: (recordKey, record) {
        final model = AssetPersistenceModel.fromRecord(
          recordKey: recordKey,
          record: record,
        );

        model.toEntity();

        return model.toRecord();
      },
    );

    await _loadSettings(database);

    await _loadEntityCollection(
      database: database,
      fileName: 'rates.json',
      store: SembastStores.rates,
      canonicalize: (recordKey, record) {
        final model = RatePersistenceModel.fromRecord(
          recordKey: recordKey,
          record: record,
        );

        model.toEntity();

        return model.toRecord();
      },
    );

    await _loadEntityCollection(
      database: database,
      fileName: 'custodians.json',
      store: SembastStores.custodians,
      canonicalize: (recordKey, record) {
        final model = CustodianPersistenceModel.fromRecord(
          recordKey: recordKey,
          record: record,
        );

        model.toEntity();

        return model.toRecord();
      },
    );

    await _loadEntityCollection(
      database: database,
      fileName: 'accounts.json',
      store: SembastStores.accounts,
      canonicalize: (recordKey, record) {
        final model = AccountPersistenceModel.fromRecord(
          recordKey: recordKey,
          record: record,
        );

        model.toEntity();

        return model.toRecord();
      },
    );

    await _loadEntityCollection(
      database: database,
      fileName: 'merchants.json',
      store: SembastStores.merchants,
      canonicalize: (recordKey, record) {
        final model = MerchantPersistenceModel.fromRecord(
          recordKey: recordKey,
          record: record,
        );

        model.toEntity();

        return model.toRecord();
      },
    );

    await _loadEntityCollection(
      database: database,
      fileName: 'categories.json',
      store: SembastStores.categories,
      canonicalize: (recordKey, record) {
        final model = CategoryPersistenceModel.fromRecord(
          recordKey: recordKey,
          record: record,
        );

        model.toEntity();

        return model.toRecord();
      },
    );

    await _loadEntityCollection(
      database: database,
      fileName: 'jars.json',
      store: SembastStores.jars,
      normalize: _normalizeJar,
      canonicalize: (recordKey, record) {
        final model = JarPersistenceModel.fromRecord(
          recordKey: recordKey,
          record: record,
        );

        model.toEntity();

        return model.toRecord();
      },
    );

    await _loadEntityCollection(
      database: database,
      fileName: 'tags.json',
      store: SembastStores.tags,
      normalize: _normalizeTag,
      canonicalize: (recordKey, record) {
        final model = TagPersistenceModel.fromRecord(
          recordKey: recordKey,
          record: record,
        );

        model.toEntity();

        return model.toRecord();
      },
    );

    await _loadEntityCollection(
      database: database,
      fileName: 'transaction_series.json',
      store: SembastStores.transactionSeries,
      canonicalize: (recordKey, record) {
        final model = TransactionSeriesPersistenceModel.fromRecord(
          recordKey: recordKey,
          record: record,
        );

        model.toEntity();

        return model.toRecord();
      },
    );

    await _loadEntityCollection(
      database: database,
      fileName: 'transactions.json',
      store: SembastStores.transactions,
      normalize: _normalizeTransaction,
      canonicalize: (recordKey, record) {
        final model = TransactionPersistenceModel.fromRecord(recordKey, record);

        model.toEntity();

        return model.toRecord();
      },
    );

    await _loadBalanceSnapshots(database);
  }

  Future<Object?> _decode(String path, {required Object emptyValue}) async {
    final String source;

    try {
      source = await _bundle.loadString(path);
    } on FlutterError {
      return emptyValue;
    }

    try {
      return jsonDecode(source);
    } on FormatException catch (error) {
      throw FormatException('Invalid JSON in $path: ${error.message}');
    }
  }

  Future<void> _loadBalanceSnapshots(DatabaseClient database) async {
    const fileName = 'balance_snapshots.json';
    final path = _path(fileName);
    final decoded = await _decode(path, emptyValue: const <Object?>[]);

    if (decoded is! List) {
      throw FormatException('$path must contain a JSON array.');
    }

    final seenKeys = <String>{};

    for (var index = 0; index < decoded.length; index++) {
      final record = _toRecord(decoded[index], path: path, index: index);

      _normalizeBalanceSnapshot(record, index, path);

      final recordKey = _takeBalanceSnapshotRecordKey(
        record,
        index: index,
        path: path,
      );

      if (!seenKeys.add(recordKey)) {
        throw FormatException(
          '$path contains duplicate balance snapshot '
          'record key "$recordKey".',
        );
      }

      final model = BalanceSnapshotPersistenceModel.fromRecord(
        recordKey: recordKey,
        record: record,
      );

      model.toEntity();

      await SembastStores.balanceSnapshots
          .record(recordKey)
          .put(database, model.toRecord());
    }
  }

  Future<void> _loadEntityCollection({
    required DatabaseClient database,
    required String fileName,
    required StoreRef<String, PersistenceRecord> store,
    required _CanonicalizeRecord canonicalize,
    _NormalizeRecord? normalize,
  }) async {
    final path = _path(fileName);
    final decoded = await _decode(path, emptyValue: const <Object?>[]);

    if (decoded is! List) {
      throw FormatException('$path must contain a JSON array.');
    }

    final seenIds = <String>{};

    for (var index = 0; index < decoded.length; index++) {
      final record = _toRecord(decoded[index], path: path, index: index);

      normalize?.call(record, index, path);

      final id = _removeRequiredString(record, 'id', path: path, index: index);

      if (!seenIds.add(id)) {
        throw FormatException('$path contains duplicate id "$id".');
      }

      final canonicalRecord = canonicalize(id, record);

      await store.record(id).put(database, canonicalRecord);
    }
  }

  Future<void> _loadSettings(DatabaseClient database) async {
    const fileName = 'settings.json';
    final path = _path(fileName);

    final decoded = await _decode(path, emptyValue: const <String, Object?>{});

    if (decoded is! Map) {
      throw FormatException('$path must contain one JSON object.');
    }

    if (decoded.isEmpty) {
      return;
    }

    final record = _toRecord(decoded, path: path);

    record.remove('id');

    final model = SettingsPersistenceModel.fromRecord(record);

    model.toEntity();

    await SembastStores.settings
        .record(SembastRecordKeys.settings)
        .put(database, model.toRecord());
  }

  String _path(String fileName) {
    final root = fixtureRoot.endsWith('/')
        ? fixtureRoot.substring(0, fixtureRoot.length - 1)
        : fixtureRoot;

    return '$root/$fileName';
  }

  static BalanceSnapshotRecordKey _balanceSnapshotKey(
    PersistenceRecord record, {
    required int index,
    required String path,
  }) {
    final explicitRecordKey = record['recordKey'];

    if (explicitRecordKey != null) {
      if (explicitRecordKey is! String || explicitRecordKey.trim().isEmpty) {
        throw FormatException(
          '$path[$index].recordKey must be a non-empty string.',
        );
      }

      return BalanceSnapshotRecordKey.parse(explicitRecordKey);
    }

    final subjectType = _requiredString(
      record,
      BalanceSnapshotPersistenceModel.subjectTypeField,
      path: path,
      index: index,
    );

    final subjectId = _requiredString(
      record,
      BalanceSnapshotPersistenceModel.subjectIdField,
      path: path,
      index: index,
    );

    final snapshotDate = _requiredString(
      record,
      BalanceSnapshotPersistenceModel.snapshotDateField,
      path: path,
      index: index,
    );

    final encodedId = Uri.encodeComponent(subjectId);

    return BalanceSnapshotRecordKey.parse(
      '$subjectType|$encodedId|$snapshotDate',
    );
  }

  static void _normalizeBalanceSnapshot(
    PersistenceRecord record,
    int index,
    String path,
  ) {
    _normalizeBalanceSnapshotSubject(record, index: index, path: path);

    final key = _balanceSnapshotKey(record, index: index, path: path);

    record.putIfAbsent(
      BalanceSnapshotPersistenceModel.recordVersionField,
      () => BalanceSnapshotPersistenceModel.currentRecordVersion,
    );

    record.putIfAbsent(
      BalanceSnapshotPersistenceModel.subjectKeyField,
      () => key.subjectKey,
    );

    record.putIfAbsent(
      BalanceSnapshotPersistenceModel.snapshotDateEpochDayField,
      () =>
          key.snapshotDate.toDateTimeUtc().millisecondsSinceEpoch ~/
          Duration.millisecondsPerDay,
    );
  }

  static void _normalizeBalanceSnapshotSubject(
    PersistenceRecord record, {
    required int index,
    required String path,
  }) {
    final subjectValue = record.remove('subject');

    if (subjectValue == null) {
      return;
    }

    if (subjectValue is! Map) {
      throw FormatException('$path[$index].subject must be a JSON object.');
    }

    final subject = Map<String, Object?>.from(subjectValue);

    final accountId = subject['accountId'];
    final custodianId = subject['custodianId'];
    final jarId = subject['jarId'];

    final presentSubjects = <({String type, Object? id})>[
      if (accountId != null)
        (type: BalanceSnapshotRecordKey.accountType, id: accountId),
      if (custodianId != null)
        (type: BalanceSnapshotRecordKey.custodianType, id: custodianId),
      if (jarId != null) (type: BalanceSnapshotRecordKey.jarType, id: jarId),
    ];

    if (presentSubjects.length != 1) {
      throw FormatException(
        '$path[$index].subject must contain exactly one of '
        'accountId, custodianId, or jarId.',
      );
    }

    final selected = presentSubjects.single;

    if (selected.id is! String || (selected.id! as String).trim().isEmpty) {
      throw FormatException(
        '$path[$index].subject contains an invalid subject ID.',
      );
    }

    record[BalanceSnapshotPersistenceModel.subjectTypeField] = selected.type;

    record[BalanceSnapshotPersistenceModel.subjectIdField] = selected.id;
  }

  static void _normalizeJar(PersistenceRecord record, int index, String path) {
    final rawTargets = record['targets'];

    if (rawTargets is! List) {
      return;
    }

    for (var targetIndex = 0; targetIndex < rawTargets.length; targetIndex++) {
      final rawTarget = rawTargets[targetIndex];

      if (rawTarget is! Map) {
        continue;
      }

      final target = Map<String, Object?>.from(rawTarget);

      final rawAmount = target['amount'];

      if (rawAmount is! Map) {
        continue;
      }

      final amount = Map<String, Object?>.from(rawAmount);

      // Fixture JSON consistently uses "amount" for monetary quantities.
      //
      // JarTargetAmountPersistenceModel historically persists this particular
      // quantity under "value", so translate it at the fixture boundary.
      if (!amount.containsKey('value') && amount.containsKey('amount')) {
        amount['value'] = amount.remove('amount');
      }

      target['amount'] = amount;
      rawTargets[targetIndex] = target;
    }
  }

  static void _normalizeTag(PersistenceRecord record, int index, String path) {
    if (record.containsKey(TagPersistenceModel.nameKeyField)) {
      return;
    }

    final name = _requiredString(
      record,
      TagPersistenceModel.nameField,
      path: path,
      index: index,
    );

    record[TagPersistenceModel.nameKeyField] = tagNameKey(name);
  }

  static void _normalizeTransaction(
    PersistenceRecord record,
    int index,
    String path,
  ) {
    record.putIfAbsent(
      TransactionPersistenceModel.persistenceOrderField,
      () => index + 1,
    );
  }

  static String _removeRequiredString(
    PersistenceRecord record,
    String field, {
    required String path,
    required int index,
  }) {
    final value = record.remove(field);

    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$path[$index].$field must be a non-empty string.');
    }

    return value;
  }

  static String _requiredString(
    PersistenceRecord record,
    String field, {
    required String path,
    required int index,
  }) {
    final value = record[field];

    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$path[$index].$field must be a non-empty string.');
    }

    return value;
  }

  static String _takeBalanceSnapshotRecordKey(
    PersistenceRecord record, {
    required int index,
    required String path,
  }) {
    final explicitRecordKey = record.remove('recordKey');

    if (explicitRecordKey != null) {
      if (explicitRecordKey is! String || explicitRecordKey.trim().isEmpty) {
        throw FormatException(
          '$path[$index].recordKey must be a non-empty string.',
        );
      }

      return BalanceSnapshotRecordKey.parse(explicitRecordKey).value;
    }

    return _balanceSnapshotKey(record, index: index, path: path).value;
  }

  static PersistenceRecord _toRecord(
    Object? value, {
    required String path,
    int? index,
  }) {
    if (value is! Map) {
      final location = index == null ? path : '$path[$index]';

      throw FormatException('$location must contain a JSON object.');
    }

    final result = <String, Object?>{};

    for (final entry in value.entries) {
      final key = entry.key;

      if (key is! String) {
        final location = index == null ? path : '$path[$index]';

        throw FormatException(
          '$location contains a non-string JSON object key.',
        );
      }

      result[key] = entry.value;
    }

    return result;
  }
}
