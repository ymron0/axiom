import 'package:axiom/src/core/domain/entities/base/audited_entity.dart';
import 'package:axiom/src/core/domain/enums/entity_color.dart';
import 'package:axiom/src/core/domain/enums/entity_icon.dart';
import 'package:axiom/src/core/domain/mixins/deletable.dart';
import 'package:axiom/src/core/domain/validation/text_validation.dart';
import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/ports/clock/clock.dart';
import 'package:axiom/src/core/ports/clock/clock_factory.dart';
import 'package:axiom/src/features/categories/domain/enums/category_kind.dart';
import 'package:axiom/src/features/categories/domain/value_objects/category_budget.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'category.mapper.dart';

/// A hierarchical classification used to categorize transaction allocations.
///
/// A category answers two related questions:
///
/// 1. **What was this transaction for?**
/// 2. **How much may be spent or received for this purpose?**
///
/// The first question is answered by the category itself. The second is
/// answered by [budget] when the category defines a financial limit.
///
/// ## Transaction classification
///
/// A transaction allocation references exactly one category.
///
/// For example:
///
/// ```text
/// Household
/// ├── Groceries
/// ├── Rent
/// └── Clothing
/// ```
///
/// A transaction at Migros may reference the `Groceries` category. That single
/// selection identifies both:
///
/// - the transaction classification: groceries; and
/// - the applicable budget rules for Groceries and its parent Household.
///
/// Transactions may also reference a top-level category directly. A transaction
/// classified directly as `Household` does not need to belong to a more
/// specific child category.
///
/// ## Hierarchy
///
/// Categories support two levels:
///
/// ```text
/// Top-level category
/// └── Child category
/// ```
///
/// A top-level category has no [parentCategoryId].
///
/// A child category references its top-level parent through [parentCategoryId].
///
/// Deeper hierarchies are not supported:
///
/// ```text
/// Household
/// └── Food
///     └── Groceries  // Invalid.
/// ```
///
/// The entity itself cannot verify that the referenced parent is top-level,
/// because it stores only the parent's identifier. That invariant must be
/// validated by the operation that creates or changes the relationship after
/// loading the parent category.
///
/// ## Category kind
///
/// [kind] determines whether the category represents expenses or income.
///
/// A child must have the same [kind] as its parent. This rule also requires the
/// parent category to be available and is therefore validated by the operation
/// that creates or changes the hierarchy.
///
/// ## Budgeting
///
/// [budget] is optional.
///
/// A category without its own budget may still contribute to a budget defined
/// by its parent.
///
/// For example:
///
/// ```text
/// Leisure — CHF 2,000 / year
/// ├── Holidays
/// └── Restaurants
/// ```
///
/// A CHF 1,800 transaction assigned to `Holidays` contributes CHF 1,800 to
/// `Leisure`. The remaining Leisure budget is therefore CHF 200, shared between
/// direct Leisure transactions, Holidays, and Restaurants.
///
/// A child may also have its own budget:
///
/// ```text
/// Household — CHF 2,500 / month
/// ├── Groceries — CHF 700 / month
/// ├── Rent
/// └── Clothing
/// ```
///
/// A CHF 100 Groceries transaction contributes:
///
/// - CHF 100 to the Groceries monthly budget; and
/// - CHF 100 to the Household monthly budget.
///
/// ## Visual identity
///
/// [color] and [icon] provide stable visual identity independently of the
/// presentation framework.
///
/// ## Ordering
///
/// [sortOrder] provides deterministic user-defined ordering amongst sibling
/// categories.
///
/// The value is meaningful within the category's current level. Top-level
/// categories are ordered against other top-level categories, while children
/// are ordered against siblings belonging to the same parent.
///
/// ## Derived data
///
/// The category deliberately stores no current spent amount, received amount,
/// remaining amount, percentage used, or budget status.
///
/// Those values depend on transactions and the requested period and are derived
/// from transaction splits.
///
/// Examples of derived values include:
///
/// ```text
/// spent
/// received
/// remaining
/// percentageUsed
/// isOverBudget
/// directTotal
/// aggregateTotal
/// ```
///
/// ## Invariants
///
/// Invariants enforced directly by this entity:
///
/// - [name] is trimmed and cannot be blank.
/// - [sortOrder] cannot be negative.
/// - [deletedAt], when present, cannot precede [createdAt].
/// - [modifiedAt] cannot precede [createdAt], as enforced by [AuditedEntity].
/// - [entityVersion] is greater than zero, as enforced by [AuditedEntity].
///
/// Hierarchy invariants that require loading the parent are enforced outside
/// this entity:
///
/// - the parent must exist;
/// - the parent must be active when assigning a new child;
/// - the parent must itself be top-level; and
/// - the child and parent must have the same [kind].
@MappableClass()
final class Category extends AuditedEntity<CategoryId>
    with Deletable, CategoryMappable {
  /// The human-readable category name.
  ///
  /// Examples include `Household`, `Groceries`, `Leisure`, and `Salary`.
  final String name;

  /// The parent of this category, when this is a child category.
  ///
  /// `null` means this is a top-level category.
  ///
  /// A non-null value means this is a child category. The referenced parent
  /// must itself be top-level.
  final CategoryId? parentCategoryId;

  /// The financial nature of this category.
  ///
  /// Expense categories classify money spent. Income categories classify money
  /// received.
  ///
  /// A child category must have the same kind as its parent.
  final CategoryKind kind;

  /// Historical and current budget rules defined for this category.
  ///
  /// The list may be empty when the category has no budget.
  ///
  /// Budget rules must not overlap. At most one rule may apply to any given
  /// calendar date.
  final List<CategoryBudget> budgets;

  /// The semantic icon identity assigned to this category.
  ///
  /// This is domain-level visual metadata rather than Flutter [IconData].
  final EntityIcon icon;

  /// The semantic color identity assigned to this category.
  final EntityColor color;

  /// The user-defined ordering position of this category amongst its siblings.
  ///
  /// Must be zero or greater.
  final int sortOrder;

  /// {@macro deletable.deleted_at}
  @override
  final DateTime? deletedAt;

  /// Creates a category.
  ///
  /// This constructor is used for persistence rehydration and for constructing
  /// an entity with an existing identity and audit information.
  ///
  /// [name] is normalized by trimming surrounding whitespace.
  ///
  /// Throws an [ArgumentError] when:
  ///
  /// - [name] is blank;
  /// - [sortOrder] is negative; or
  /// - [deletedAt] precedes [createdAt].
  ///
  /// Parent-dependent hierarchy rules cannot be validated by this constructor
  /// because only [parentCategoryId], rather than the parent entity, is
  /// available.
  @MappableConstructor()
  Category({
    required super.id,
    required String name,
    this.parentCategoryId,
    required this.kind,
    this.budgets = const [],
    required this.icon,
    required this.color,
    required this.sortOrder,
    this.deletedAt,
    required super.createdAt,
    required super.modifiedAt,
    required super.entityVersion,
  }) : name = normalizeRequiredText(name, 'name') {
    _validateBudgets();

    if (sortOrder < 0) {
      throw ArgumentError.value(
        sortOrder,
        'sortOrder',
        'Category sort order cannot be negative.',
      );
    }

    if (deletedAt?.isBefore(createdAt) ?? false) {
      throw ArgumentError.value(
        deletedAt,
        'deletedAt',
        'Deletion time cannot precede creation time.',
      );
    }
  }

  /// Creates a new category.
  ///
  /// Generates a new [CategoryId], initializes the entity at version `1`, and
  /// uses the same UTC timestamp for [createdAt] and [modifiedAt].
  ///
  /// Supplying [clock] allows deterministic creation in tests. Production code
  /// uses [createClock] when no clock is supplied.
  factory Category.create({
    required String name,
    CategoryId? parentCategoryId,
    required CategoryKind kind,
    List<CategoryBudget> budgets = const [],
    required EntityIcon icon,
    required EntityColor color,
    required int sortOrder,
    Clock? clock,
  }) {
    final resolvedClock = clock ?? createClock();
    final now = resolvedClock.nowUtc;

    return Category(
      id: CategoryId.generate(),
      name: name,
      parentCategoryId: parentCategoryId,
      kind: kind,
      budgets: budgets,
      icon: icon,
      color: color,
      sortOrder: sortOrder,
      createdAt: now,
      modifiedAt: now,
      entityVersion: 1,
    );
  }

  /// Whether this is a top-level category.
  ///
  /// A top-level category has no parent and may contain direct child
  /// categories.
  bool get isTopLevel => parentCategoryId == null;

  /// Whether this is a child category.
  ///
  /// Child categories cannot themselves contain children.
  bool get isChild => parentCategoryId != null;

  /// Whether this category defines at least one budget rule.
  ///
  /// This may include historical, current, or future budget rules.
  bool get hasBudget => budgets.isNotEmpty;

  /// Returns the budget rule effective on [date].
  ///
  /// Returns `null` when no budget is defined for that date.
  CategoryBudget? budgetAt(CalendarDate date) {
    for (final budget in budgets) {
      if (budget.appliesOn(date)) {
        return budget;
      }
    }

    return null;
  }

  void _validateBudgets() {
    final sorted = [...budgets]
      ..sort((a, b) => a.effectiveFrom.compareTo(b.effectiveFrom));

    for (var i = 1; i < sorted.length; i++) {
      final previous = sorted[i - 1];
      final current = sorted[i];

      if (previous.effectiveUntil == null) {
        throw ArgumentError(
          'An indefinite budget rule cannot be followed by another rule.',
        );
      }

      if (current.effectiveFrom.isBefore(previous.effectiveUntil!)) {
        throw ArgumentError('Category budget rules cannot overlap.');
      }
    }
  }
}
