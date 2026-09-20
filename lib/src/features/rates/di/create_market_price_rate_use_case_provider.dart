import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/features/rates/application/use_cases/create_market_price_rate_use_case.dart';
import 'package:axiom/src/features/rates/di/create_rate_service_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'create_market_price_rate_use_case_provider.g.dart';

/// Provides the application use case that creates market-price rates.
///
/// The provider supplies the shared rate-creation service and application
/// clock used to construct and persist a new market-price rate.
@riverpod
CreateMarketPriceRateUseCase createMarketPriceRateUseCase(Ref ref) {
  return CreateMarketPriceRateUseCase(
    createRate: ref.watch(createRateServiceProvider),
    clock: ref.watch(clockProvider),
  );
}
