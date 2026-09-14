import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'merchant_not_archived_failure.mapper.dart';

/// Indicates that an operation requiring an archived merchant received an
/// active merchant.
@MappableClass()
final class MerchantNotArchivedFailure extends Failure<MerchantNotArchivedFailure>
    with MerchantNotArchivedFailureMappable
    implements MerchantFailure {
  /// Creates a merchant-not-archived failure.
  const MerchantNotArchivedFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'merchants.merchantNotArchived';

  @override
  MerchantNotArchivedFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
