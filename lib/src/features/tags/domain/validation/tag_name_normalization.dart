/// Whitespace occurring inside a tag name.
final RegExp _tagWhitespacePattern = RegExp(r'\s+');

/// Normalizes a tag's display name.
///
/// Normalization:
///
/// - removes leading and trailing whitespace;
/// - collapses consecutive internal whitespace into one ASCII space; and
/// - preserves letter casing.
///
/// Examples:
///
/// ```text
/// "  Business   Trip " -> "Business Trip"
/// "tax"                -> "tax"
/// ```
///
/// Throws an [ArgumentError] when the normalized value is empty.
String normalizeTagName(String value) {
  final trimmed = value.trim();

  if (trimmed.isEmpty) {
    throw ArgumentError.value(value, 'name', 'Tag name cannot be blank.');
  }

  return trimmed.replaceAll(_tagWhitespacePattern, ' ');
}

/// Returns the canonical comparison key for a tag name.
///
/// Tag identity remains [TagId]-based, but tag names are unique using this
/// canonical representation.
///
/// Comparison is therefore insensitive to casing and insignificant whitespace.
///
/// Example:
///
/// ```text
/// "Business   Trip" -> "business trip"
/// " business trip " -> "business trip"
/// ```
String tagNameKey(String value) => normalizeTagName(value).toLowerCase();
