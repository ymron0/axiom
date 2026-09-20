@Tags(['data', 'persistence'])
library;

import 'package:axiom/src/core/domain/enums/entity_color.dart';
import 'package:axiom/src/core/domain/enums/entity_icon.dart';
import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/persistence/sembast_stores.dart';
import 'package:axiom/src/features/assets/domain/enums/asset_amount_direction.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/categories/data/repositories/sembast_category_repository_impl.dart';
import 'package:axiom/src/features/categories/domain/entities/category.dart';
import 'package:axiom/src/features/categories/domain/enums/budget_period.dart';
import 'package:axiom/src/features/categories/domain/enums/category_kind.dart';
import 'package:axiom/src/features/categories/domain/failures/category_already_active_failure.dart';
import 'package:axiom/src/features/categories/domain/failures/category_already_archived_failure.dart';
import 'package:axiom/src/features/categories/domain/failures/category_already_deleted_failure.dart';
import 'package:axiom/src/features/categories/domain/failures/category_already_exists_failure.dart';
import 'package:axiom/src/features/categories/domain/failures/category_not_archived_failure.dart';
import 'package:axiom/src/features/categories/domain/failures/category_not_found_failure.dart';
import 'package:axiom/src/features/categories/domain/failures/category_repository_failure.dart';
import 'package:axiom/src/features/categories/domain/repositories/category_repository.dart';
import 'package:axiom/src/features/categories/domain/value_objects/category_budget.dart';
import 'package:decimal/decimal.dart';
import 'package:sembast/sembast.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/core/persistence/persistence_test_environment.dart';

void main() {
  late Database database;
  late CategoryRepository repository;

  final archivedAt = DateTime.utc(2026, 1, 2);
  final modifiedAt = DateTime.utc(2026, 1, 3);
  final deletedAt = DateTime.utc(2026, 1, 4);

  setUp(() async {
    final sembastDatabase = await createTestSembastDatabase();
    database = await sembastDatabase.open();

    repository = SembastCategoryRepositoryImpl(database: database);
  });

  group('SembastCategoryRepositoryImpl', () {
    group('create', () {
      test('persists an active category', () async {
        // Given
        final category = _category(id: 'create', name: 'Groceries');

        // When
        final result = await repository.create(category);

        // Then
        expect(result.isSuccess, isTrue);

        final stored = (await repository.getById(category.id)).valueOrNull;

        expect(stored?.id, category.id);
        expect(stored?.name, 'Groceries');
      });

      test('returns typed failures for invalid create states', () async {
        // Given
        final active = _category(id: 'active-create');
        await repository.create(active);

        // When
        final duplicate = await repository.create(
          _category(id: active.id.value, name: 'Duplicate'),
        );
        final archived = await repository.create(
          _category(id: 'archived-create', archivedAt: archivedAt),
        );
        final deleted = await repository.create(
          _category(id: 'deleted-create', deletedAt: deletedAt),
        );

        // Then
        expect(duplicate.failureOrNull, isA<CategoryAlreadyExistsFailure>());
        expect(archived.failureOrNull, isA<CategoryAlreadyArchivedFailure>());
        expect(deleted.failureOrNull, isA<CategoryAlreadyDeletedFailure>());
      });
    });

    group('queries', () {
      test('returns all categories in an immutable list', () async {
        // Given
        final first = _category(id: 'all-first');
        final second = _category(id: 'all-second');

        await repository.create(second);
        await repository.create(first);

        // When
        final categories = (await repository.getAll()).valueOrNull!;

        // Then
        expect(
          categories.map((category) => category.id),
          unorderedEquals([first.id, second.id]),
        );
        expect(() => categories.clear(), throwsUnsupportedError);
      });

      test('returns successful null for a missing ID', () async {
        // When
        final result = await repository.getById(
          CategoryId.fromString('missing'),
        );

        // Then
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull, isNull);
      });

      test('filters by direct parent', () async {
        // Given
        final parent = _category(id: 'parent');
        final firstChild = _category(id: 'child-first', parentId: parent.id);
        final secondChild = _category(id: 'child-second', parentId: parent.id);
        final unrelated = _category(id: 'unrelated');

        await repository.create(parent);
        await repository.create(firstChild);
        await repository.create(unrelated);
        await repository.create(secondChild);

        // When
        final categories = (await repository.getByParentId(
          parent.id,
        )).valueOrNull!;

        // Then
        expect(
          categories.map((category) => category.id),
          unorderedEquals([firstChild.id, secondChild.id]),
        );
        expect(() => categories.clear(), throwsUnsupportedError);
      });

      test('filters by category kind', () async {
        // Given
        final expense = _category(
          id: 'kind-expense',
          kind: CategoryKind.expense,
        );
        final income = _category(id: 'kind-income', kind: CategoryKind.income);

        await repository.create(expense);
        await repository.create(income);

        // When
        final categories = (await repository.getByKind(
          CategoryKind.expense,
        )).valueOrNull!;

        // Then
        expect(categories.map((category) => category.id), [expense.id]);
        expect(() => categories.clear(), throwsUnsupportedError);
      });

      test('returns categories with any budget history', () async {
        // Given
        final monthly = _category(
          id: 'budget-monthly',
          budgets: [_budget(BudgetPeriod.monthly)],
        );
        final yearly = _category(
          id: 'budget-yearly',
          budgets: [_budget(BudgetPeriod.yearly)],
        );
        final none = _category(id: 'budget-none');

        await repository.create(monthly);
        await repository.create(yearly);
        await repository.create(none);

        // When
        final categories = (await repository.getBudgeted()).valueOrNull!;

        // Then
        expect(
          categories.map((category) => category.id),
          unorderedEquals([monthly.id, yearly.id]),
        );
        expect(() => categories.clear(), throwsUnsupportedError);
      });

      test('filters budgeted categories by period', () async {
        // Given
        final monthly = _category(
          id: 'period-monthly',
          budgets: [_budget(BudgetPeriod.monthly)],
        );
        final yearly = _category(
          id: 'period-yearly',
          budgets: [_budget(BudgetPeriod.yearly)],
        );

        await repository.create(monthly);
        await repository.create(yearly);

        // When
        final categories = (await repository.getBudgetedByPeriod(
          BudgetPeriod.monthly,
        )).valueOrNull!;

        // Then
        expect(categories.map((category) => category.id), [monthly.id]);
        expect(() => categories.clear(), throwsUnsupportedError);
      });

      test('searches names case-insensitively by substring', () async {
        // Given
        final groceries = _category(id: 'search-groceries', name: 'Groceries');
        final transport = _category(id: 'search-transport', name: 'Transport');

        await repository.create(groceries);
        await repository.create(transport);

        // When
        final categories = (await repository.search('OcEr')).valueOrNull!;

        // Then
        expect(categories.map((category) => category.id), [groceries.id]);
        expect(() => categories.clear(), throwsUnsupportedError);
      });

      test('separates active and archived categories', () async {
        // Given
        final active = _category(id: 'active-query');
        final archived = _category(id: 'archived-query');

        await repository.create(active);
        await repository.create(archived);
        await repository.archive(archived.id, archivedAt);

        // When
        final activeResults = (await repository.getActive()).valueOrNull!;
        final archivedResults = (await repository.getArchived()).valueOrNull!;

        // Then
        expect(activeResults.map((category) => category.id), [active.id]);
        expect(archivedResults.map((category) => category.id), [archived.id]);

        expect(() => activeResults.clear(), throwsUnsupportedError);
        expect(() => archivedResults.clear(), throwsUnsupportedError);
      });
    });

    group('update', () {
      test('persists the complete replacement snapshot', () async {
        // Given
        final original = _category(id: 'update', name: 'Original');
        final replacement = _category(
          id: original.id.value,
          name: 'Updated',
          budgets: [_budget(BudgetPeriod.monthly)],
          modifiedAt: modifiedAt,
        );

        await repository.create(original);

        // When
        final result = await repository.update(replacement);

        // Then
        expect(result.isSuccess, isTrue);

        final stored = (await repository.getById(original.id)).valueOrNull!;

        expect(stored.name, 'Updated');
        expect(stored.budgets, hasLength(1));
        expect(stored.budgets.single.period, BudgetPeriod.monthly);
      });

      test('returns typed failures for missing and deleted category', () async {
        // Given
        final original = _category(id: 'update-original');
        await repository.create(original);

        // When
        final missing = await repository.update(
          _category(id: 'update-missing'),
        );
        final deleted = await repository.update(
          _category(id: original.id.value, deletedAt: deletedAt),
        );

        // Then
        expect(missing.failureOrNull, isA<CategoryNotFoundFailure>());
        expect(deleted.failureOrNull, isA<CategoryAlreadyDeletedFailure>());
      });
    });

    group('hierarchical archival', () {
      test('archives a category and every direct child atomically', () async {
        // Given
        final parent = _category(id: 'archive-parent');
        final firstChild = _category(
          id: 'archive-child-first',
          parentId: parent.id,
        );
        final secondChild = _category(
          id: 'archive-child-second',
          parentId: parent.id,
        );
        final unrelated = _category(id: 'archive-unrelated');

        await repository.create(parent);
        await repository.create(firstChild);
        await repository.create(secondChild);
        await repository.create(unrelated);

        // When
        final result = await repository.archive(parent.id, archivedAt);

        // Then
        expect(result.isSuccess, isTrue);

        expect(
          (await repository.getById(parent.id)).valueOrNull?.archivedAt,
          archivedAt,
        );
        expect(
          (await repository.getById(firstChild.id)).valueOrNull?.archivedAt,
          archivedAt,
        );
        expect(
          (await repository.getById(secondChild.id)).valueOrNull?.archivedAt,
          archivedAt,
        );
        expect(
          (await repository.getById(unrelated.id)).valueOrNull?.archivedAt,
          isNull,
        );
      });

      test('unarchives a category and every direct child', () async {
        // Given
        final parent = _category(id: 'unarchive-parent');
        final child = _category(id: 'unarchive-child', parentId: parent.id);

        await repository.create(parent);
        await repository.create(child);
        await repository.archive(parent.id, archivedAt);

        // When
        final result = await repository.unarchive(parent.id, modifiedAt);

        // Then
        expect(result.isSuccess, isTrue);

        final storedParent = (await repository.getById(parent.id)).valueOrNull!;
        final storedChild = (await repository.getById(child.id)).valueOrNull!;

        expect(storedParent.archivedAt, isNull);
        expect(storedChild.archivedAt, isNull);
        expect(storedParent.modifiedAt, modifiedAt);
        expect(storedChild.modifiedAt, modifiedAt);
      });

      test('returns typed failures for invalid transitions', () async {
        // Given
        final category = _category(id: 'transition');
        await repository.create(category);

        // When
        final missingArchive = await repository.archive(
          CategoryId.fromString('archive-missing'),
          archivedAt,
        );

        await repository.archive(category.id, archivedAt);

        final alreadyArchived = await repository.archive(
          category.id,
          archivedAt,
        );

        await repository.unarchive(category.id, modifiedAt);

        final notArchived = await repository.unarchive(category.id, modifiedAt);

        // Then
        expect(missingArchive.failureOrNull, isA<CategoryNotFoundFailure>());
        expect(
          alreadyArchived.failureOrNull,
          isA<CategoryAlreadyArchivedFailure>(),
        );
        expect(notArchived.failureOrNull, isA<CategoryNotArchivedFailure>());
      });
    });

    group('delete and restore', () {
      test('physically deletes and restores a category', () async {
        // Given
        final category = _category(id: 'delete-restore');
        await repository.create(category);

        // When
        final deleteResult = await repository.delete(category.id);

        // Then
        final deleted = deleteResult.valueOrNull!;

        expect(deleted.deletedAt, isNotNull);
        expect((await repository.getById(category.id)).valueOrNull, isNull);

        // When
        final restoreResult = await repository.restore(deleted);

        // Then
        expect(restoreResult.isSuccess, isTrue);
        expect(
          (await repository.getById(category.id)).valueOrNull?.deletedAt,
          isNull,
        );
      });

      test('returns typed delete and restore failures', () async {
        // Given
        final active = _category(id: 'restore-active');
        await repository.create(active);

        final duplicateDeleted = _category(
          id: active.id.value,
          deletedAt: deletedAt,
        );

        // When
        final missingDelete = await repository.delete(
          CategoryId.fromString('delete-missing'),
        );
        final activeRestore = await repository.restore(active);
        final duplicateRestore = await repository.restore(duplicateDeleted);

        // Then
        expect(missingDelete.failureOrNull, isA<CategoryNotFoundFailure>());
        expect(
          activeRestore.failureOrNull,
          isA<CategoryAlreadyActiveFailure>(),
        );
        expect(
          duplicateRestore.failureOrNull,
          isA<CategoryAlreadyExistsFailure>(),
        );
      });
    });

    test('translates malformed persisted category to typed failure', () async {
      // Given
      const id = 'corrupt-category';

      await SembastStores.categories
          .record(id)
          .put(database, <String, Object?>{});

      // When
      final result = await repository.getById(CategoryId.fromString(id));

      // Then
      expect(result.failureOrNull, isA<CategoryRepositoryFailure>());
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
    modifiedAt: modifiedAt ?? archivedAt ?? createdAt,
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
