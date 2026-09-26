import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'tags_view_state.dart';

part 'tags_view_controller.g.dart';

@riverpod
class TagsViewController extends _$TagsViewController {
  @override
  TagsViewState build() {
    return const TagsViewState();
  }

  void setSearchQuery(String value) {
    state = state.copyWith(searchQuery: value);
  }

  void setIncludeArchived(bool value) {
    state = state.copyWith(includeArchived: value);
  }
}
