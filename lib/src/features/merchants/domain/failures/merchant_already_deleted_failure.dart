import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'merchant_already_deleted_failure.mapper.dart';

/// Indicates that a merchant is already marked as deleted.
@MappableClass()
final class MerchantAlreadyDeletedFailure
    extends Failure<MerchantAlreadyDeletedFailure>
    with MerchantAlreadyDeletedFailureMappable
    implements MerchantFailure {
  /// Creates a merchant-already-deleted failure with optional details.
  const MerchantAlreadyDeletedFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'merchants.merchantAlreadyDeleted';

  @override
  MerchantAlreadyDeletedFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
