import 'package:dart_mappable/dart_mappable.dart';
import 'package:decimal/decimal.dart';

/// Maps [Decimal] values to and from their exact string representation.
///
/// Decimal numbers are serialized as strings rather than floating-point
/// numbers to preserve their exact value across persistence boundaries.
///
/// For example, `Decimal.parse('10.05')` is serialized as:
///
/// ```json
/// "10.05"
/// ```
///
/// and never as a JSON floating-point value.
class DecimalMapper extends SimpleMapper<Decimal> {
  /// Creates a mapper for [Decimal] values.
  const DecimalMapper();

  @override
  Decimal decode(Object value) {
    return Decimal.parse(value as String);
  }

  @override
  Object encode(Decimal self) {
    return self.toString();
  }
}
