import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'merchant_already_archived_failure.mapper.dart';

/// Indicates that a merchant is already archived.
@MappableClass()
final class MerchantAlreadyArchivedFailure
    extends Failure<MerchantAlreadyArchivedFailure>
    with MerchantAlreadyArchivedFailureMappable
    implements MerchantFailure {
  /// Creates a merchant-already-archived failure.
  const MerchantAlreadyArchivedFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'merchants.merchantAlreadyArchived';

  @override
  MerchantAlreadyArchivedFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
