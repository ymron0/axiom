import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/rate_id.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_exception.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_reader.dart';
import 'package:axiom/src/features/rates/domain/entities/exchange_rate.dart';
import 'package:axiom/src/features/rates/domain/entities/rate.dart';
import 'package:decimal/decimal.dart';

/// Persistence representation of a [Rate].
///
/// This model owns the translation boundary between domain rates and their
/// persisted representation.
///
/// ## Identity
///
/// The rate ID is stored as the Sembast record key rather than duplicated
/// inside the record value.
///
/// [recordKey] supplied to [fromRecord] is therefore the authoritative
/// persisted identity.
///
/// ## Record representation
///
/// Rate records contain only persistence-safe primitive values.
///
/// Decimal values are stored as strings so that persistence never introduces
/// binary floating-point rounding.
///
/// Timestamps are stored as UTC ISO-8601 strings.
///
/// A type discriminator is persisted because [Rate] is an abstract hierarchy
/// and additional rate types may be introduced later.
///
/// ## Query fields
///
/// [baseAssetIdField] and [quoteAssetIdField] are public because persistent
/// repository implementations query those fields directly.
///
/// [effectiveAt] is intentionally reconstructed as a [DateTime] before
/// temporal ordering is performed. Repository semantics therefore do not
/// depend on textual ordering of serialized timestamps.
///
/// ## Failure behavior
///
/// Persisted data is treated as untrusted input.
///
/// Malformed records, unsupported rate types, malformed decimal values,
/// invalid identifiers, and reconstructed entities that violate current
/// domain invariants produce [PersistenceRecordException].
///
/// The persistent repository translates that internal exception into the
/// feature's typed persistence failure contract.
final class RatePersistenceModel {
  /// Field used by persistence queries for the ordered pair's base asset.
  static const String baseAssetIdField = 'baseAssetId';

  /// Field used by persistence queries for the ordered pair's quote asset.
  static const String quoteAssetIdField = 'quoteAssetId';

  static const String _typeField = 'type';
  static const String _entityVersionField = 'entityVersion';
  static const String _createdAtField = 'createdAt';
  static const String _modifiedAtField = 'modifiedAt';
  static const String _rateField = 'rate';
  static const String _effectiveAtField = 'effectiveAt';

  static const String _exchangeRateType = 'exchangeRate';

  /// Persisted rate identity.
  ///
  /// This value is represented by the Sembast record key and is intentionally
  /// omitted from [toRecord].
  final String id;

  /// Discriminator identifying the concrete [Rate] subtype.
  final String type;

  /// Domain entity class version.
  final int entityVersion;

  /// Creation timestamp normalized to UTC.
  final DateTime createdAt;

  /// Most recent modification timestamp normalized to UTC.
  final DateTime modifiedAt;

  /// Persisted base asset identity.
  final String baseAssetId;

  /// Persisted quote asset identity.
  final String quoteAssetId;

  /// Exact decimal representation of the rate.
  ///
  /// The value is deliberately stored as a string rather than as a `double`.
  final String rate;

  /// Financial effective timestamp normalized to UTC.
  final DateTime effectiveAt;

  const RatePersistenceModel._({
    required this.id,
    required this.type,
    required this.entityVersion,
    required this.createdAt,
    required this.modifiedAt,
    required this.baseAssetId,
    required this.quoteAssetId,
    required this.rate,
    required this.effectiveAt,
  });

  /// Creates a persistence model from [rate].
  ///
  /// Domain invariants have already been validated by the entity, so this
  /// operation performs structural translation only.
  ///
  /// Throws [UnsupportedError] when a new concrete [Rate] subtype reaches the
  /// persistence layer before explicit persistence support has been added.
  ///
  /// Such an error is a programming/configuration error rather than corrupt
  /// persisted data and must therefore not be converted into a persistence
  /// failure.
  factory RatePersistenceModel.fromEntity(Rate rate) {
    final type = switch (rate) {
      ExchangeRate() => _exchangeRateType,
      _ => throw UnsupportedError(
        'Unsupported rate type: ${rate.runtimeType}.',
      ),
    };

    return RatePersistenceModel._(
      id: rate.id.value,
      type: type,
      entityVersion: rate.entityVersion,
      createdAt: rate.createdAt.toUtc(),
      modifiedAt: rate.modifiedAt.toUtc(),
      baseAssetId: rate.baseAssetId.value,
      quoteAssetId: rate.quoteAssetId.value,
      rate: rate.rate.toString(),
      effectiveAt: rate.effectiveAt.toUtc(),
    );
  }

  /// Reconstructs a persistence model from a stored [record].
  ///
  /// [recordKey] is the rate identity stored as the Sembast record key.
  ///
  /// Throws [PersistenceRecordException] when required fields are absent,
  /// malformed, or contain unsupported serialized values.
  factory RatePersistenceModel.fromRecord({
    required String recordKey,
    required PersistenceRecord record,
  }) {
    final reader = PersistenceRecordReader(record);

    return RatePersistenceModel._(
      id: recordKey,
      type: reader.requiredString(_typeField),
      entityVersion: reader.requiredInt(_entityVersionField),
      createdAt: _readUtcDateTime(reader, _createdAtField),
      modifiedAt: _readUtcDateTime(reader, _modifiedAtField),
      baseAssetId: reader.requiredString(baseAssetIdField),
      quoteAssetId: reader.requiredString(quoteAssetIdField),
      rate: reader.requiredString(_rateField),
      effectiveAt: _readUtcDateTime(reader, _effectiveAtField),
    );
  }

  /// Converts this model into the persisted record representation.
  ///
  /// [id] is intentionally omitted because it is stored as the Sembast record
  /// key.
  ///
  /// Decimal values remain strings so their exact decimal representation is
  /// preserved without introducing binary floating-point conversion.
  PersistenceRecord toRecord() {
    return <String, Object?>{
      _typeField: type,
      _entityVersionField: entityVersion,
      _createdAtField: createdAt.toUtc().toIso8601String(),
      _modifiedAtField: modifiedAt.toUtc().toIso8601String(),
      baseAssetIdField: baseAssetId,
      quoteAssetIdField: quoteAssetId,
      _rateField: rate,
      _effectiveAtField: effectiveAt.toUtc().toIso8601String(),
    };
  }

  /// Reconstructs the domain [Rate] represented by this model.
  ///
  /// Throws [PersistenceRecordException] when:
  ///
  /// - the persisted rate type is unsupported;
  /// - the decimal representation is malformed;
  /// - persisted identifiers are invalid; or
  /// - persisted values violate current [Rate] invariants.
  Rate toEntity() {
    try {
      final decimalRate = _parseDecimal(rate);

      return switch (type) {
        _exchangeRateType => ExchangeRate(
          id: RateId.fromString(id),
          baseAssetId: AssetId.fromString(baseAssetId),
          quoteAssetId: AssetId.fromString(quoteAssetId),
          rate: decimalRate,
          effectiveAt: effectiveAt,
          entityVersion: entityVersion,
          createdAt: createdAt,
          modifiedAt: modifiedAt,
        ),
        _ => throw PersistenceRecordException(
          field: _typeField,
          reason: 'Unsupported rate type.',
        ),
      };
    } on PersistenceRecordException {
      rethrow;
    } on ArgumentError {
      throw const PersistenceRecordException(
        reason: 'Persisted rate violates current domain invariants.',
      );
    }
  }

  /// Reads a required persisted timestamp and normalizes it to UTC.
  ///
  /// Persisted timestamps without timezone information are rejected because
  /// accepting local timestamps would make reconstruction dependent on the
  /// runtime environment.
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

  /// Parses an exact persisted decimal representation.
  ///
  /// Decimal values are serialized as strings rather than doubles so that
  /// financial values round-trip without binary floating-point loss.
  static Decimal _parseDecimal(String value) {
    try {
      return Decimal.parse(value);
    } on FormatException {
      throw const PersistenceRecordException(
        field: _rateField,
        reason: 'Expected a valid decimal representation.',
      );
    }
  }
}
