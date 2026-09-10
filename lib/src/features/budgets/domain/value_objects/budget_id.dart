import 'package:axiom/src/core/domain/value_objects/unique_id.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'budget_id.mapper.dart';

/// A type-safe identifier for a budget.
///
/// Create one from a persisted value:
/// ```dart
/// final budgetId = BudgetId.fromString('budget-123');
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
/// The Dart type represents budget identity and must not be substituted for an
/// unrelated typed identifier with the same serialized value.
///
/// ## Contract
///
/// Use [fromString] for persisted values and [generate] for new budget IDs.
@MappableClass()
final class BudgetId extends UniqueId with BudgetIdMappable {
  /// Creates a budget identifier from its serialized [value].
  ///
  /// Throws an [ArgumentError] when [value] is blank.
  @MappableConstructor()
  BudgetId.fromString(super.value);

  /// Creates a budget identifier with a newly generated Nano ID value.
  BudgetId.generate() : super.generate();
}
