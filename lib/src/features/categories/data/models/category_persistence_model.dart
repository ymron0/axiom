import 'package:axiom/src/core/domain/enums/entity_color.dart';
import 'package:axiom/src/core/domain/enums/entity_icon.dart';
import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_exception.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_helpers.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_reader.dart';
import 'package:axiom/src/features/categories/data/models/category_budget_persistence_model.dart';
import 'package:axiom/src/features/categories/domain/entities/category.dart';
import 'package:axiom/src/features/categories/domain/enums/category_kind.dart';

/// Persistence representation of a [Category].
///
/// This model owns the translation boundary between the Categories domain and
/// the primitive representation stored by Sembast.
///
/// ## Identity
///
/// Category identity is represented by the Sembast record key.
///
/// [id] is therefore intentionally omitted from [toRecord], and [recordKey]
/// supplied to [fromRecord] is authoritative.
///
/// ## Hierarchy
///
/// [parentCategoryId] is persisted as a nullable string.
///
/// This model preserves the relationship but deliberately does not perform
/// cross-category hierarchy validation. Rules requiring another category to be
/// loaded belong outside the persistence model.
///
/// ## Budgets
///
/// Budget history is embedded directly in the category record as an ordered
/// list of [CategoryBudgetPersistenceModel] values.
///
/// Persisted budget order is preserved.
///
/// ## Lifecycle
///
/// Archived categories remain persisted.
///
/// Deleted categories do not. Deletion is physical in [CategoryRepository], so
/// a persisted record whose `deletedAt` value is non-null is considered invalid
/// persisted state.
///
/// ## Failure behavior
///
/// Malformed records are converted into [PersistenceRecordException].
///
/// Persistent repositories translate that internal exception into
/// `CategoryPersistenceFailure`.
final class CategoryPersistenceModel {
  /// Persisted category name.
  static const String nameField = 'name';

  /// Persisted parent-category identifier.
  ///
  /// Public because `CategoryRepository.getByParentId` queries this field
  /// directly.
  static const String parentCategoryIdField = 'parentCategoryId';

  /// Persisted category kind.
  ///
  /// Public because `CategoryRepository.getByKind` queries this field directly.
  static const String kindField = 'kind';

  /// Archive timestamp.
  static const String archivedAtField = 'archivedAt';

  /// Deletion timestamp.
  ///
  /// Valid persisted categories always contain `null` here.
  static const String deletedAtField = 'deletedAt';

  static const String _budgetsField = 'budgets';
  static const String _iconField = 'icon';
  static const String _colorField = 'color';
  static const String _sortOrderField = 'sortOrder';
  static const String _createdAtField = 'createdAt';
  static const String _modifiedAtField = 'modifiedAt';
  static const String _entityVersionField = 'entityVersion';

  /// Category identity represented by the Sembast record key.
  final String id;

  /// Human-readable category name.
  final String name;

  /// Optional parent-category identity.
  final String? parentCategoryId;

  /// Expense/income category kind.
  final CategoryKind kind;

  /// Effective-dated budget history.
  final List<CategoryBudgetPersistenceModel> budgets;

  /// Semantic icon identity.
  final EntityIcon icon;

  /// Semantic color identity.
  final EntityColor color;

  /// User-defined sibling ordering.
  final int sortOrder;

  /// Optional archive timestamp.
  final DateTime? archivedAt;

  /// Optional deletion timestamp.
  ///
  /// Must be `null` for valid persisted category records.
  final DateTime? deletedAt;

  /// UTC creation timestamp.
  final DateTime createdAt;

  /// UTC modification timestamp.
  final DateTime modifiedAt;

  /// Domain entity class version.
  final int entityVersion;

  CategoryPersistenceModel._({
    required this.id,
    required this.name,
    required this.parentCategoryId,
    required this.kind,
    required List<CategoryBudgetPersistenceModel> budgets,
    required this.icon,
    required this.color,
    required this.sortOrder,
    required this.archivedAt,
    required this.deletedAt,
    required this.createdAt,
    required this.modifiedAt,
    required this.entityVersion,
  }) : budgets = List<CategoryBudgetPersistenceModel>.unmodifiable(budgets);

  /// Creates a persistence model from an active or archived [category].
  ///
  /// Deleted categories cannot be persisted because deletion is physical.
  ///
  /// A deleted category reaching this layer is therefore a programming error
  /// rather than an expected persistence failure.
  factory CategoryPersistenceModel.fromEntity(Category category) {
    if (category.isDeleted) {
      throw StateError(
        'Deleted categories cannot be represented as persisted category '
        'records.',
      );
    }

    return CategoryPersistenceModel._(
      id: category.id.value,
      name: category.name,
      parentCategoryId: category.parentCategoryId?.value,
      kind: category.kind,
      budgets: category.budgets
          .map(CategoryBudgetPersistenceModel.fromEntity)
          .toList(growable: false),
      icon: category.icon,
      color: category.color,
      sortOrder: category.sortOrder,
      archivedAt: category.archivedAt?.toUtc(),
      deletedAt: null,
      createdAt: category.createdAt.toUtc(),
      modifiedAt: category.modifiedAt.toUtc(),
      entityVersion: category.entityVersion,
    );
  }

  /// Reconstructs a persistence model from a Sembast [record].
  ///
  /// [recordKey] is the authoritative persisted category identifier.
  ///
  /// Stored values are treated as untrusted input.
  factory CategoryPersistenceModel.fromRecord({
    required String recordKey,
    required PersistenceRecord record,
  }) {
    final reader = PersistenceRecordReader(record);
    final rawBudgets = reader.requiredList(_budgetsField);

    return CategoryPersistenceModel._(
      id: recordKey,
      name: reader.requiredString(nameField),
      parentCategoryId: reader.optionalString(parentCategoryIdField),
      kind: readPersistenceEnum(
        reader: reader,
        field: kindField,
        values: CategoryKind.values,
      ),
      budgets: <CategoryBudgetPersistenceModel>[
        for (var index = 0; index < rawBudgets.length; index++)
          CategoryBudgetPersistenceModel.fromRecord(
            persistenceRecordFromListValue(
              rawBudgets[index],
              field: '$_budgetsField[$index]',
            ),
            path: '$_budgetsField[$index]',
          ),
      ],
      icon: readPersistenceEnum(
        reader: reader,
        field: _iconField,
        values: EntityIcon.values,
      ),
      color: readPersistenceEnum(
        reader: reader,
        field: _colorField,
        values: EntityColor.values,
      ),
      sortOrder: reader.requiredInt(_sortOrderField),
      archivedAt: _readOptionalUtcDateTime(reader, archivedAtField),
      deletedAt: _readOptionalUtcDateTime(reader, deletedAtField),
      createdAt: readPersistenceDateTime(reader, _createdAtField),
      modifiedAt: readPersistenceDateTime(reader, _modifiedAtField),
      entityVersion: readPositivePersistenceInt(reader, _entityVersionField),
    );
  }

  /// Converts this model into its Sembast-compatible primitive record.
  ///
  /// [id] is omitted because it is represented by the Sembast record key.
  PersistenceRecord toRecord() {
    return <String, Object?>{
      nameField: name,
      parentCategoryIdField: parentCategoryId,
      kindField: kind.name,
      _budgetsField: budgets
          .map((budget) => budget.toRecord())
          .toList(growable: false),
      _iconField: icon.name,
      _colorField: color.name,
      _sortOrderField: sortOrder,
      archivedAtField: archivedAt?.toUtc().toIso8601String(),
      deletedAtField: deletedAt?.toUtc().toIso8601String(),
      _createdAtField: createdAt.toUtc().toIso8601String(),
      _modifiedAtField: modifiedAt.toUtc().toIso8601String(),
      _entityVersionField: entityVersion,
    };
  }

  /// Reconstructs the domain [Category] represented by this model.
  ///
  /// Current entity invariants are deliberately revalidated during
  /// reconstruction.
  ///
  /// Cross-category hierarchy validation remains outside this model because the
  /// referenced parent category is not available here.
  Category toEntity() {
    if (deletedAt != null) {
      throw const PersistenceRecordException(
        field: deletedAtField,
        reason:
            'Deleted categories must not remain in persistent category storage.',
      );
    }

    try {
      return Category(
        id: CategoryId.fromString(id),
        name: name,
        parentCategoryId: parentCategoryId == null
            ? null
            : CategoryId.fromString(parentCategoryId!),
        kind: kind,
        budgets: List.unmodifiable(
          budgets.map((budget) => budget.toEntity()).toList(growable: false),
        ),
        icon: icon,
        color: color,
        sortOrder: sortOrder,
        archivedAt: archivedAt,
        deletedAt: null,
        createdAt: createdAt,
        modifiedAt: modifiedAt,
        entityVersion: entityVersion,
      );
    } on PersistenceRecordException {
      rethrow;
    } on ArgumentError {
      throw const PersistenceRecordException(
        reason: 'Persisted category violates current domain invariants.',
      );
    // coverage:ignore-start
    } on FormatException {
      throw const PersistenceRecordException(
        reason: 'Persisted category contains an invalid domain value.',
      );
    }
    // coverage:ignore-end
  }

  /// Reads an optional UTC ISO-8601 timestamp.
  static DateTime? _readOptionalUtcDateTime(
    PersistenceRecordReader reader,
    String field,
  ) {
    final value = reader.optionalString(field);

    if (value == null) {
      return null;
    }

    try {
      final parsed = DateTime.parse(value);

      if (!parsed.isUtc) {
        throw const FormatException();
      }

      return parsed.toUtc();
    } on FormatException {
      throw PersistenceRecordException(
        field: field,
        reason: 'Expected a UTC ISO-8601 timestamp.',
      );
    }
  }
}
