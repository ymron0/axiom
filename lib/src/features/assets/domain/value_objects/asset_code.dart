import 'package:dart_mappable/dart_mappable.dart';

part 'asset_code.mapper.dart';

/// The canonical machine-readable code identifying an asset.
///
/// [AssetCode] is distinct from an asset's display name and symbol. Input is
/// trimmed before it is stored; casing is preserved because different asset
/// classes may use different code conventions.
///
/// ## Invariants
///
/// - [value] is non-empty and not solely whitespace.
/// - [value] is the supplied code with surrounding whitespace removed.
/// - The value is immutable after construction.
///
/// ## Semantics
///
/// Asset codes identify the domain code of an asset independently of its
/// display name, symbol, or local [AssetId]. Equality compares canonical code
/// values, so equivalent surrounding whitespace represents the same code while
/// casing differences remain meaningful.
///
/// ## Contract
///
/// Construction throws [ArgumentError] when the supplied value is blank. A
/// valid value is trimmed without changing its casing.
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
  /// Throws [ArgumentError] when the trimmed value is empty.
  factory AssetCode(String value) {
    final normalized = value.trim();

    if (normalized.isEmpty) {
      throw ArgumentError.value(value, 'value', 'Asset code cannot be blank.');
    }

    return AssetCode._(normalized);
  }

  /// Returns the normalized code value.
  @override
  String toString() => value;
}
