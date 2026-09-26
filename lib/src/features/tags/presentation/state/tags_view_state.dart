/// Presentation-only filters for tag management.
final class TagsViewState {
  final String searchQuery;
  final bool includeArchived;

  const TagsViewState({this.searchQuery = '', this.includeArchived = false});

  TagsViewState copyWith({String? searchQuery, bool? includeArchived}) {
    return TagsViewState(
      searchQuery: searchQuery ?? this.searchQuery,
      includeArchived: includeArchived ?? this.includeArchived,
    );
  }
}
