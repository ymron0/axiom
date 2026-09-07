import 'package:axiom/src/core/domain/value_objects/unique_id.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'account_id.mapper.dart';

/// A type-safe identifier for an account.
///
/// Create one from a persisted value:
/// ```dart
/// final accountId = AccountId.fromString('account-123');
/// ```
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
