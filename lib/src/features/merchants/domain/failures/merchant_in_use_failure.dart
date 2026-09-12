import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'merchant_in_use_failure.mapper.dart';

/// Indicates that a merchant is referenced by another record.
@MappableClass()
final class MerchantInUseFailure extends Failure<MerchantInUseFailure>
    with MerchantInUseFailureMappable
    implements MerchantFailure {
  /// Creates a merchant-in-use failure with optional details.
  const MerchantInUseFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'merchants.merchantInUse';

  @override
  MerchantInUseFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
