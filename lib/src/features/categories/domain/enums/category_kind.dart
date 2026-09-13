import 'package:dart_mappable/dart_mappable.dart';

part 'category_kind.mapper.dart';

/// Describes the financial nature of a category.
///
/// The kind determines whether transactions classified under the category
/// represent money spent or money received.
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
  /// Classifies money leaving the user's finances.
  expense,

  /// Classifies money entering the user's finances.
  income,
}