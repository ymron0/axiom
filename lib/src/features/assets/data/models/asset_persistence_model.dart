import 'package:axiom/src/core/domain/enums/entity_logo_source.dart';
import 'package:axiom/src/core/domain/value_objects/entity_logo.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_exception.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_reader.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_code.dart';

/// Persistence representation of an [Asset].
///
/// This model owns the translation boundary between domain assets and their
/// storage representation.
///
/// ## Identity
///
/// The asset ID is stored as the Sembast record key rather than duplicated
/// inside the record value.
///
/// [recordKey] supplied to [fromRecord] is therefore the authoritative
/// persisted identity.
///
/// ## Record representation
///
/// Asset records contain only persistence-safe primitive values and nested
/// maps. Timestamps are stored as UTC ISO-8601 strings.
///
/// A type discriminator is persisted because [Asset] is a sealed hierarchy and
/// additional asset types may be introduced later.
///
/// ## Failure behavior
///
/// Persisted data is treated as untrusted input.
///
/// Malformed records, unsupported asset types, invalid identifiers, invalid
/// value objects, and reconstructed entities that violate domain invariants
/// produce [PersistenceRecordException].
///
/// The persistent repository is responsible for translating that internal
/// exception into the feature's typed failure contract.
final class AssetPersistenceModel {
  /// Field used by persistence queries for asset-code lookup.
  static const String codeField = 'code';

  static const String _typeField = 'type';
  static const String _entityVersionField = 'entityVersion';
  static const String _createdAtField = 'createdAt';
  static const String _modifiedAtField = 'modifiedAt';
  static const String _nameField = 'name';
  static const String _symbolField = 'symbol';
  static const String _decimalPlacesField = 'decimalPlaces';
  static const String _logoField = 'logo';
  static const String _logoSourceField = 'source';
  static const String _logoValueField = 'value';

  static const String _currencyType = 'currency';

  /// Persisted asset identity.
  ///
  /// This value is represented by the Sembast record key and is intentionally
  /// omitted from [toRecord].
  final String id;

  /// Discriminator identifying the concrete [Asset] subtype.
  final String type;

  /// Domain entity class version.
  final int entityVersion;

  /// Creation timestamp normalized to UTC.
  final DateTime createdAt;

  /// Most recent modification timestamp normalized to UTC.
  final DateTime modifiedAt;

  /// Human-readable asset name.
  final String name;

  /// Machine-readable asset code.
  final String code;

  /// Optional short display symbol.
  final String? symbol;

  /// Supported number of decimal places.
  final int decimalPlaces;

  /// Optional logo source.
  final EntityLogoSource? logoSource;

  /// Optional logo location.
  final String? logoValue;

  const AssetPersistenceModel._({
    required this.id,
    required this.type,
    required this.entityVersion,
    required this.createdAt,
    required this.modifiedAt,
    required this.name,
    required this.code,
    required this.symbol,
    required this.decimalPlaces,
    required this.logoSource,
    required this.logoValue,
  });

  /// Creates a persistence model from [asset].
  ///
  /// The domain entity has already validated its invariants, so this operation
  /// performs structural translation only.
  factory AssetPersistenceModel.fromEntity(Asset asset) {
    final type = switch (asset) {
      Currency() => _currencyType,
    };

    return AssetPersistenceModel._(
      id: asset.id.value,
      type: type,
      entityVersion: asset.entityVersion,
      createdAt: asset.createdAt.toUtc(),
      modifiedAt: asset.modifiedAt.toUtc(),
      name: asset.name,
      code: asset.code.value,
      symbol: asset.symbol,
      decimalPlaces: asset.decimalPlaces,
      logoSource: asset.logo?.source,
      logoValue: asset.logo?.value,
    );
  }

  /// Reconstructs a persistence model from a stored [record].
  ///
  /// [recordKey] is the asset identity stored as the Sembast record key.
  ///
  /// Throws [PersistenceRecordException] when persisted values have an invalid
  /// shape or contain unsupported serialized values.
  factory AssetPersistenceModel.fromRecord({
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

      logoSource = _parseLogoSource(
        logoReader.requiredString(_logoSourceField),
      );
      logoValue = logoReader.requiredString(_logoValueField);
    }

    return AssetPersistenceModel._(
      id: recordKey,
      type: reader.requiredString(_typeField),
      entityVersion: reader.requiredInt(_entityVersionField),
      createdAt: _readUtcDateTime(reader, _createdAtField),
      modifiedAt: _readUtcDateTime(reader, _modifiedAtField),
      name: reader.requiredString(_nameField),
      code: reader.requiredString(codeField),
      symbol: reader.optionalString(_symbolField),
      decimalPlaces: reader.requiredInt(_decimalPlacesField),
      logoSource: logoSource,
      logoValue: logoValue,
    );
  }

  /// Converts this model into the persisted record representation.
  ///
  /// [id] is intentionally omitted because it is stored as the Sembast record
  /// key.
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
    } else {
      // coverage:ignore-start
      throw StateError(
        'Asset persistence model contains incomplete logo data.',
      );
      // coverage:ignore-end
    }

    return <String, Object?>{
      _typeField: type,
      _entityVersionField: entityVersion,
      _createdAtField: createdAt.toUtc().toIso8601String(),
      _modifiedAtField: modifiedAt.toUtc().toIso8601String(),
      _nameField: name,
      codeField: code,
      _symbolField: symbol,
      _decimalPlacesField: decimalPlaces,
      _logoField: logo,
    };
  }

  /// Reconstructs the domain [Asset] represented by this model.
  ///
  /// Throws [PersistenceRecordException] when the persisted asset type is not
  /// supported or persisted values violate current domain invariants.
  Asset toEntity() {
    try {
      final logo = _toEntityLogo();

      return switch (type) {
        _currencyType => Currency(
          id: AssetId.fromString(id),
          entityVersion: entityVersion,
          createdAt: createdAt,
          modifiedAt: modifiedAt,
          name: name,
          code: AssetCode(code),
          symbol: symbol,
          decimalPlaces: decimalPlaces,
          logo: logo,
        ),
        _ => throw PersistenceRecordException(
          field: _typeField,
          reason: 'Unsupported asset type.',
        ),
      };
    } on PersistenceRecordException {
      rethrow;
    } on ArgumentError {
      throw const PersistenceRecordException(
        reason: 'Persisted asset violates current domain invariants.',
      );
    }
  }

  EntityLogo? _toEntityLogo() {
    final source = logoSource;
    final value = logoValue;

    if (source == null && value == null) {
      return null;
    }

    if (source == null || value == null) {
      throw const PersistenceRecordException(
        field: _logoField,
        reason: 'Persisted logo data is incomplete.',
      );
    }

    return EntityLogo(source: source, value: value);
  }

  static DateTime _readUtcDateTime(
    PersistenceRecordReader reader,
    String field,
  ) {
    final rawValue = reader.requiredString(field);
    final parsedValue = DateTime.tryParse(rawValue);

    if (parsedValue == null || !parsedValue.isUtc) {
      throw PersistenceRecordException(
        field: field,
        reason: 'Expected an ISO-8601 timestamp with a timezone.',
      );
    }

    return parsedValue.toUtc();
  }

  static EntityLogoSource _parseLogoSource(String value) {
    return switch (value) {
      'asset' => EntityLogoSource.asset,
      'remote' => EntityLogoSource.remote,
      _ => throw const PersistenceRecordException(
        field: 'logo.source',
        reason: 'Unknown entity logo source.',
      ),
    };
  }
}
