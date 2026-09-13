import 'package:axiom/src/core/domain/enums/entity_color.dart';
import 'package:axiom/src/core/domain/enums/entity_icon.dart';
import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/features/categories/domain/enums/category_kind.dart';
import 'package:axiom/src/features/categories/domain/value_objects/category_budget.dart';

/// Input required to create and persist a new category.
///
/// Generated identity, version, audit metadata, and deletion state are
/// intentionally excluded.
final class CreateCategoryCommand {
  /// Creates a category creation command.
  const CreateCategoryCommand({
    required this.name,
    this.parentCategoryId,
    required this.kind,
    this.budgets = const [],
    required this.icon,
    required this.color,
    required this.sortOrder,
  });

  /// The category's human-readable name.
  final String name;

  /// The top-level parent, or `null` for a top-level category.
  final CategoryId? parentCategoryId;

  /// The category's financial nature.
  final CategoryKind kind;

  /// Historical, current, and future budget rules.
  final List<CategoryBudget> budgets;

  /// The category's semantic visual icon.
  final EntityIcon icon;

  /// The category's semantic visual color.
  final EntityColor color;

  /// The category's user-defined ordering position amongst its siblings.
  final int sortOrder;
}
