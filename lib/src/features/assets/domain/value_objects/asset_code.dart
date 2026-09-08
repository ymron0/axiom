import 'package:dart_mappable/dart_mappable.dart';

part 'asset_code.mapper.dart';

/// A normalized, non-empty code identifying an asset.
///
/// Example:
/// ```dart
/// final code = AssetCode('EUR');
/// ```
@MappableClass()
class AssetCode with AssetCodeMappable {
  /// The asset code.
  final String value;

  // Creates an AssetCode after the public factory has validated its value.
  const AssetCode._(this.value);

  /// Creates an asset code from [value].
  ///
  /// Throws [ArgumentError] when the normalized value is empty.
  factory AssetCode(String value) {
    final normalized = value.trim();

    if (normalized.isEmpty) {
      throw ArgumentError('Asset code cannot be empty');
    }

    return AssetCode._(normalized);
  }

  /// Returns the normalized code value.
  @override
  String toString() => value;
}
