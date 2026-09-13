import 'package:dart_mappable/dart_mappable.dart';

part 'budget_period.mapper.dart';

/// Defines the period over which a category budget limit applies.
///
/// The budget is evaluated against transactions falling inside the current
/// calendar period.
///
/// For example:
///
/// ```text
/// Groceries
/// CHF 700 / month
///
/// Leisure
/// CHF 2,000 / year
/// ```
///
/// Period boundary calculation does not belong to this enum. It should be
/// performed by the application/domain calculation responsible for determining
/// budget usage for a specific date.
@MappableEnum()
enum BudgetPeriod {
  /// The budget applies to one calendar month and resets for the next month.
  monthly,

  /// The budget applies to one calendar year and resets for the next year.
  yearly,
}