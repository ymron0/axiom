import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/custodian_id.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:decimal/decimal.dart';

/// The current value of one account expressed in both its denomination asset
/// and the app's valuation currency.
///
/// [AccountValuation] is derived financial state. It is not persisted on the
/// account or custodian entity.
///
/// For example, an EUR-denominated account whose current value is EUR 1,000
/// and whose equivalent value in the app's CHF valuation currency is CHF 935
/// can be represented as:
///
/// ```text
/// accountAmount:     EUR 1,000 incoming
/// valuationAmount:   CHF   935 incoming
/// ```
///
/// A negative account position uses an outgoing [AssetAmount]:
///
/// ```text
/// accountAmount:     EUR 1,000 outgoing
/// valuationAmount:   CHF   935 outgoing
/// ```
///
/// ## Responsibilities
///
/// The application layer is responsible for:
///
/// 1. deriving the account's current balance;
/// 2. converting that balance into the app's valuation currency; and
/// 3. constructing this value.
///
/// This value object only validates that the two amounts can represent the
/// same financial position.
///
/// ## Invariants
///
/// - [accountAmount] must be known.
/// - [valuationAmount] must be known.
/// - zero in one representation requires zero in the other representation.
/// - non-zero amounts must have the same direction.
/// - when both amounts use the same asset, they must represent exactly the
///   same signed amount.
///
/// Cross-account invariants, such as ensuring that every account belongs to
/// the same custodian, are enforced by [CustodianAggregationCalculator].
final class AccountValuation {
  /// Creates an account valuation.
  ///
  /// Throws an [ArgumentError] when the two amounts cannot represent the same
  /// current financial position.
  AccountValuation({
    required this.accountId,
    required this.custodianId,
    required this.accountAmount,
    required this.valuationAmount,
  }) {
    _validateKnownAmounts();
    _validateZeroConsistency();
    _validateDirectionConsistency();
    _validateSameAssetConsistency();
  }

  /// The account represented by this valuation.
  final AccountId accountId;

  /// The custodian that owns the account.
  final CustodianId custodianId;

  /// The account's signed current balance in its denomination asset.
  ///
  /// Its [AssetAmount.assetId] should correspond to the account's
  /// `denominationAssetId`.
  ///
  /// Incoming represents a positive balance and outgoing represents a negative
  /// balance.
  final AssetAmount accountAmount;

  /// The account's signed current value in the app's valuation currency.
  ///
  /// Its [AssetAmount.assetId] identifies the valuation currency used for
  /// custodian and portfolio-level aggregation.
  ///
  /// Incoming represents a positive value and outgoing represents a negative
  /// value.
  final AssetAmount valuationAmount;

  /// Ensures that a current account valuation never contains an unknown amount.
  ///
  /// The `-1` sentinel supported by [AssetAmount] is useful for values that are
  /// legitimately unknown, such as some planned transaction amounts, but an
  /// account valuation must be concrete before it can participate in
  /// aggregation.
  void _validateKnownAmounts() {
    if (accountAmount.isUnknownAmount) {
      throw ArgumentError.value(
        accountAmount,
        'accountAmount',
        'Account valuation requires a known account amount.',
      );
    }

    if (valuationAmount.isUnknownAmount) {
      throw ArgumentError.value(
        valuationAmount,
        'valuationAmount',
        'Account valuation requires a known valuation amount.',
      );
    }
  }

  /// Ensures that zero is represented consistently in both currencies.
  ///
  /// A zero account balance cannot convert to a non-zero valuation, and a
  /// non-zero account balance cannot convert to zero at domain precision.
  void _validateZeroConsistency() {
    final accountIsZero = accountAmount.amount == Decimal.zero;
    final valuationIsZero = valuationAmount.amount == Decimal.zero;

    if (accountIsZero != valuationIsZero) {
      throw ArgumentError.value(
        valuationAmount,
        'valuationAmount',
        'Account and valuation amounts must either both be zero or both be '
            'non-zero.',
      );
    }
  }

  /// Ensures that currency conversion never changes the sign of the position.
  ///
  /// Directions on zero amounts are intentionally ignored because positive and
  /// negative zero are economically equivalent.
  void _validateDirectionConsistency() {
    if (accountAmount.amount == Decimal.zero) {
      return;
    }

    if (accountAmount.direction != valuationAmount.direction) {
      throw ArgumentError.value(
        valuationAmount,
        'valuationAmount',
        'Account and valuation amounts must have the same direction.',
      );
    }
  }

  /// Ensures that conversion is identity when both amounts use the same asset.
  ///
  /// When an account is already denominated in the app's valuation currency,
  /// its account and valuation amounts must represent the same signed value.
  void _validateSameAssetConsistency() {
    if (accountAmount.assetId != valuationAmount.assetId) {
      return;
    }

    if (!accountAmount.isEqualTo(valuationAmount)) {
      throw ArgumentError.value(
        valuationAmount,
        'valuationAmount',
        'Account and valuation amounts must be equal when they use the same '
            'asset.',
      );
    }
  }
}