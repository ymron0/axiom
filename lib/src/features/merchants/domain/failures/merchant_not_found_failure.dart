import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'merchant_not_found_failure.mapper.dart';

/// Indicates that an expected merchant does not exist.
@MappableClass()
final class MerchantNotFoundFailure
    extends Failure<MerchantNotFoundFailure>
    with MerchantNotFoundFailureMappable
    implements MerchantFailure {
  /// Creates a merchant-not-found failure with optional details.
  const MerchantNotFoundFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'merchants.merchantNotFound';

  @override
  MerchantNotFoundFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
