import 'package:axiom/src/core/result/result.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'invalid_payment_asset_failure.mapper.dart';

/// Indicates that a transaction uses an asset that is not enabled for payments.
///
/// This does not mean the asset is globally unusable. The same asset may still
/// denominate an account or participate in an internal transfer.
@MappableClass()
final class InvalidPaymentAssetFailure
    extends Failure<InvalidPaymentAssetFailure>
    with InvalidPaymentAssetFailureMappable {
  /// Stable identifier for this failure kind.
  static const typeId = 'application.invalidPaymentAsset';

  /// Creates the failure.
  const InvalidPaymentAssetFailure({required String message}) : super(message);

  @override
  InvalidPaymentAssetFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
