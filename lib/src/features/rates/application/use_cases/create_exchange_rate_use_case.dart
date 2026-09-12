import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/ports/clock/clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/rates/application/commands/create_exchange_rate_command.dart';
import 'package:axiom/src/features/rates/application/services/create_rate_service.dart';
import 'package:axiom/src/features/rates/domain/entities/exchange_rate.dart';

/// Creates and persists a new exchange-rate observation.
///
/// Entity construction remains in the domain layer, while persistence and
/// asset validation are delegated to [CreateRateService].
final class CreateExchangeRateUseCase {
  /// Creates a use case with its persistence workflow and time source.
  const CreateExchangeRateUseCase({
    required CreateRateService createRate,
    required Clock clock,
  }) : _createRate = createRate, // ignore: prefer_initializing_formals
       _clock = clock; // ignore: prefer_initializing_formals

  final CreateRateService _createRate;
  final Clock _clock;

  /// Creates and persists an exchange rate from [command].
  ///
  /// Returns the created exchange rate on success. Returns the typed
  /// application or domain failure from the delegated workflow unchanged.
  Future<Result<ExchangeRate, BaseFailure>> call(
    CreateExchangeRateCommand command,
  ) async {
    final exchangeRate = ExchangeRate.create(
      baseAssetId: command.baseAssetId,
      quoteAssetId: command.quoteAssetId,
      rate: command.rate,
      effectiveAt: command.effectiveAt,
      clock: _clock,
    );
    final createResult = await _createRate(exchangeRate);

    return createResult.when<Result<ExchangeRate, BaseFailure>>(
      success: (_) => Success(exchangeRate),
      failure: (failure) => failure,
    );
  }
}
