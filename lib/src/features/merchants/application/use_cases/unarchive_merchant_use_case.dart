import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/ports/clock/clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/merchants/domain/entities/merchant.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_failure.dart';
import 'package:axiom/src/features/merchants/domain/repositories/merchant_repository.dart';

/// Restores an archived merchant to normal use.
final class UnarchiveMerchantUseCase {
  /// Creates a use case with its repository and canonical time source.
  const UnarchiveMerchantUseCase({
    required MerchantRepository repository,
    required Clock clock,
  }) : _repository = repository, // ignore: prefer_initializing_formals
       _clock = clock; // ignore: prefer_initializing_formals

  final MerchantRepository _repository;
  final Clock _clock;

  /// Unarchives the merchant identified by [id].
  Future<Result<Merchant, MerchantFailure>> call(MerchantId id) {
    return _repository.unarchive(id, _clock.nowUtc);
  }
}
