import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'merchant_already_exists_failure.mapper.dart';

/// Indicates that a merchant conflicts with an existing merchant.
@MappableClass()
final class MerchantAlreadyExistsFailure
    extends Failure<MerchantAlreadyExistsFailure>
    with MerchantAlreadyExistsFailureMappable
    implements MerchantFailure {
  /// Creates a merchant-already-exists failure with optional details.
  const MerchantAlreadyExistsFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'merchants.merchantAlreadyExists';

  @override
  MerchantAlreadyExistsFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
