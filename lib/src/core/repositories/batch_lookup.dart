/// Contains the items found by a batch lookup and the requested keys that
/// were not found.
///
/// Example:
/// ```dart
/// final lookup = BatchLookup<String, String>(
///   found: ['asset-1'],
///   missing: ['asset-2'],
/// );
/// ```
final class BatchLookup<T extends Object, K extends Object> {
  /// Creates an immutable batch lookup.
  ///
  /// The [found] and [missing] collections are copied and exposed as
  /// unmodifiable lists.
  BatchLookup({required List<T> found, required List<K> missing})
    : found = List.unmodifiable(found),
      missing = List.unmodifiable(missing);

  /// Items found for the requested keys.
  final List<T> found;

  /// Requested keys for which no item was found.
  final List<K> missing;
}
