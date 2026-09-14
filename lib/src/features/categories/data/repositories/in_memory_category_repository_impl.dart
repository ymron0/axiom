import 'package:axiom/src/core/domain/enums/entity_color.dart';
import 'package:axiom/src/core/domain/enums/entity_icon.dart';
import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/ports/clock/clock_factory.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/domain/enums/asset_amount_direction.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/categories/domain/entities/category.dart';
import 'package:axiom/src/features/categories/domain/enums/budget_period.dart';
import 'package:axiom/src/features/categories/domain/enums/category_kind.dart';
import 'package:axiom/src/features/categories/domain/failures/category_already_active_failure.dart';
import 'package:axiom/src/features/categories/domain/failures/category_already_deleted_failure.dart';
import 'package:axiom/src/features/categories/domain/failures/category_already_exists_failure.dart';
import 'package:axiom/src/features/categories/domain/failures/category_failure.dart';
import 'package:axiom/src/features/categories/domain/failures/category_not_found_failure.dart';
import 'package:axiom/src/features/categories/domain/repositories/category_repository.dart';
import 'package:axiom/src/features/categories/domain/value_objects/category_budget.dart';
import 'package:decimal/decimal.dart';
import 'package:fixtures/fixtures.dart';
import 'package:fixtures/types/categories.dart';

/// Stores categories in memory.
final class InMemoryCategoryRepositoryImpl implements CategoryRepository {
  /// Creates a repository seeded with [initialCategories].
  ///
  /// When omitted, the repository loads the active external category
  /// fixtures. Throws [ArgumentError] when the seed contains deleted
  /// categories or duplicate IDs.
  InMemoryCategoryRepositoryImpl({Iterable<Category>? initialCategories})
    : _categories = _validatedSeed(
        initialCategories ??
            categoriesFixtures
                .where((fixture) => fixture.deletedAt == null)
                .map<Category>(_fromFixture)
                .toList(),
      );

  final Map<CategoryId, Category> _categories;

  static Map<CategoryId, Category> _validatedSeed(
    Iterable<Category> categories,
  ) {
    final result = <CategoryId, Category>{};

    for (final category in categories) {
      if (category.isDeleted) {
        throw ArgumentError(
          'Deleted category cannot be seeded: ${category.id.value}',
        );
      }
      if (result.containsKey(category.id)) {
        throw ArgumentError(
          'Category ID is duplicated: ${category.id.value}',
        );
      }
      result[category.id] = category;
    }

    return result;
  }

  @override
  Future<Result<void, CategoryFailure>> create(Category category) async {
    if (category.isDeleted) {
      return CategoryAlreadyDeletedFailure(
        message: 'Deleted category cannot be created: ${category.id.value}',
      );
    }
    if (_categories.containsKey(category.id)) {
      return CategoryAlreadyExistsFailure(
        message: 'Category ID already exists: ${category.id.value}',
      );
    }

    _categories[category.id] = category;
    return const Success(null);
  }

  @override
  Future<Result<Category, CategoryFailure>> delete(CategoryId id) async {
    final category = _categories.remove(id);
    if (category == null) {
      return _notFound(id);
    }

    return Success(_withDeletedAt(category, createClock().now));
  }

  @override
  Future<Result<List<Category>, CategoryFailure>> getAll() async {
    return Success(List.unmodifiable(_categories.values));
  }

  @override
  Future<Result<List<Category>, CategoryFailure>> getBudgeted() async {
    return Success(_matchingCategories((category) => category.hasBudget));
  }

  @override
  Future<Result<List<Category>, CategoryFailure>> getBudgetedByPeriod(
    BudgetPeriod period,
  ) async {
    return Success(
      _matchingCategories(
        (category) => category.budgets.any((budget) => budget.period == period),
      ),
    );
  }

  @override
  Future<Result<Category?, CategoryFailure>> getById(CategoryId id) async {
    return Success(_categories[id]);
  }

  @override
  Future<Result<List<Category>, CategoryFailure>> getByKind(
    CategoryKind kind,
  ) async {
    return Success(_matchingCategories((category) => category.kind == kind));
  }

  @override
  Future<Result<List<Category>, CategoryFailure>> getByParentId(
    CategoryId parentId,
  ) async {
    return Success(
      _matchingCategories(
        (category) => category.parentCategoryId == parentId,
      ),
    );
  }

  @override
  Future<Result<void, CategoryFailure>> restore(Category category) async {
    if (!category.isDeleted) {
      return CategoryAlreadyActiveFailure(
        message: 'Category is already active: ${category.id.value}',
      );
    }
    if (_categories.containsKey(category.id)) {
      return CategoryAlreadyExistsFailure(
        message: 'Category ID already exists: ${category.id.value}',
      );
    }

    _categories[category.id] = _withDeletedAt(category, null);
    return const Success(null);
  }

  @override
  Future<Result<List<Category>, CategoryFailure>> search(String query) async {
    final normalizedQuery = query.toLowerCase();
    return Success(
      _matchingCategories(
        (category) => category.name.toLowerCase().contains(normalizedQuery),
      ),
    );
  }

  @override
  Future<Result<void, CategoryFailure>> update(Category category) async {
    if (category.isDeleted) {
      return CategoryAlreadyDeletedFailure(
        message: 'Deleted category cannot be updated: ${category.id.value}',
      );
    }
    if (!_categories.containsKey(category.id)) {
      return _notFound(category.id);
    }

    _categories[category.id] = category;
    return const Success(null);
  }

  static CategoryNotFoundFailure _notFound(CategoryId id) {
    return CategoryNotFoundFailure(
      message: 'Category ID was not found: ${id.value}',
    );
  }

  List<Category> _matchingCategories(
    bool Function(Category category) matches,
  ) {
    return List.unmodifiable(_categories.values.where(matches));
  }

  static Category _fromFixture(CategoryFixture fixture) {
    return Category(
      id: CategoryId.fromString(fixture.id),
      name: fixture.name,
      parentCategoryId: fixture.parentCategoryId == null
          ? null
          : CategoryId.fromString(fixture.parentCategoryId!),
      kind: CategoryKind.values.byName(fixture.kind),
      budgets: fixture.budgets.map(_budgetFromFixture).toList(growable: false),
      icon: EntityIcon.values.byName(fixture.icon),
      color: EntityColor.values.byName(fixture.color),
      sortOrder: fixture.sortOrder,
      deletedAt: fixture.deletedAt,
      createdAt: fixture.createdAt,
      modifiedAt: fixture.modifiedAt,
      entityVersion: fixture.entityVersion,
    );
  }

  static CategoryBudget _budgetFromFixture(CategoryBudgetFixture fixture) {
    return CategoryBudget(
      limit: AssetAmount(
        assetId: AssetId.fromString(fixture.assetId),
        amount: Decimal.parse(fixture.limit),
        direction: AssetAmountDirection.values.byName(fixture.direction),
      ),
      period: BudgetPeriod.values.byName(fixture.period),
      effectiveFrom: CalendarDate.fromDateTime(fixture.effectiveFrom),
      effectiveUntil: fixture.effectiveUntil == null
          ? null
          : CalendarDate.fromDateTime(fixture.effectiveUntil!),
    );
  }

  static Category _withDeletedAt(Category category, DateTime? deletedAt) {
    return Category(
      id: category.id,
      name: category.name,
      parentCategoryId: category.parentCategoryId,
      kind: category.kind,
      budgets: category.budgets,
      icon: category.icon,
      color: category.color,
      sortOrder: category.sortOrder,
      deletedAt: deletedAt,
      createdAt: category.createdAt,
      modifiedAt: category.modifiedAt,
      entityVersion: category.entityVersion,
    );
  }
}
