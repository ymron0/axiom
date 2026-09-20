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
/// ## Polymorphism
///
/// [typeField] identifies the concrete domain subtype.
///
/// [paymentEnabledField] persists whether the asset is usable for payments.
/// During reconstruction, fixed subtype payment semantics are validated rather
/// than silently corrected.
///
/// ## Backward compatibility
///
/// Currency records written before payment support was introduced do not
/// contain [paymentEnabledField]. Such records are interpreted as payment
/// enabled because that is an invariant of [Currency].
///
/// Missing payment information for any other subtype is considered corrupt
/// persistence.
///
/// ## Identity
///
/// The asset ID is stored as the Sembast record key rather than duplicated
/// inside the record value.
///
/// ## Failure behavior
///
/// Persisted data is treated as untrusted input. Malformed records,
/// unsupported asset types, invalid identifiers, invalid value objects, and
/// reconstructed entities that violate domain invariants produce
/// [PersistenceRecordException].
final class AssetPersistenceModel {
  /// Field used by persistence queries for asset-code lookup.
  static const String codeField = 'code';

  /// Field containing the persisted concrete asset type.
  static const String typeField = 'type';

  /// Field indicating whether the asset can be used for payments.
  static const String paymentEnabledField = 'paymentEnabled';

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
  static const String _cryptoType = 'crypto';
  static const String _stockType = 'stock';
  static const String _commodityType = 'commodity';

  /// Persisted asset identity.
  final String id;

  /// Discriminator identifying the concrete [Asset] subtype.
  final String type;

  /// Whether the persisted asset is enabled for payments.
  final bool paymentEnabled;

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

  /// Creates a persistence model from [asset].
  factory AssetPersistenceModel.fromEntity(Asset asset) {
    final type = switch (asset) {
      Currency() => _currencyType,
      CryptoAsset() => _cryptoType,
      StockAsset() => _stockType,
      CommodityAsset() => _commodityType,
    };

    return AssetPersistenceModel._(
      id: asset.id.value,
      type: type,
      paymentEnabled: asset.paymentEnabled,
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
  factory AssetPersistenceModel.fromRecord({
    required String recordKey,
    required PersistenceRecord record,
  }) {
    final reader = PersistenceRecordReader(record);

    final type = reader.requiredString(typeField);
    final paymentEnabled = _readPaymentEnabled(reader: reader, type: type);

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
      type: type,
      paymentEnabled: paymentEnabled,
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

  const AssetPersistenceModel._({
    required this.id,
    required this.type,
    required this.paymentEnabled,
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

  /// Reconstructs the domain [Asset] represented by this model.
  ///
  /// Throws [PersistenceRecordException] when the persisted asset type is not
  /// supported or persisted values violate current domain invariants.
  Asset toEntity() {
    try {
      _validatePaymentSemantics();

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
        _cryptoType => CryptoAsset(
          id: AssetId.fromString(id),
          entityVersion: entityVersion,
          createdAt: createdAt,
          modifiedAt: modifiedAt,
          name: name,
          code: AssetCode(code),
          symbol: symbol,
          decimalPlaces: decimalPlaces,
          logo: logo,
          paymentEnabled: paymentEnabled,
        ),
        _stockType => StockAsset(
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
        _commodityType => CommodityAsset(
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
          field: typeField,
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

  /// Converts this model into the persisted record representation.
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
      typeField: type,
      paymentEnabledField: paymentEnabled,
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

  void _validatePaymentSemantics() {
    if (type == _currencyType && !paymentEnabled) {
      throw const PersistenceRecordException(
        field: paymentEnabledField,
        reason: 'Currency assets must be payment enabled.',
      );
    }

    if ((type == _stockType || type == _commodityType) && paymentEnabled) {
      throw const PersistenceRecordException(
        field: paymentEnabledField,
        reason: 'This asset type cannot be payment enabled.',
      );
    }
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

  static bool _readPaymentEnabled({
    required PersistenceRecordReader reader,
    required String type,
  }) {
    if (reader.contains(paymentEnabledField)) {
      return reader.requiredBool(paymentEnabledField);
    }

    // Currency is the only asset subtype that existed before payment-enabled
    // persistence was introduced. Its value is fixed by domain semantics.
    if (type == _currencyType) {
      return true;
    }

    throw const PersistenceRecordException(
      field: paymentEnabledField,
      reason: 'Required field is missing.',
    );
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
}
