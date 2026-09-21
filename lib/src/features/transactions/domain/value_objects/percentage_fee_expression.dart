part of 'fee_expression.dart';

/// A fee expressed as a percentage.
///
/// Percentage values use percentage units:
///
/// - `1` means 1%;
/// - `0.25` means 0.25%;
/// - `12.5` means 12.5%.
@MappableClass(
  discriminatorValue: 'percentage',
  includeCustomMappers: [DecimalMapper()],
)
final class PercentageFeeExpression extends FeeExpression
    with PercentageFeeExpressionMappable {
  /// Percentage originally entered by the user.
  final Decimal percentage;

  /// Creates a percentage fee expression.
  PercentageFeeExpression({required this.percentage}) {
    if (percentage <= Decimal.zero) {
      throw ArgumentError.value(
        percentage,
        'percentage',
        'Fee percentage must be greater than zero.',
      );
    }
  }
}
