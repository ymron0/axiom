import 'package:axiom/src/core/identity/unique_id.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'merchant_id.mapper.dart';

/// A type-safe identifier for a merchant.
///
/// Create one from a persisted value:
/// ```dart
/// final merchantId = MerchantId.fromString('merchant-123');
/// ```
///
/// ## Invariants
///
/// The serialized value is non-empty, not solely whitespace, immutable, and
/// stable for the lifetime of this identifier. Generated values obey the same
/// validation contract. Valid supplied values are preserved exactly without
/// silent trimming or normalization.
///
/// ## Semantics
///
/// The Dart type represents merchant identity; [self] is the reserved current
/// merchant identity. Neither may be substituted for an unrelated typed ID.
///
/// ## Contract
///
/// Use [fromString] for persisted values and [generate] for new merchant IDs.
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
