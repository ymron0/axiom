import 'package:axiom/src/core/domain/value_objects/unique_id.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'budget_id.mapper.dart';

/// A type-safe identifier for a budget.
///
/// Create one from a persisted value:
/// ```dart
/// final budgetId = BudgetId.fromString('budget-123');
/// ```
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
