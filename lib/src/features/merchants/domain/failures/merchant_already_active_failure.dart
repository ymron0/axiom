import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'merchant_already_active_failure.mapper.dart';

/// Indicates that a merchant is already active.
@MappableClass()
final class MerchantAlreadyActiveFailure
    extends Failure<MerchantAlreadyActiveFailure>
    with MerchantAlreadyActiveFailureMappable
    implements MerchantFailure {
  /// Creates a merchant-already-active failure with optional details.
  const MerchantAlreadyActiveFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'merchants.merchantAlreadyActive';

  @override
  MerchantAlreadyActiveFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
