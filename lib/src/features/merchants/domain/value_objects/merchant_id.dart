import 'package:axiom/src/core/domain/value_objects/unique_id.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'merchant_id.mapper.dart';

/// A type-safe identifier for a merchant.
///
/// Create one from a persisted value:
/// ```dart
/// final merchantId = MerchantId.fromString('merchant-123');
/// ```
@MappableClass()
final class MerchantId extends UniqueId with MerchantIdMappable {
  /// The reserved identifier used for the current merchant context.
  static final self = MerchantId.fromString('self');

  /// Creates a merchant identifier from its serialized [value].
  ///
  /// Throws an [ArgumentError] when [value] is blank.
  @MappableConstructor()
  MerchantId.fromString(super.value);

  /// Creates a merchant identifier with a newly generated Nano ID value.
  MerchantId.generate() : super.generate();
}
