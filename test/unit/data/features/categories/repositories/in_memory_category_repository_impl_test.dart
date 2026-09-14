@Tags(['data'])
library;

import 'package:axiom/src/core/domain/enums/entity_color.dart';
import 'package:axiom/src/core/domain/enums/entity_icon.dart';
import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/features/assets/domain/enums/asset_amount_direction.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/categories/data/repositories/in_memory_category_repository_impl.dart';
import 'package:axiom/src/features/categories/domain/entities/category.dart';
import 'package:axiom/src/features/categories/domain/enums/budget_period.dart';
import 'package:axiom/src/features/categories/domain/enums/category_kind.dart';
import 'package:axiom/src/features/categories/domain/failures/category_already_active_failure.dart';
import 'package:axiom/src/features/categories/domain/failures/category_already_deleted_failure.dart';
import 'package:axiom/src/features/categories/domain/failures/category_already_exists_failure.dart';
import 'package:axiom/src/features/categories/domain/failures/category_not_found_failure.dart';
import 'package:axiom/src/features/categories/domain/value_objects/category_budget.dart';
import 'package:decimal/decimal.dart';
import 'package:fixtures/fixtures.dart';
import 'package:fixtures/types/categories.dart';
import 'package:test/test.dart';

void main() {
  group('InMemoryCategoryRepositoryImpl', () {
    group('constructor', () {
      test('rejects a deleted initial category', () {
        // Given
        final deleted = _category(
          id: 'seed-deleted',
          deletedAt: DateTime.utc(2026, 1, 2),
        );

        // When / Then
        expect(
          () => InMemoryCategoryRepositoryImpl(
            initialCategories: [deleted],
          ),
          throwsArgumentError,
        );
      });

      test('rejects duplicate initial category IDs', () {
        // Given
        final first = _category(id: 'seed-duplicate');
        final duplicate = _category(id: first.id.value, name: 'Duplicate');

        // When / Then
        expect(
          () => InMemoryCategoryRepositoryImpl(
            initialCategories: [first, duplicate],
          ),
          throwsArgumentError,
        );
      });

      test('loads non-deleted category fixtures by default, including archived', () async {
        // Given
        final repository = InMemoryCategoryRepositoryImpl();

        // When
        final result = await repository.getAll();

        // Then
        expect(
          result.valueOrNull?.map((category) => category.id.value).toList(),
          [
            'category-household',
            'category-groceries',
            'category-salary',
            'category-archived',
          ],
        );
      });

      test('maps a fixture budget with an effective end date', () async {
        // Given
        const fixtureId = 'category-test-ended-budget';
        categoriesFixtures.add(
          CategoryFixture(
            id: fixtureId,
            name: 'Ended budget',
            kind: 'expense',
            budgets: [
              CategoryBudgetFixture(
                assetId: 'asset-chf',
                limit: '100',
                direction: 'outgoing',
                period: 'monthly',
                effectiveFrom: DateTime.utc(2026, 1, 1),
                effectiveUntil: DateTime.utc(2026, 2, 1),
              ),
            ],
            icon: 'other',
            color: 'grey',
            sortOrder: 0,
            createdAt: DateTime.utc(2026, 1, 1),
            modifiedAt: DateTime.utc(2026, 1, 1),
            entityVersion: 1,
          ),
        );

        try {
          // When
          final repository = InMemoryCategoryRepositoryImpl();
          final result = await repository.getById(
            CategoryId.fromString(fixtureId),
          );

          // Then
          final budget = result.valueOrNull?.budgetAt(
            CalendarDate(2026, 1, 31),
          );
          expect(budget, isNotNull);
          expect(budget?.limit.assetId, AssetId.fromString('asset-chf'));
          expect(budget?.limit.amount, Decimal.parse('100'));
          expect(budget?.limit.isOutgoing, isTrue);
          expect(
            result.valueOrNull?.budgetAt(CalendarDate(2026, 2, 1)),
            isNull,
          );
        } finally {
          categoriesFixtures.removeWhere((fixture) => fixture.id == fixtureId);
        }
      });
    });

    group('create', () {
      test('stores an active category', () async {
        // Given
        final repository = InMemoryCategoryRepositoryImpl(
          initialCategories: <Category>[],
        );
        final category = _category(id: 'create-category');

        // When
        final result = await repository.create(category);

        // Then
        expect(result.isSuccess, isTrue);
        expect(
          (await repository.getById(category.id)).valueOrNull,
          same(category),
        );
      });

      test('rejects an existing category without replacing it', () async {
        // Given
        final repository = InMemoryCategoryRepositoryImpl(
          initialCategories: <Category>[],
        );
        final original = _category(id: 'create-duplicate');
        final duplicate = _category(id: original.id.value, name: 'Duplicate');
        await repository.create(original);

        // When
        final result = await repository.create(duplicate);

        // Then
        expect(result.failureOrNull, isA<CategoryAlreadyExistsFailure>());
        expect(
          (await repository.getById(original.id)).valueOrNull,
          same(original),
        );
      });

      test('rejects a deleted category', () async {
        // Given
        final repository = InMemoryCategoryRepositoryImpl(
          initialCategories: <Category>[],
        );
        final deleted = _category(
          id: 'create-deleted',
          deletedAt: DateTime.utc(2026, 1, 2),
        );

        // When
        final result = await repository.create(deleted);

        // Then
        expect(result.failureOrNull, isA<CategoryAlreadyDeletedFailure>());
        expect((await repository.getById(deleted.id)).valueOrNull, isNull);
      });
    });

    group('lookups', () {
      test('returns categories in insertion order', () async {
        // Given
        final repository = InMemoryCategoryRepositoryImpl(
          initialCategories: <Category>[],
        );
        final first = _category(id: 'lookup-first');
        final second = _category(id: 'lookup-second');
        await repository.create(second);
        await repository.create(first);

        // When
        final result = await repository.getAll();

        // Then
        expect(result.valueOrNull, [same(second), same(first)]);
      });

      test('returns a category or null by ID', () async {
        // Given
        final repository = InMemoryCategoryRepositoryImpl(
          initialCategories: <Category>[],
        );
        final category = _category(id: 'lookup-by-id');
        await repository.create(category);

        // When
        final found = await repository.getById(category.id);
        final missing = await repository.getById(
          CategoryId.fromString('missing'),
        );

        // Then
        expect(found.valueOrNull, same(category));
        expect(missing.valueOrNull, isNull);
      });

      test('filters categories by parent and kind', () async {
        // Given
        final repository = InMemoryCategoryRepositoryImpl(
          initialCategories: <Category>[],
        );
        final parent = _category(id: 'parent');
        final child = _category(id: 'child', parentId: parent.id);
        final income = _category(id: 'income', kind: CategoryKind.income);
        await repository.create(parent);
        await repository.create(child);
        await repository.create(income);

        // When
        final children = await repository.getByParentId(parent.id);
        final expenses = await repository.getByKind(CategoryKind.expense);

        // Then
        expect(children.valueOrNull, [same(child)]);
        expect(expenses.valueOrNull, [same(parent), same(child)]);
      });

      test('filters budgeted categories by existence and period', () async {
        // Given
        final repository = InMemoryCategoryRepositoryImpl(
          initialCategories: <Category>[],
        );
        final monthly = _category(
          id: 'monthly',
          budgets: [_budget(BudgetPeriod.monthly)],
        );
        final yearly = _category(
          id: 'yearly',
          budgets: [_budget(BudgetPeriod.yearly)],
        );
        final unbudgeted = _category(id: 'unbudgeted');
        await repository.create(monthly);
        await repository.create(yearly);
        await repository.create(unbudgeted);

        // When
        final budgeted = await repository.getBudgeted();
        final monthlyBudgeted = await repository.getBudgetedByPeriod(
          BudgetPeriod.monthly,
        );

        // Then
        expect(budgeted.valueOrNull, [same(monthly), same(yearly)]);
        expect(monthlyBudgeted.valueOrNull, [same(monthly)]);
      });

      test('searches names case-insensitively by substring', () async {
        // Given
        final repository = InMemoryCategoryRepositoryImpl(
          initialCategories: <Category>[],
        );
        final groceries = _category(id: 'groceries', name: 'Groceries');
        final transport = _category(id: 'transport', name: 'Transport');
        await repository.create(groceries);
        await repository.create(transport);

        // When
        final result = await repository.search('OcEr');

        // Then
        expect(result.valueOrNull, [same(groceries)]);
      });
    });

    group('update', () {
      test('replaces an existing active category', () async {
        // Given
        final repository = InMemoryCategoryRepositoryImpl(
          initialCategories: <Category>[],
        );
        final original = _category(id: 'update-category');
        final replacement = _category(
          id: original.id.value,
          name: 'Updated category',
          entityVersion: original.entityVersion,
        );
        await repository.create(original);

        // When
        final result = await repository.update(replacement);

        // Then
        expect(result.isSuccess, isTrue);
        expect(
          (await repository.getById(original.id)).valueOrNull,
          same(replacement),
        );
      });

      test('rejects a missing or deleted category without mutation', () async {
        // Given
        final repository = InMemoryCategoryRepositoryImpl(
          initialCategories: <Category>[],
        );
        final original = _category(id: 'update-original');
        final deleted = _category(
          id: original.id.value,
          deletedAt: DateTime.utc(2026, 1, 2),
        );
        await repository.create(original);

        // When
        final missingResult = await repository.update(_category(id: 'missing'));
        final deletedResult = await repository.update(deleted);

        // Then
        expect(missingResult.failureOrNull, isA<CategoryNotFoundFailure>());
        expect(
          deletedResult.failureOrNull,
          isA<CategoryAlreadyDeletedFailure>(),
        );
        expect(
          (await repository.getById(original.id)).valueOrNull,
          same(original),
        );
      });
    });

    group('archival', () {
      test('archives a parent and every direct child', () async {
        // Given
        final repository = InMemoryCategoryRepositoryImpl(
          initialCategories: <Category>[],
        );
        final parent = _category(id: 'parent');
        final child = _category(id: 'child', parentId: parent.id);
        final other = _category(id: 'other');
        final archivedAt = DateTime.utc(2026, 1, 2);
        await repository.create(parent);
        await repository.create(child);
        await repository.create(other);

        // When
        final result = await repository.archive(parent.id, archivedAt);

        // Then
        expect(result.valueOrNull?.id, parent.id);
        expect((await repository.getById(parent.id)).valueOrNull?.archivedAt, archivedAt);
        expect((await repository.getById(child.id)).valueOrNull?.archivedAt, archivedAt);
        expect((await repository.getById(other.id)).valueOrNull?.isArchived, isFalse);
      });

      test('unarchives a parent and every direct child', () async {
        // Given
        final archivedAt = DateTime.utc(2026, 1, 2);
        final parent = _category(
          id: 'parent',
          archivedAt: archivedAt,
          modifiedAt: archivedAt,
        );
        final child = _category(
          id: 'child',
          parentId: parent.id,
          archivedAt: archivedAt,
          modifiedAt: archivedAt,
        );
        final repository = InMemoryCategoryRepositoryImpl(
          initialCategories: [parent, child],
        );
        final unarchivedAt = DateTime.utc(2026, 1, 3);

        // When
        final result = await repository.unarchive(parent.id, unarchivedAt);

        // Then
        expect(result.valueOrNull?.archivedAt, isNull);
        expect((await repository.getById(child.id)).valueOrNull?.archivedAt, isNull);
        expect((await repository.getById(parent.id)).valueOrNull?.modifiedAt, unarchivedAt);
        expect((await repository.getById(child.id)).valueOrNull?.modifiedAt, unarchivedAt);
      });
    });

    group('delete and restore', () {
      test('removes a category and returns its deleted snapshot', () async {
        // Given
        final repository = InMemoryCategoryRepositoryImpl(
          initialCategories: <Category>[],
        );
        final category = _category(id: 'delete-category');
        await repository.create(category);

        // When
        final result = await repository.delete(category.id);

        // Then
        expect(result.valueOrNull?.isDeleted, isTrue);
        expect(result.valueOrNull?.id, category.id);
        expect((await repository.getById(category.id)).valueOrNull, isNull);
      });

      test('returns CategoryNotFoundFailure for a missing category', () async {
        // Given
        final repository = InMemoryCategoryRepositoryImpl(
          initialCategories: <Category>[],
        );

        // When
        final result = await repository.delete(
          CategoryId.fromString('missing'),
        );

        // Then
        expect(result.failureOrNull, isA<CategoryNotFoundFailure>());
      });

      test('restores a deleted category as active', () async {
        // Given
        final repository = InMemoryCategoryRepositoryImpl(
          initialCategories: <Category>[],
        );
        final category = _category(id: 'restore-category', entityVersion: 3);
        await repository.create(category);
        final deleted = (await repository.delete(category.id)).valueOrNull!;

        // When
        final result = await repository.restore(deleted);

        // Then
        final restored = (await repository.getById(category.id)).valueOrNull;
        expect(result.isSuccess, isTrue);
        expect(restored?.isDeleted, isFalse);
        expect(restored?.entityVersion, 3);
      });

      test('rejects active and duplicate deleted categories', () async {
        // Given
        final repository = InMemoryCategoryRepositoryImpl(
          initialCategories: <Category>[],
        );
        final active = _category(id: 'restore-active');
        final deletedWithSameId = _category(
          id: active.id.value,
          deletedAt: DateTime.utc(2026, 1, 2),
        );
        await repository.create(active);

        // When
        final activeResult = await repository.restore(active);
        final duplicateResult = await repository.restore(deletedWithSameId);

        // Then
        expect(activeResult.failureOrNull, isA<CategoryAlreadyActiveFailure>());
        expect(
          duplicateResult.failureOrNull,
          isA<CategoryAlreadyExistsFailure>(),
        );
        expect((await repository.getById(active.id)).valueOrNull, same(active));
      });
    });
  });
}

Category _category({
  required String id,
  String name = 'Category',
  CategoryId? parentId,
  CategoryKind kind = CategoryKind.expense,
  List<CategoryBudget> budgets = const [],
  DateTime? archivedAt,
  DateTime? deletedAt,
  DateTime? modifiedAt,
  int entityVersion = 1,
}) {
  final createdAt = DateTime.utc(2026, 1, 1);
  return Category(
    id: CategoryId.fromString(id),
    name: name,
    parentCategoryId: parentId,
    kind: kind,
    budgets: budgets,
    icon: EntityIcon.other,
    color: EntityColor.blue,
    sortOrder: 0,
    archivedAt: archivedAt,
    deletedAt: deletedAt,
    createdAt: createdAt,
    modifiedAt: modifiedAt ?? createdAt,
    entityVersion: entityVersion,
  );
}

CategoryBudget _budget(BudgetPeriod period) {
  return CategoryBudget(
    limit: AssetAmount(
      assetId: AssetId.fromString('asset-chf'),
      amount: Decimal.parse('100'),
      direction: AssetAmountDirection.outgoing,
    ),
    period: period,
    effectiveFrom: CalendarDate(2026, 1, 1),
  );
}
