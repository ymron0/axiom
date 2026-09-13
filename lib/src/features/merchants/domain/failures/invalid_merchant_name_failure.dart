import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'invalid_merchant_name_failure.mapper.dart';

/// Indicates that a merchant name violates the merchant naming rules.
@MappableClass()
final class InvalidMerchantNameFailure
    extends Failure<InvalidMerchantNameFailure>
    with InvalidMerchantNameFailureMappable
    implements MerchantFailure {
  /// Creates a failure explaining why the merchant name is invalid.
  const InvalidMerchantNameFailure({required String message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'merchants.invalidMerchantName';

  @override
  InvalidMerchantNameFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
