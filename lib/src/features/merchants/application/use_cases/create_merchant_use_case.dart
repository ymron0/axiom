import 'package:axiom/src/core/ports/clock/clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/merchants/domain/entities/merchant.dart';
import 'package:axiom/src/features/merchants/domain/failures/invalid_merchant_name_failure.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_failure.dart';
import 'package:axiom/src/features/merchants/domain/repositories/merchant_repository.dart';

/// Creates and persists a new active merchant.
final class CreateMerchantUseCase {
  /// Creates a use case with its repository and time source.
  const CreateMerchantUseCase({
    required MerchantRepository repository,
    required Clock clock,
  }) : _repository = repository, // ignore: prefer_initializing_formals
       _clock = clock; // ignore: prefer_initializing_formals

  final MerchantRepository _repository;
  final Clock _clock;

  /// Creates and persists a merchant with [name].
  ///
  /// Returns the created merchant on success, an [InvalidMerchantNameFailure]
  /// when [name] is invalid, or a repository [MerchantFailure].
  Future<Result<Merchant, MerchantFailure>> call(String name) async {
    final Merchant merchant;
    try {
      merchant = Merchant.create(name: name, clock: _clock);
    } on ArgumentError catch (error) {
      if (error.name != 'name') {
        rethrow;
      }

      return InvalidMerchantNameFailure(message: error.message.toString());
    }
    final createResult = await _repository.create(merchant);

    return createResult.when<Result<Merchant, MerchantFailure>>(
      success: (_) => Success(merchant),
      failure: (failure) => failure,
    );
  }
}
