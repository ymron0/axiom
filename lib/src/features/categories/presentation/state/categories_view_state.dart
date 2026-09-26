import '../../domain/enums/category_kind.dart';

/// Transient presentation state owned by the Categories overview.
///
/// ## Behavior
///
/// Repository/application data remains outside this object. This state owns
/// only view concerns such as search text and filtering.
final class CategoriesViewState {
  final String searchQuery;
  final CategoryKind? kind;
  final bool includeDeleted;

  const CategoriesViewState({
    this.searchQuery = '',
    this.kind,
    this.includeDeleted = false,
  });

  bool get hasFilters =>
      searchQuery.trim().isNotEmpty || kind != null || includeDeleted;

  CategoriesViewState copyWith({
    String? searchQuery,
    Object? kind = _unsetCategoryKind,
    bool? includeDeleted,
  }) {
    return CategoriesViewState(
      searchQuery: searchQuery ?? this.searchQuery,
      kind: identical(kind, _unsetCategoryKind)
          ? this.kind
          : kind as CategoryKind?,
      includeDeleted: includeDeleted ?? this.includeDeleted,
    );
  }
}

const Object _unsetCategoryKind = Object();
