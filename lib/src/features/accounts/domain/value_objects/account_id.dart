import 'package:axiom/src/core/domain/value_objects/unique_id.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'account_id.mapper.dart';

/// A type-safe identifier for an account.
///
/// Create one from a persisted value:
/// ```dart
/// final accountId = AccountId.fromString('account-123');
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
/// The Dart type represents account identity and must not be substituted for
/// an unrelated typed identifier with the same serialized value.
///
/// ## Contract
///
/// Use [fromString] for persisted values and [generate] for new account IDs.
@MappableClass()
final class AccountId extends UniqueId with AccountIdMappable {
  /// Creates an account identifier from its serialized [value].
  ///
  /// Throws an [ArgumentError] when [value] is blank.
  @MappableConstructor()
  AccountId.fromString(super.value);

  /// Creates an account identifier with a newly generated Nano ID value.
  AccountId.generate() : super.generate();
}
