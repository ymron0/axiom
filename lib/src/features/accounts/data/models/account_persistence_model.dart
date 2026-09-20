import 'package:axiom/src/core/domain/enums/entity_color.dart';
import 'package:axiom/src/core/domain/enums/entity_icon.dart';
import 'package:axiom/src/core/domain/enums/entity_logo_source.dart';
import 'package:axiom/src/core/domain/value_objects/entity_logo.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/custodian_id.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_exception.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_reader.dart';
import 'package:axiom/src/features/accounts/domain/entities/account.dart';
import 'package:axiom/src/features/accounts/domain/enums/account_kind.dart';

/// Persistence representation of an [Account].
///
/// This model owns the translation boundary between the Accounts domain and the
/// Sembast-compatible primitive representation stored by the data layer.
///
/// ## Identity
///
/// The account ID is stored as the Sembast record key rather than duplicated
/// inside the record value.
///
/// [recordKey] supplied to [fromRecord] is therefore the authoritative
/// persisted identity.
///
/// ## Record representation
///
/// Records contain persistence-safe primitive values and nested maps only.
///
/// Enumerations are stored using their stable enum names.
///
/// Timestamps are serialized as UTC ISO-8601 strings.
///
/// ## Deleted accounts
///
/// Deleted accounts are not valid persisted account records.
///
/// `AccountRepository.delete` physically removes the record and returns a
/// caller-retained snapshot containing a non-null `deletedAt`. Consequently a
/// record containing a non-null [deletedAt] indicates invalid persisted state
/// and is rejected by [toEntity].
///
/// The `deletedAt` field remains part of the persisted shape so the entity's
/// lifecycle representation remains explicit and malformed or legacy records
/// can be detected rather than silently interpreted as active accounts.
///
/// ## Failure behavior
///
/// Persisted values are treated as untrusted input.
///
/// Malformed values, unsupported enum values, invalid identifiers, malformed
/// timestamps, invalid logos, and records violating current Account invariants
/// produce [PersistenceRecordException].
///
/// Persistent repository implementations translate that internal exception into
/// [AccountRepositoryFailure] through the common persistence-operation guard.
final class AccountPersistenceModel {
  /// Field containing the account name.
  ///
  /// Public because repository queries may depend on this persisted field.
  static const String nameField = 'name';

  /// Field containing the owning custodian ID.
  ///
  /// Public because `AccountRepository.getByCustodianId` queries this field
  /// directly.
  static const String custodianIdField = 'custodianId';

  /// Field containing the archive timestamp.
  ///
  /// Public because archive state is a repository query dimension.
  static const String archivedAtField = 'archivedAt';

  /// Field containing the deletion timestamp.
  ///
  /// Persisted accounts must always contain `null` here.
  static const String deletedAtField = 'deletedAt';

  static const String _denominationAssetIdField = 'denominationAssetId';
  static const String _kindField = 'kind';
  static const String _referenceField = 'reference';
  static const String _logoField = 'logo';
  static const String _logoSourceField = 'source';
  static const String _logoValueField = 'value';
  static const String _iconField = 'icon';
  static const String _colorField = 'color';
  static const String _sortOrderField = 'sortOrder';
  static const String _createdAtField = 'createdAt';
  static const String _modifiedAtField = 'modifiedAt';
  static const String _entityVersionField = 'entityVersion';

  /// Persisted account identity.
  ///
  /// This value is represented by the Sembast record key and is intentionally
  /// omitted from [toRecord].
  final String id;

  /// Human-readable account name.
  final String name;

  /// Identity of the custodian holding the account.
  final String custodianId;

  /// Identity of the asset in which the account is denominated.
  final String denominationAssetId;

  /// Semantic account kind.
  final AccountKind kind;

  /// Optional user-visible account reference.
  final String? reference;

  /// Optional logo source.
  final EntityLogoSource? logoSource;

  /// Optional logo source-specific location.
  final String? logoValue;

  /// Semantic fallback icon.
  final EntityIcon icon;

  /// Semantic display color.
  final EntityColor color;

  /// User-defined account ordering position.
  final int sortOrder;

  /// Optional archive timestamp.
  final DateTime? archivedAt;

  /// Optional deletion timestamp.
  ///
  /// This must always be `null` for a valid stored account.
  final DateTime? deletedAt;

  /// Creation timestamp normalized to UTC.
  final DateTime createdAt;

  /// Latest modification timestamp normalized to UTC.
  final DateTime modifiedAt;

  /// Domain entity class version.
  final int entityVersion;

  const AccountPersistenceModel._({
    required this.id,
    required this.name,
    required this.custodianId,
    required this.denominationAssetId,
    required this.kind,
    required this.reference,
    required this.logoSource,
    required this.logoValue,
    required this.icon,
    required this.color,
    required this.sortOrder,
    required this.archivedAt,
    required this.deletedAt,
    required this.createdAt,
    required this.modifiedAt,
    required this.entityVersion,
  });

  /// Creates a persistence model from [account].
  ///
  /// Deleted accounts cannot be persisted because deletion in
  /// [AccountRepository] is physical.
  ///
  /// A deleted account reaching this layer therefore represents a programming
  /// error rather than an expected persistence failure.
  factory AccountPersistenceModel.fromEntity(Account account) {
    if (account.deletedAt != null) {
      throw StateError(
        'Deleted accounts cannot be represented as persisted account records.',
      );
    }

    return AccountPersistenceModel._(
      id: account.id.value,
      name: account.name,
      custodianId: account.custodianId.value,
      denominationAssetId: account.denominationAssetId.value,
      kind: account.kind,
      reference: account.reference,
      logoSource: account.logo?.source,
      logoValue: account.logo?.value,
      icon: account.icon,
      color: account.color,
      sortOrder: account.sortOrder,
      archivedAt: account.archivedAt?.toUtc(),
      deletedAt: null,
      createdAt: account.createdAt.toUtc(),
      modifiedAt: account.modifiedAt.toUtc(),
      entityVersion: account.entityVersion,
    );
  }

  /// Reconstructs a persistence model from [record].
  ///
  /// [recordKey] is the account identity stored as the Sembast record key.
  ///
  /// Throws [PersistenceRecordException] when a persisted field has an invalid
  /// type or unsupported serialized value.
  factory AccountPersistenceModel.fromRecord({
    required String recordKey,
    required PersistenceRecord record,
  }) {
    final reader = PersistenceRecordReader(record);

    final logoRecord = reader.optionalMap(_logoField);

    final EntityLogoSource? logoSource;
    final String? logoValue;

    if (logoRecord == null) {
      logoSource = null;
      logoValue = null;
    } else {
      final logoReader = PersistenceRecordReader(logoRecord);

      logoSource = _parseEnum<EntityLogoSource>(
        value: logoReader.requiredString(_logoSourceField),
        values: EntityLogoSource.values,
        field: '$_logoField.$_logoSourceField',
      );

      logoValue = logoReader.requiredString(_logoValueField);
    }

    return AccountPersistenceModel._(
      id: recordKey,
      name: reader.requiredString(nameField),
      custodianId: reader.requiredString(custodianIdField),
      denominationAssetId: reader.requiredString(_denominationAssetIdField),
      kind: _parseEnum<AccountKind>(
        value: reader.requiredString(_kindField),
        values: AccountKind.values,
        field: _kindField,
      ),
      reference: reader.optionalString(_referenceField),
      logoSource: logoSource,
      logoValue: logoValue,
      icon: _parseEnum<EntityIcon>(
        value: reader.requiredString(_iconField),
        values: EntityIcon.values,
        field: _iconField,
      ),
      color: _parseEnum<EntityColor>(
        value: reader.requiredString(_colorField),
        values: EntityColor.values,
        field: _colorField,
      ),
      sortOrder: reader.requiredInt(_sortOrderField),
      archivedAt: _readOptionalUtcDateTime(reader, archivedAtField),
      deletedAt: _readOptionalUtcDateTime(reader, deletedAtField),
      createdAt: _readRequiredUtcDateTime(reader, _createdAtField),
      modifiedAt: _readRequiredUtcDateTime(reader, _modifiedAtField),
      entityVersion: reader.requiredInt(_entityVersionField),
    );
  }

  /// Converts this model into its Sembast-compatible record representation.
  ///
  /// [id] is intentionally omitted because it is represented by the Sembast
  /// record key.
  PersistenceRecord toRecord() {
    final PersistenceRecord? logo;

    final source = logoSource;
    final value = logoValue;

    if (source == null && value == null) {
      logo = null;
    } else if (source != null && value != null) {
      logo = <String, Object?>{
        _logoSourceField: source.name,
        _logoValueField: value,
      };
    // coverage:ignore-start
    } else {
      throw StateError(
        'Account persistence model contains incomplete logo data.',
      );
    }
    // coverage:ignore-end

    return <String, Object?>{
      nameField: name,
      custodianIdField: custodianId,
      _denominationAssetIdField: denominationAssetId,
      _kindField: kind.name,
      _referenceField: reference,
      _logoField: logo,
      _iconField: icon.name,
      _colorField: color.name,
      _sortOrderField: sortOrder,
      archivedAtField: archivedAt?.toUtc().toIso8601String(),
      deletedAtField: deletedAt?.toUtc().toIso8601String(),
      _createdAtField: createdAt.toUtc().toIso8601String(),
      _modifiedAtField: modifiedAt.toUtc().toIso8601String(),
      _entityVersionField: entityVersion,
    };
  }

  /// Reconstructs the domain [Account] represented by this model.
  ///
  /// Throws [PersistenceRecordException] when persisted values violate current
  /// Accounts-domain invariants.
  Account toEntity() {
    if (deletedAt != null) {
      throw const PersistenceRecordException(
        field: deletedAtField,
        reason:
            'Deleted accounts must not remain in persistent account storage.',
      );
    }

    try {
      return Account(
        id: AccountId.fromString(id),
        name: name,
        custodianId: CustodianId.fromString(custodianId),
        denominationAssetId: AssetId.fromString(denominationAssetId),
        kind: kind,
        reference: reference,
        logo: _toEntityLogo(),
        icon: icon,
        color: color,
        sortOrder: sortOrder,
        archivedAt: archivedAt,
        deletedAt: null,
        createdAt: createdAt,
        modifiedAt: modifiedAt,
        entityVersion: entityVersion,
      );
    } on PersistenceRecordException {
      rethrow;
    } on ArgumentError {
      throw const PersistenceRecordException(
        reason: 'Persisted account violates current domain invariants.',
      );
    }
  }

  /// Reconstructs the optional account logo.
  EntityLogo? _toEntityLogo() {
    final source = logoSource;
    final value = logoValue;

    if (source == null && value == null) {
      return null;
    }

    if (source == null || value == null) {
      throw const PersistenceRecordException(
        field: _logoField,
        reason: 'Persisted account logo data is incomplete.',
      );
    }

    try {
      return EntityLogo(source: source, value: value);
    } on ArgumentError {
      throw const PersistenceRecordException(
        field: _logoField,
        reason: 'Persisted account logo is invalid.',
      );
    }
  }

  /// Reads a required UTC timestamp.
  static DateTime _readRequiredUtcDateTime(
    PersistenceRecordReader reader,
    String field,
  ) {
    return _parseUtcDateTime(value: reader.requiredString(field), field: field);
  }

  /// Reads an optional UTC timestamp.
  static DateTime? _readOptionalUtcDateTime(
    PersistenceRecordReader reader,
    String field,
  ) {
    final rawValue = reader.optionalString(field);

    if (rawValue == null) {
      return null;
    }

    return _parseUtcDateTime(value: rawValue, field: field);
  }

  /// Parses a timestamp that must contain timezone information.
  static DateTime _parseUtcDateTime({
    required String value,
    required String field,
  }) {
    final parsedValue = DateTime.tryParse(value);

    if (parsedValue == null || !parsedValue.isUtc) {
      throw PersistenceRecordException(
        field: field,
        reason: 'Expected an ISO-8601 timestamp with a timezone.',
      );
    }

    return parsedValue.toUtc();
  }

  /// Reconstructs a persisted enum by its stable name.
  static T _parseEnum<T extends Enum>({
    required String value,
    required Iterable<T> values,
    required String field,
  }) {
    try {
      return values.byName(value);
    } on ArgumentError {
      throw PersistenceRecordException(
        field: field,
        reason: 'Unknown persisted enum value: $value.',
      );
    }
  }
}
