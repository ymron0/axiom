import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/enums/category_kind.dart';
import 'categories_view_state.dart';

part 'categories_view_controller.g.dart';

/// Owns transient Categories overview controls.
@riverpod
class CategoriesViewController extends _$CategoriesViewController {
  @override
  CategoriesViewState build() {
    return const CategoriesViewState();
  }

  void setSearchQuery(String value) {
    state = state.copyWith(searchQuery: value);
  }

  void setKind(CategoryKind? value) {
    state = state.copyWith(kind: value);
  }

  void setIncludeDeleted(bool value) {
    state = state.copyWith(includeDeleted: value);
  }

  void clearFilters() {
    state = const CategoriesViewState();
  }
}
