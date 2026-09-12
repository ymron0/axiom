import 'package:axiom/src/core/domain/validation/text_validation.dart';

/// Returns whether [value] is an absolute HTTP(S) URL with a host.
bool isValidHttpUrl(String value) {
  final normalized = value.trim();

  if (normalized.isEmpty) {
    return false;
  }

  final uri = Uri.tryParse(normalized);

  return uri != null &&
      uri.host.isNotEmpty &&
      (uri.scheme == 'http' || uri.scheme == 'https');
}

/// Normalizes an optional absolute HTTP(S) URL for a domain object.
///
/// Returns `null` unchanged. Non-null values are trimmed, rejected when blank,
/// and required to have an HTTP(S) scheme and host.
///
/// Throws an [ArgumentError] when the supplied value is blank or is not an
/// absolute HTTP(S) URL. The [name] is used as the error's argument name.
String? normalizeOptionalHttpUrl(String? value, String name) {
  if (value == null) {
    return null;
  }

  final normalized = normalizeRequiredText(value, name);

  if (!isValidHttpUrl(normalized)) {
    throw ArgumentError.value(
      value,
      name,
      '$name must be an absolute HTTP(S) URL.',
    );
  }

  return normalized;
}
