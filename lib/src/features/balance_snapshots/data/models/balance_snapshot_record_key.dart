import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/custodian_id.dart';
import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_exception.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_helpers.dart';
import 'package:axiom/src/features/balance_snapshots/domain/value_objects/balance_snapshot_subject.dart';

/// Stable Sembast record key for one daily balance snapshot.
///
/// ## Natural identity
///
/// A balance snapshot is uniquely identified by:
///
/// ```text
/// subject type + subject ID + snapshot date
/// ```
///
/// The serialized key therefore has the form:
///
/// ```text
/// account|<encoded-id>|2026-09-19
/// custodian|<encoded-id>|2026-09-19
/// jar|<encoded-id>|2026-09-19
/// ```
///
/// Subject IDs are URI-component encoded so an ID containing the separator
/// cannot corrupt the key structure.
///
/// ## Record-version independence
///
/// The persistence-record schema version is deliberately not included in this
/// key.
///
/// Future payload migrations must preserve the same natural key. Changing the
/// record schema must not create a second logical snapshot for the same
/// subject and date.
///
/// ## Historical lookup
///
/// [subjectKey] contains only the subject portion:
///
/// ```text
/// account|<encoded-id>
/// ```
///
/// Snapshot records persist this value separately to support efficient
/// subject-scoped queries without reparsing record keys.
final class BalanceSnapshotRecordKey {
  /// Serialized subject type for account snapshots.
  static const String accountType = 'account';

  /// Serialized subject type for custodian snapshots.
  static const String custodianType = 'custodian';

  /// Serialized subject type for jar snapshots.
  static const String jarType = 'jar';

  static const String _separator = '|';

  /// Stable serialized subject-type discriminator.
  final String subjectType;

  /// Raw domain subject identifier.
  final String subjectId;

  /// Calendar date represented by the snapshot.
  final CalendarDate snapshotDate;

  /// Creates a validated key from already serialized subject components.
  factory BalanceSnapshotRecordKey.fromParts({
    required String subjectType,
    required String subjectId,
    required CalendarDate snapshotDate,
  }) {
    _validateSubjectType(subjectType);

    if (subjectId.trim().isEmpty) {
      throw const PersistenceRecordException(
        field: 'recordKey',
        reason: 'Snapshot subject ID cannot be blank.',
      );
    }

    return BalanceSnapshotRecordKey._(
      subjectType: subjectType,
      subjectId: subjectId,
      snapshotDate: snapshotDate,
    );
  }

  /// Creates the key for [subject] on [snapshotDate].
  factory BalanceSnapshotRecordKey.fromSubject({
    required BalanceSnapshotSubject subject,
    required CalendarDate snapshotDate,
  }) {
    final accountId = subject.accountId;

    if (accountId != null) {
      return BalanceSnapshotRecordKey._(
        subjectType: accountType,
        subjectId: accountId.value,
        snapshotDate: snapshotDate,
      );
    }

    final custodianId = subject.custodianId;

    if (custodianId != null) {
      return BalanceSnapshotRecordKey._(
        subjectType: custodianType,
        subjectId: custodianId.value,
        snapshotDate: snapshotDate,
      );
    }

    final jarId = subject.jarId;

    if (jarId != null) {
      return BalanceSnapshotRecordKey._(
        subjectType: jarType,
        subjectId: jarId.value,
        snapshotDate: snapshotDate,
      );
    }

    throw const PersistenceRecordException(
      field: 'recordKey',
      reason: 'Snapshot subject type is not supported.',
    );
  }

  /// Parses and validates a persisted Sembast [value].
  ///
  /// Throws [PersistenceRecordException] when the key is malformed, contains
  /// an unsupported subject type, contains a blank subject identity, or
  /// contains an invalid calendar date.
  factory BalanceSnapshotRecordKey.parse(String value) {
    final parts = value.split(_separator);

    if (parts.length != 3) {
      throw const PersistenceRecordException(
        field: 'recordKey',
        reason:
            'Expected snapshot record key to contain subject type, subject ID, '
            'and snapshot date.',
      );
    }

    final subjectType = parts[0];

    _validateSubjectType(subjectType);

    final String subjectId;

    try {
      subjectId = Uri.decodeComponent(parts[1]);
    } on ArgumentError {
      throw const PersistenceRecordException(
        field: 'recordKey',
        reason: 'Snapshot record key contains an invalid encoded subject ID.',
      );
    }

    if (subjectId.trim().isEmpty) {
      throw const PersistenceRecordException(
        field: 'recordKey',
        reason: 'Snapshot subject ID cannot be blank.',
      );
    }

    final snapshotDate = readCalendarDate(parts[2], field: 'recordKey');

    return BalanceSnapshotRecordKey._(
      subjectType: subjectType,
      subjectId: subjectId,
      snapshotDate: snapshotDate,
    );
  }

  const BalanceSnapshotRecordKey._({
    required this.subjectType,
    required this.subjectId,
    required this.snapshotDate,
  });

  /// Stable subject-only key used by historical queries.
  String get subjectKey {
    return '$subjectType$_separator${Uri.encodeComponent(subjectId)}';
  }

  /// Complete Sembast record key.
  String get value {
    return '$subjectKey$_separator$snapshotDate';
  }

  /// Reconstructs the typed snapshot subject represented by this key.
  BalanceSnapshotSubject toSubject() {
    try {
      return switch (subjectType) {
        accountType => BalanceSnapshotSubject.account(
          AccountId.fromString(subjectId),
        ),
        custodianType => BalanceSnapshotSubject.custodian(
          CustodianId.fromString(subjectId),
        ),
        jarType => BalanceSnapshotSubject.jar(JarId.fromString(subjectId)),
        // The public constructors validate the subject type and reject blank
        // IDs, while current ID value objects reject only blank values. These
        // defensive branches are therefore unreachable through the public API.
        // coverage:ignore-start
        _ => throw const PersistenceRecordException(
          field: 'recordKey',
          reason: 'Snapshot subject type is not supported.',
        ),
      };
    } on PersistenceRecordException {
      rethrow;
    } on ArgumentError {
      throw const PersistenceRecordException(
        field: 'recordKey',
        reason: 'Snapshot record key contains an invalid subject identity.',
      );
    }
    // coverage:ignore-end
  }

  static void _validateSubjectType(String subjectType) {
    if (subjectType != accountType &&
        subjectType != custodianType &&
        subjectType != jarType) {
      throw const PersistenceRecordException(
        field: 'recordKey',
        reason: 'Snapshot record key contains an unsupported subject type.',
      );
    }
  }
}
