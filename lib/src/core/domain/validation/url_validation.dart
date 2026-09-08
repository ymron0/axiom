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
