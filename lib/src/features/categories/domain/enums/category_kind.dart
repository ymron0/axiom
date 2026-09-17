// coverage:ignore-file

import 'package:dart_mappable/dart_mappable.dart';

part 'category_kind.mapper.dart';

/// Describes the classification and reporting nature of a category.
///
/// Category kind groups categories into expense-oriented and income-oriented
/// hierarchies. It is used for hierarchy validation, budgeting semantics,
/// reporting, and presentation.
///
/// Category kind does not restrict the direction of transactions that may be
/// allocated to the category.
///
/// For example, an expense category may contain:
///
/// - outgoing expense transactions such as insurance premiums; and
/// - incoming transactions such as insurance reimbursements.
///
/// Likewise, an income category may contain outgoing adjustments, reversals,
/// chargebacks, or repayments.
///
/// Opposite-direction allocations reduce the category's net activity and may
/// cause its value for a period to become negative relative to its normal kind.
///
/// A child category must have the same kind as its parent. For example:
///
/// ```text
/// Household (expense)
/// ├── Groceries (expense)
/// └── Rent (expense)
///
/// Income (income)
/// ├── Salary (income)
/// └── Interest (income)
/// ```
///
/// A hierarchy such as an income category below an expense category is not
/// valid.
@MappableEnum()
enum CategoryKind {
  /// An expense-oriented category.
  ///
  /// Outgoing allocations normally increase its expense value, while incoming
  /// allocations reduce it.
  expense,

  /// An income-oriented category.
  ///
  /// Incoming allocations normally increase its income value, while outgoing
  /// allocations reduce it.
  income,
}