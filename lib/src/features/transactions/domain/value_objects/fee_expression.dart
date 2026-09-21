import 'package:axiom/src/core/domain/mappers/decimal_mapper.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:dart_mappable/dart_mappable.dart';
import 'package:decimal/decimal.dart';

part 'asset_amount_fee_expression.dart';
part 'fee_expression.mapper.dart';
part 'percentage_fee_expression.dart';

/// Describes how a transaction fee was originally expressed.
///
/// A fee may be expressed either:
///
/// - directly as an [AssetAmount]; or
/// - as a percentage.
///
/// The fee expression preserves the user's original input. It is not the
/// authoritative accounting impact of the fee.
///
/// Resolved accounting values remain stored on the fee's `LedgerEntry` as its
/// transaction, account, and valuation amounts.
@MappableClass(discriminatorKey: 'type')
sealed class FeeExpression with FeeExpressionMappable {
  /// Creates a fee expression.
  const FeeExpression();
}
