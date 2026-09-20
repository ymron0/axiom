import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record.dart';
import 'package:axiom/src/core/persistence/persistence_operation_guard.dart';
import 'package:axiom/src/core/persistence/sembast_stores.dart';
import 'package:axiom/src/core/ports/clock/clock_factory.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/categories/data/models/category_persistence_model.dart';
import 'package:axiom/src/features/categories/domain/entities/category.dart';
import 'package:axiom/src/features/categories/domain/enums/budget_period.dart';
import 'package:axiom/src/features/categories/domain/enums/category_kind.dart';
import 'package:axiom/src/features/categories/domain/failures/category_already_active_failure.dart';
import 'package:axiom/src/features/categories/domain/failures/category_already_archived_failure.dart';
import 'package:axiom/src/features/categories/domain/failures/category_already_deleted_failure.dart';
import 'package:axiom/src/features/categories/domain/failures/category_already_exists_failure.dart';
import 'package:axiom/src/features/categories/domain/failures/category_failure.dart';
import 'package:axiom/src/features/categories/domain/failures/category_not_archived_failure.dart';
import 'package:axiom/src/features/categories/domain/failures/category_not_found_failure.dart';
import 'package:axiom/src/features/categories/domain/failures/category_repository_failure.dart';
import 'package:axiom/src/features/categories/domain/repositories/category_repository.dart';
import 'package:sembast/sembast.dart';

/// Persists categories in the Sembast categories store.
///
/// The repository implements the storage-independent [CategoryRepository]
/// contract while keeping Sembast-specific details inside the data layer.
///
/// ## Identity
///
/// [Category.id] is used directly as the Sembast record key.
///
/// Category identity is therefore not duplicated inside the record value.
///
/// ## Hierarchy
///
/// Parent-child relationships are persisted through
/// [Category.parentCategoryId].
///
/// Cross-category hierarchy validation deliberately remains outside this
/// repository. Operations coordinating category relationships must validate
/// parent existence, hierarchy depth, archive state, and kind compatibility
/// before persistence.
///
/// ## Budgets
///
/// Category budget history is embedded in the owning category record.
///
/// Budget queries operate on reconstructed category snapshots. No separate
/// budget store exists.
///
/// ## Deleted categories
///
/// Category deletion is physical.
///
/// Deleted snapshots are returned to the caller but are not retained in
/// Sembast. Restoration requires the caller-retained deleted snapshot.
///
/// ## Archived categories
///
/// Archived categories remain persisted.
///
/// Archiving or unarchiving a category also transitions every directly
/// persisted child category in the same Sembast transaction.
///
/// Children already in the requested state are preserved.
///
/// ## Transactions
///
/// Operations requiring read-before-write consistency use Sembast transactions,
/// so validation and mutation are atomic with respect to this store.
///
/// ## Failure translation
///
/// Expected persistence infrastructure exceptions and malformed persisted
/// records are translated to [CategoryRepositoryFailure] through
/// [guardPersistenceOperation].
///
/// Domain failures remain explicit typed result values.
///
/// Programmer errors and violated internal assumptions deliberately propagate.
final class SembastCategoryRepositoryImpl implements CategoryRepository {
  static final StoreRef<String, PersistenceRecord> _store =
      SembastStores.categories;

  final Database _database;

  /// Creates a category repository backed by an already-open and validated
  /// [database].
  ///
  /// Database lifecycle ownership remains outside this repository.
  ///
  /// This repository never opens or closes the supplied database.
  // ignore: prefer_initializing_formals
  SembastCategoryRepositoryImpl({required Database database})
    : _database = database; // ignore: prefer_initializing_formals

  @override
  Future<Result<Category, CategoryFailure>> archive(
    CategoryId id,
    DateTime archivedAt,
  ) => guardPersistenceOperation<Category, CategoryFailure>(
    operation: () => _database.transaction((transaction) async {
      final rootRecord = _store.record(id.value);
      final persistedRoot = await rootRecord.get(transaction);

      if (persistedRoot == null) {
        return CategoryNotFoundFailure(
          message: 'Category ID was not found: ${id.value}',
        );
      }

      final category = _categoryFromRecord(
        recordKey: id.value,
        record: persistedRoot,
      );

      if (category.isArchived) {
        return CategoryAlreadyArchivedFailure(
          message: 'Category is already archived: ${id.value}',
        );
      }

      final archivedCategory = _withArchivedAt(
        category,
        archivedAt: archivedAt,
        modifiedAt: archivedAt,
      );

      await rootRecord.put(
        transaction,
        CategoryPersistenceModel.fromEntity(archivedCategory).toRecord(),
      );

      final childSnapshots = await _store.find(
        transaction,
        finder: Finder(
          filter: Filter.equals(
            CategoryPersistenceModel.parentCategoryIdField,
            id.value,
          ),
        ),
      );

      for (final childSnapshot in childSnapshots) {
        // The requested category itself should never be one of its own
        // children. Skipping the key prevents duplicate processing even if
        // invalid cross-category state has previously been stored.
        if (childSnapshot.key == id.value) {
          continue;
        }

        final child = _categoryFromSnapshot(childSnapshot);

        if (child.isArchived) {
          continue;
        }

        final archivedChild = _withArchivedAt(
          child,
          archivedAt: archivedAt,
          modifiedAt: archivedAt,
        );

        await _store
            .record(child.id.value)
            .put(
              transaction,
              CategoryPersistenceModel.fromEntity(archivedChild).toRecord(),
            );
      }

      return Success(archivedCategory);
    }),
    persistenceFailure: _persistenceFailure,
    failureMessage: 'Unable to archive the category.',
  );

  @override
  Future<Result<void, CategoryFailure>> create(Category category) {
    if (category.isDeleted) {
      return Future.value(
        CategoryAlreadyDeletedFailure(
          message: 'Deleted category cannot be created: ${category.id.value}',
        ),
      );
    }

    if (category.isArchived) {
      return Future.value(
        CategoryAlreadyArchivedFailure(
          message: 'Archived category cannot be created: ${category.id.value}',
        ),
      );
    }

    return guardPersistenceOperation<void, CategoryFailure>(
      operation: () => _database.transaction((transaction) async {
        final record = _store.record(category.id.value);
        final existingRecord = await record.get(transaction);

        if (existingRecord != null) {
          return CategoryAlreadyExistsFailure(
            message: 'Category ID already exists: ${category.id.value}',
          );
        }

        final model = CategoryPersistenceModel.fromEntity(category);

        await record.put(transaction, model.toRecord());

        return const Success(null);
      }),
      persistenceFailure: _persistenceFailure,
      failureMessage: 'Unable to create the category.',
    );
  }

  @override
  Future<Result<Category, CategoryFailure>> delete(CategoryId id) =>
      guardPersistenceOperation<Category, CategoryFailure>(
        operation: () => _database.transaction((transaction) async {
          final record = _store.record(id.value);
          final persistedRecord = await record.get(transaction);

          if (persistedRecord == null) {
            return CategoryNotFoundFailure(
              message: 'Category ID was not found: ${id.value}',
            );
          }

          final category = _categoryFromRecord(
            recordKey: id.value,
            record: persistedRecord,
          );

          final deletedCategory = _withDeletedAt(category, createClock().now);

          await record.delete(transaction);

          return Success(deletedCategory);
        }),
        persistenceFailure: _persistenceFailure,
        failureMessage: 'Unable to delete the category.',
      );

  @override
  Future<Result<List<Category>, CategoryFailure>> getActive() =>
      guardPersistenceOperation<List<Category>, CategoryFailure>(
        operation: () async {
          final categories = await _loadAllCategories(_database);

          final activeCategories = categories
              .where((category) => !category.isArchived)
              .toList(growable: false);

          return Success(List<Category>.unmodifiable(activeCategories));
        },
        persistenceFailure: _persistenceFailure,
        failureMessage: 'Unable to load the active categories.',
      );

  @override
  Future<Result<List<Category>, CategoryFailure>> getAll() =>
      guardPersistenceOperation<List<Category>, CategoryFailure>(
        operation: () async {
          final categories = await _loadAllCategories(_database);

          return Success(List<Category>.unmodifiable(categories));
        },
        persistenceFailure: _persistenceFailure,
        failureMessage: 'Unable to load the categories.',
      );

  @override
  Future<Result<List<Category>, CategoryFailure>> getArchived() =>
      guardPersistenceOperation<List<Category>, CategoryFailure>(
        operation: () async {
          final categories = await _loadAllCategories(_database);

          final archivedCategories = categories
              .where((category) => category.isArchived)
              .toList(growable: false);

          return Success(List<Category>.unmodifiable(archivedCategories));
        },
        persistenceFailure: _persistenceFailure,
        failureMessage: 'Unable to load the archived categories.',
      );

  @override
  Future<Result<List<Category>, CategoryFailure>> getBudgeted() =>
      guardPersistenceOperation<List<Category>, CategoryFailure>(
        operation: () async {
          final categories = await _loadAllCategories(_database);

          final budgetedCategories = categories
              .where((category) => category.hasBudget)
              .toList(growable: false);

          return Success(List<Category>.unmodifiable(budgetedCategories));
        },
        persistenceFailure: _persistenceFailure,
        failureMessage: 'Unable to load budgeted categories.',
      );

  @override
  Future<Result<List<Category>, CategoryFailure>> getBudgetedByPeriod(
    BudgetPeriod period,
  ) => guardPersistenceOperation<List<Category>, CategoryFailure>(
    operation: () async {
      final categories = await _loadAllCategories(_database);

      final matches = categories
          .where(
            (category) =>
                category.budgets.any((budget) => budget.period == period),
          )
          .toList(growable: false);

      return Success(List<Category>.unmodifiable(matches));
    },
    persistenceFailure: _persistenceFailure,
    failureMessage: 'Unable to load categories by budget period.',
  );

  @override
  Future<Result<Category?, CategoryFailure>> getById(CategoryId id) =>
      guardPersistenceOperation<Category?, CategoryFailure>(
        operation: () async {
          final record = await _store.record(id.value).get(_database);

          if (record == null) {
            return const Success(null);
          }

          return Success(
            _categoryFromRecord(recordKey: id.value, record: record),
          );
        },
        persistenceFailure: _persistenceFailure,
        failureMessage: 'Unable to load the category by ID.',
      );

  @override
  Future<Result<List<Category>, CategoryFailure>> getByKind(
    CategoryKind kind,
  ) => guardPersistenceOperation<List<Category>, CategoryFailure>(
    operation: () async {
      final snapshots = await _store.find(
        _database,
        finder: Finder(
          filter: Filter.equals(CategoryPersistenceModel.kindField, kind.name),
        ),
      );

      final categories = snapshots
          .map(_categoryFromSnapshot)
          .toList(growable: false);

      return Success(List<Category>.unmodifiable(categories));
    },
    persistenceFailure: _persistenceFailure,
    failureMessage: 'Unable to load categories by kind.',
  );

  @override
  Future<Result<List<Category>, CategoryFailure>> getByParentId(
    CategoryId parentId,
  ) => guardPersistenceOperation<List<Category>, CategoryFailure>(
    operation: () async {
      final snapshots = await _store.find(
        _database,
        finder: Finder(
          filter: Filter.equals(
            CategoryPersistenceModel.parentCategoryIdField,
            parentId.value,
          ),
        ),
      );

      final categories = snapshots
          .map(_categoryFromSnapshot)
          .toList(growable: false);

      return Success(List<Category>.unmodifiable(categories));
    },
    persistenceFailure: _persistenceFailure,
    failureMessage: 'Unable to load categories by parent ID.',
  );

  @override
  Future<Result<void, CategoryFailure>> restore(Category category) {
    if (!category.isDeleted) {
      return Future.value(
        CategoryAlreadyActiveFailure(
          message: 'Category is already active: ${category.id.value}',
        ),
      );
    }

    return guardPersistenceOperation<void, CategoryFailure>(
      operation: () => _database.transaction((transaction) async {
        final record = _store.record(category.id.value);
        final existingRecord = await record.get(transaction);

        if (existingRecord != null) {
          return CategoryAlreadyExistsFailure(
            message: 'Category ID already exists: ${category.id.value}',
          );
        }

        final restoredCategory = _withDeletedAt(category, null);
        final model = CategoryPersistenceModel.fromEntity(restoredCategory);

        await record.put(transaction, model.toRecord());

        return const Success(null);
      }),
      persistenceFailure: _persistenceFailure,
      failureMessage: 'Unable to restore the category.',
    );
  }

  @override
  Future<Result<List<Category>, CategoryFailure>> search(String query) =>
      guardPersistenceOperation<List<Category>, CategoryFailure>(
        operation: () async {
          final categories = await _loadAllCategories(_database);
          final normalizedQuery = query.toLowerCase();

          final matches = categories
              .where(
                (category) =>
                    category.name.toLowerCase().contains(normalizedQuery),
              )
              .toList(growable: false);

          return Success(List<Category>.unmodifiable(matches));
        },
        persistenceFailure: _persistenceFailure,
        failureMessage: 'Unable to search categories.',
      );

  @override
  Future<Result<Category, CategoryFailure>> unarchive(
    CategoryId id,
    DateTime modifiedAt,
  ) => guardPersistenceOperation<Category, CategoryFailure>(
    operation: () => _database.transaction((transaction) async {
      final rootRecord = _store.record(id.value);
      final persistedRoot = await rootRecord.get(transaction);

      if (persistedRoot == null) {
        return CategoryNotFoundFailure(
          message: 'Category ID was not found: ${id.value}',
        );
      }

      final category = _categoryFromRecord(
        recordKey: id.value,
        record: persistedRoot,
      );

      if (!category.isArchived) {
        return CategoryNotArchivedFailure(
          message: 'Category is not archived: ${id.value}',
        );
      }

      final unarchivedCategory = _withArchivedAt(
        category,
        archivedAt: null,
        modifiedAt: modifiedAt,
      );

      await rootRecord.put(
        transaction,
        CategoryPersistenceModel.fromEntity(unarchivedCategory).toRecord(),
      );

      final childSnapshots = await _store.find(
        transaction,
        finder: Finder(
          filter: Filter.equals(
            CategoryPersistenceModel.parentCategoryIdField,
            id.value,
          ),
        ),
      );

      for (final childSnapshot in childSnapshots) {
        if (childSnapshot.key == id.value) {
          continue;
        }

        final child = _categoryFromSnapshot(childSnapshot);

        if (!child.isArchived) {
          continue;
        }

        final unarchivedChild = _withArchivedAt(
          child,
          archivedAt: null,
          modifiedAt: modifiedAt,
        );

        await _store
            .record(child.id.value)
            .put(
              transaction,
              CategoryPersistenceModel.fromEntity(unarchivedChild).toRecord(),
            );
      }

      return Success(unarchivedCategory);
    }),
    persistenceFailure: _persistenceFailure,
    failureMessage: 'Unable to unarchive the category.',
  );

  @override
  Future<Result<void, CategoryFailure>> update(Category category) {
    if (category.isDeleted) {
      return Future.value(
        CategoryAlreadyDeletedFailure(
          message: 'Deleted category cannot be updated: ${category.id.value}',
        ),
      );
    }

    return guardPersistenceOperation<void, CategoryFailure>(
      operation: () => _database.transaction((transaction) async {
        final record = _store.record(category.id.value);
        final existingRecord = await record.get(transaction);

        if (existingRecord == null) {
          return CategoryNotFoundFailure(
            message: 'Category ID was not found: ${category.id.value}',
          );
        }

        final model = CategoryPersistenceModel.fromEntity(category);

        await record.put(transaction, model.toRecord());

        return const Success(null);
      }),
      persistenceFailure: _persistenceFailure,
      failureMessage: 'Unable to update the category.',
    );
  }

  /// Reconstructs a category from a persisted record key and value.
  static Category _categoryFromRecord({
    required String recordKey,
    required PersistenceRecord record,
  }) {
    return CategoryPersistenceModel.fromRecord(
      recordKey: recordKey,
      record: record,
    ).toEntity();
  }

  /// Reconstructs a category from a Sembast record snapshot.
  static Category _categoryFromSnapshot(
    RecordSnapshot<String, PersistenceRecord> snapshot,
  ) {
    return _categoryFromRecord(recordKey: snapshot.key, record: snapshot.value);
  }

  /// Loads and reconstructs every persisted category.
  ///
  /// Any malformed persisted category or nested budget produces
  /// `PersistenceRecordException`, which the public persistence-operation guard
  /// translates into [CategoryRepositoryFailure].
  static Future<List<Category>> _loadAllCategories(
    DatabaseClient databaseClient,
  ) async {
    final snapshots = await _store.find(databaseClient);

    return snapshots.map(_categoryFromSnapshot).toList(growable: false);
  }

  /// Creates the feature-specific failure returned when persistence
  /// infrastructure cannot complete an operation.
  static CategoryRepositoryFailure _persistenceFailure(String message) {
    return CategoryRepositoryFailure(message: message);
  }

  /// Creates a category snapshot differing in archive state and modification
  /// timestamp.
  static Category _withArchivedAt(
    Category category, {
    required DateTime? archivedAt,
    required DateTime modifiedAt,
  }) {
    return Category(
      id: category.id,
      name: category.name,
      parentCategoryId: category.parentCategoryId,
      kind: category.kind,
      budgets: category.budgets,
      icon: category.icon,
      color: category.color,
      sortOrder: category.sortOrder,
      archivedAt: archivedAt,
      deletedAt: category.deletedAt,
      createdAt: category.createdAt,
      modifiedAt: modifiedAt,
      entityVersion: category.entityVersion,
    );
  }

  /// Creates a category snapshot differing only in deletion state.
  ///
  /// Physical deletion does not alter [Category.modifiedAt]. The deletion
  /// timestamp is retained only on the caller-visible deleted snapshot.
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
      archivedAt: category.archivedAt,
      deletedAt: deletedAt,
      createdAt: category.createdAt,
      modifiedAt: category.modifiedAt,
      entityVersion: category.entityVersion,
    );
  }
}
