import 'package:axiom/src/core/identity/ids/category_id.dart';

import '../../../../core/domain/enums/entity_color.dart';
import '../../../../core/domain/enums/entity_icon.dart';
import '../../domain/entities/category.dart';
import '../../domain/enums/category_kind.dart';

/// Editable presentation snapshot for category creation and editing.
///
/// Domain objects are created only on submission.
final class CategoryFormState {
  final String name;
  final CategoryKind kind;
  final CategoryId? parentCategoryId;
  final EntityIcon icon;
  final EntityColor color;

  const CategoryFormState({
    required this.name,
    required this.kind,
    required this.parentCategoryId,
    required this.icon,
    required this.color,
  });

  factory CategoryFormState.create() {
    return const CategoryFormState(
      name: '',
      kind: CategoryKind.expense,
      parentCategoryId: null,
      icon: EntityIcon.payments,
      color: EntityColor.blue,
    );
  }

  factory CategoryFormState.fromCategory(Category category) {
    return CategoryFormState(
      name: category.name,
      kind: category.kind,
      parentCategoryId: category.parentCategoryId,
      icon: category.icon,
      color: category.color,
    );
  }

  bool get isNameValid => name.trim().isNotEmpty;

  bool get isValid => isNameValid;

  CategoryFormState copyWith({
    String? name,
    CategoryKind? kind,
    Object? parentCategoryId = _unsetParent,
    EntityIcon? icon,
    EntityColor? color,
  }) {
    return CategoryFormState(
      name: name ?? this.name,
      kind: kind ?? this.kind,
      parentCategoryId: identical(parentCategoryId, _unsetParent)
          ? this.parentCategoryId
          : parentCategoryId as CategoryId?,
      icon: icon ?? this.icon,
      color: color ?? this.color,
    );
  }
}

const Object _unsetParent = Object();
