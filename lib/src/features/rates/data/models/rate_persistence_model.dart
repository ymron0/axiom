import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/rate_id.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_exception.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_reader.dart';
import 'package:axiom/src/features/rates/domain/entities/rate.dart';
import 'package:decimal/decimal.dart';

/// Persistence representation of a [Rate].
///
/// The concrete rate type is retained explicitly so exchange-rate and
/// market-price semantics survive persistence round-trips.
final class RatePersistenceModel {
  /// Field used to query the ordered pair's base asset.
  static const String baseAssetIdField = 'baseAssetId';

  /// Field used to query the ordered pair's quote asset.
  static const String quoteAssetIdField = 'quoteAssetId';

  static const String _typeField = 'type';
  static const String _entityVersionField = 'entityVersion';
  static const String _createdAtField = 'createdAt';
  static const String _modifiedAtField = 'modifiedAt';
  static const String _rateField = 'rate';
  static const String _effectiveAtField = 'effectiveAt';

  static const String _exchangeRateType = 'exchangeRate';
  static const String _marketPriceRateType = 'marketPriceRate';

  /// Persisted rate identity.
  final String id;

  /// Concrete rate discriminator.
  final String type;

  /// Domain entity version.
  final int entityVersion;

  /// Entity creation timestamp.
  final DateTime createdAt;

  /// Entity modification timestamp.
  final DateTime modifiedAt;

  /// Base asset identity.
  final String baseAssetId;

  /// Quote asset identity.
  final String quoteAssetId;

  /// Exact decimal rate representation.
  final String rate;

  /// Financial effective instant.
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

  /// Creates the persistence model from a domain rate.
  factory RatePersistenceModel.fromEntity(Rate rate) {
    final type = switch (rate) {
      ExchangeRate() => _exchangeRateType,
      MarketPriceRate() => _marketPriceRateType,
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

  /// Reconstructs a persistence model from a stored record.
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

  /// Converts this model to its primitive persistence record.
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

  /// Reconstructs the domain rate.
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
        _marketPriceRateType => MarketPriceRate(
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
