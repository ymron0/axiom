// coverage:ignore-file

import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/categories/domain/entities/category.dart';
import 'package:axiom/src/features/categories/domain/enums/budget_period.dart';
import 'package:axiom/src/features/categories/domain/enums/category_kind.dart';
import 'package:axiom/src/features/categories/domain/failures/category_already_active_failure.dart';
import 'package:axiom/src/features/categories/domain/failures/category_already_deleted_failure.dart';
import 'package:axiom/src/features/categories/domain/failures/category_already_exists_failure.dart';
import 'package:axiom/src/features/categories/domain/failures/category_failure.dart';
import 'package:axiom/src/features/categories/domain/failures/category_not_found_failure.dart';

/// Domain-facing contract for storing and retrieving [Category] entities.
///
/// A category is the single classification selected for a transaction
/// allocation. It identifies what the transaction represents and may also
/// define one or more effective-dated budget rules.
///
/// ## Persistence semantics
///
/// Categories with a non-null [Category.deletedAt] are absent from persistence.
///
/// Deletion is physical: this repository returns the deleted snapshot but does
/// not retain it. A caller that needs to support restoration must retain that
/// snapshot and later pass it to [restore].
///
/// ## Hierarchy
///
/// Category relationships are represented by [Category.parentCategoryId].
///
/// This repository stores those relationships but does not enforce
/// cross-category hierarchy invariants.
///
/// Rules requiring knowledge of both the child and parent category must be
/// validated before persistence. These include:
///
/// - the parent category must exist;
/// - the parent category must be active;
/// - a category cannot be its own parent;
/// - the parent must itself be top-level;
/// - the hierarchy cannot exceed the supported two levels; and
/// - the child and parent must have compatible category kinds.
///
/// These rules belong to the domain/application operation coordinating the
/// relationship rather than to the persistence implementation.
///
/// ## Budgeting
///
/// Budget definitions are stored as part of [Category].
///
/// A category may contain zero or more effective-dated budget rules. These
/// rules may represent historical, current, or future budgets.
///
/// This repository stores and queries budget configuration only. It does not
/// calculate:
///
/// - amounts spent or received;
/// - remaining budget;
/// - budget usage percentages;
/// - budget status; or
/// - parent-category aggregate usage.
///
/// Those values require transaction data and belong to higher-level domain or
/// application operations.
///
/// ## Deletion
///
/// The repository itself does not determine whether a category is referenced
/// by transactions or has child categories.
///
/// Such usage checks must be performed before calling [delete].
abstract interface class CategoryRepository {
  /// Stores a new active [category].
  ///
  /// Fails with [CategoryAlreadyExistsFailure] when a category with the same
  /// identity already exists.
  ///
  /// Fails with [CategoryAlreadyDeletedFailure] when [Category.deletedAt] is
  /// not `null`.
  Future<Result<void, CategoryFailure>> create(Category category);

  /// Returns all persisted categories.
  ///
  /// This includes both top-level and child categories.
  ///
  /// Returns an empty list when no categories exist.
  Future<Result<List<Category>, CategoryFailure>> getAll();

  /// Returns the persisted category identified by [id].
  ///
  /// Returns `null` when no category with [id] exists.
  Future<Result<Category?, CategoryFailure>> getById(CategoryId id);

  /// Returns all persisted direct children of the category identified by
  /// [parentId].
  ///
  /// Only direct children are returned.
  ///
  /// The Categories domain supports a maximum hierarchy depth of:
  ///
  /// ```text
  /// Parent
  /// └── Child
  /// ```
  ///
  /// Therefore descendants beyond one child level are not expected.
  ///
  /// This method does not require that a category with [parentId] actually
  /// exists. It simply returns categories whose [Category.parentCategoryId]
  /// matches [parentId].
  ///
  /// Returns an empty list when no child categories reference [parentId].
  Future<Result<List<Category>, CategoryFailure>> getByParentId(
    CategoryId parentId,
  );

  /// Returns all persisted categories whose [Category.kind] equals [kind].
  ///
  /// This includes both top-level and child categories.
  ///
  /// For example, this query may be used when transaction entry needs to show
  /// only expense categories or only income categories.
  ///
  /// Returns an empty list when no categories have [kind].
  Future<Result<List<Category>, CategoryFailure>> getByKind(CategoryKind kind);

  /// Returns all persisted categories that define at least one budget rule.
  ///
  /// A category is considered budgeted when [Category.budgets] is not empty.
  ///
  /// Historical, current, and future budget rules all count. This query does
  /// not determine whether a budget is effective on the current date.
  ///
  /// For example, a category whose only budget applied during 2025 is still
  /// returned because it has budget history.
  ///
  /// Returns an empty list when no category defines any budget rules.
  Future<Result<List<Category>, CategoryFailure>> getBudgeted();

  /// Returns all persisted categories that contain at least one budget rule
  /// whose period equals [period].
  ///
  /// Historical, current, and future budget rules are all considered.
  ///
  /// A category is returned only once even when several of its budget rules
  /// use [period].
  ///
  /// For example, given:
  ///
  /// ```text
  /// Leisure
  /// 2025: CHF 5,000 / year
  /// 2026: CHF 4,500 / year
  /// ```
  ///
  /// `getBudgetedByPeriod(BudgetPeriod.yearly)` returns `Leisure` once.
  ///
  /// This query does not determine whether a matching rule is effective on the
  /// current date.
  ///
  /// Returns an empty list when no category contains a budget rule using
  /// [period].
  Future<Result<List<Category>, CategoryFailure>> getBudgetedByPeriod(
    BudgetPeriod period,
  );

  /// Returns persisted categories whose name contains [query].
  ///
  /// Matching is case-insensitive and based on a substring of the category
  /// name.
  ///
  /// For example:
  ///
  /// ```text
  /// "ocer" → "Groceries"
  /// ```
  ///
  /// The search applies to both top-level and child categories.
  ///
  /// Returns an empty list when no categories match.
  Future<Result<List<Category>, CategoryFailure>> search(String query);

  /// Replaces the persisted snapshot of [category].
  ///
  /// The supplied entity represents the complete new snapshot. Changes to
  /// individual properties such as:
  ///
  /// - name;
  /// - parent;
  /// - kind;
  /// - budget rules;
  /// - icon;
  /// - color; or
  /// - sort order;
  ///
  /// are therefore persisted through this single operation.
  ///
  /// For example, adding or changing budget history should be performed by
  /// creating an updated category, typically through `copyWith`, and passing
  /// it to this method.
  ///
  /// Fails with [CategoryNotFoundFailure] when the category does not exist.
  ///
  /// Fails with [CategoryAlreadyDeletedFailure] when [category] is deleted.
  ///
  /// Cross-category hierarchy validation must be performed before calling this
  /// method when [Category.parentCategoryId] or [Category.kind] changes.
  Future<Result<void, CategoryFailure>> update(Category category);

  /// Physically removes the category identified by [id].
  ///
  /// Fails with [CategoryNotFoundFailure] when the category does not exist.
  ///
  /// Returns the removed snapshot with [Category.deletedAt] set to the
  /// deletion time.
  ///
  /// The repository does not retain that deleted snapshot. A caller that wants
  /// to offer undo or restoration must retain it and later pass it to
  /// [restore].
  ///
  /// Before calling this method, the coordinating operation must determine
  /// whether deletion is allowed.
  ///
  /// In particular, deletion may need to be rejected when:
  ///
  /// - transactions reference the category; or
  /// - child categories reference the category as their parent.
  Future<Result<Category, CategoryFailure>> delete(CategoryId id);

  /// Restores the caller-retained deleted [category].
  ///
  /// On success, an active copy of [category] is stored with
  /// [Category.deletedAt] set to `null`.
  ///
  /// Fails with [CategoryAlreadyActiveFailure] when [category] is already
  /// active.
  ///
  /// Fails with [CategoryAlreadyExistsFailure] when its identity already exists
  /// in persistence.
  ///
  /// When restoring a child category, the caller must validate that:
  ///
  /// - its parent still exists;
  /// - its parent is active;
  /// - its parent is still top-level; and
  /// - the parent-child relationship remains valid.
  ///
  /// Those cross-category checks occur before calling this repository method.
  Future<Result<void, CategoryFailure>> restore(Category category);
}
