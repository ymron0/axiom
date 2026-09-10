/// Normalizes optional text for domain objects.
///
/// Returns `null` unchanged. Non-null text is trimmed and rejected when the
/// result is empty.
///
/// Throws an [ArgumentError] when supplied text is blank after trimming. The
/// [name] is used as the error's argument name.
String? normalizeOptionalText(String? value, String name) {
  if (value == null) {
    return null;
  }

  final normalized = value.trim();

  if (normalized.isEmpty) {
    throw ArgumentError.value(value, name, '$name cannot be blank.');
  }

  return normalized;
}
