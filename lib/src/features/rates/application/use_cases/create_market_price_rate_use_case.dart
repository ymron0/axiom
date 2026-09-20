import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/ports/clock/clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/rates/application/commands/create_market_price_rate_command.dart';
import 'package:axiom/src/features/rates/application/services/create_rate_service.dart';
import 'package:axiom/src/features/rates/domain/entities/rate.dart';

/// Creates and persists a [MarketPriceRate] from application input.
///
/// The use case delegates entity construction to the domain factory and
/// persistence to [CreateRateService], returning the created rate on success
/// or the service failure unchanged.
final class CreateMarketPriceRateUseCase {
  final CreateRateService _createRate;
  final Clock _clock;

  /// Creates the use case.
  const CreateMarketPriceRateUseCase({
    required CreateRateService createRate,
    required Clock clock,
  }) : _createRate = createRate, // ignore: prefer_initializing_formals
       _clock = clock; // ignore: prefer_initializing_formals

  /// Creates and persists a market price from [command].
  Future<Result<MarketPriceRate, BaseFailure>> call(
    CreateMarketPriceRateCommand command,
  ) async {
    final marketPriceRate = MarketPriceRate.create(
      baseAssetId: command.baseAssetId,
      quoteAssetId: command.quoteAssetId,
      rate: command.rate,
      effectiveAt: command.effectiveAt,
      clock: _clock,
    );

    final result = await _createRate(marketPriceRate);

    return result.when<Result<MarketPriceRate, BaseFailure>>(
      success: (_) => Success(marketPriceRate),
      failure: (failure) => failure,
    );
  }
}
