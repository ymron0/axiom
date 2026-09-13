import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/features/categories/domain/enums/budget_period.dart';
import 'package:dart_mappable/dart_mappable.dart';
import 'package:decimal/decimal.dart';

part 'category_budget.mapper.dart';

/// Defines a budget rule that applies to a category during a specific
/// effective-date range.
///
/// Budget rules are historical. Changing a category's budget does not overwrite
/// the previous rule. Instead, the previous rule is ended and a new rule is
/// added.
///
/// ## Effective dates
///
/// [effectiveFrom] is inclusive.
///
/// [effectiveUntil] is exclusive. A `null` value means that the rule remains
/// effective indefinitely.
///
/// For example:
///
/// ```text
/// effectiveFrom:  2026-01-01
/// effectiveUntil: 2026-09-01
/// ```
///
/// means that the rule applies from January 1, 2026 through August 31, 2026.
///
/// ## Currency
///
/// [limit] is always expressed in the application's valuation currency.
///
/// ## Invariants
///
/// - [limit] cannot be negative.
/// - [effectiveUntil], when present, must be after [effectiveFrom].
@MappableClass()
final class CategoryBudget with CategoryBudgetMappable {
  /// Maximum amount available during [period].
  final Decimal limit;

  /// Recurring period over which [limit] applies.
  final BudgetPeriod period;

  /// First calendar date on which this rule applies.
  ///
  /// Inclusive.
  final CalendarDate effectiveFrom;

  /// First calendar date on which this rule no longer applies.
  ///
  /// Exclusive.
  ///
  /// `null` means that this rule remains effective indefinitely.
  final CalendarDate? effectiveUntil;

  /// Creates an effective-dated category budget rule.
  @MappableConstructor()
  CategoryBudget({
    required this.limit,
    required this.period,
    required this.effectiveFrom,
    this.effectiveUntil,
  }) {
    if (limit < Decimal.zero) {
      throw ArgumentError.value(
        limit,
        'limit',
        'Category budget limit cannot be negative.',
      );
    }

    if (effectiveUntil != null && !effectiveUntil!.isAfter(effectiveFrom)) {
      throw ArgumentError.value(
        effectiveUntil,
        'effectiveUntil',
        'Budget effective-until date must be after its effective-from date.',
      );
    }
  }

  /// Whether this budget rule applies on [date].
  bool appliesOn(CalendarDate date) {
    return date.isOnOrAfter(effectiveFrom) &&
        (effectiveUntil == null || date.isBefore(effectiveUntil!));
  }
}
