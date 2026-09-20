import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'merchant_repository_failure.mapper.dart';

/// Indicates that a merchant repository operation could not complete.
@MappableClass()
final class MerchantRepositoryFailure extends Failure<MerchantRepositoryFailure>
    with MerchantRepositoryFailureMappable
    implements MerchantFailure {
  /// Creates a merchant repository failure with optional details.
  const MerchantRepositoryFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'merchants.repository';

  @override
  MerchantRepositoryFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
