import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/features/rates/application/use_cases/create_exchange_rate_use_case.dart';
import 'package:axiom/src/features/rates/di/create_rate_service_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'create_exchange_rate_use_case_provider.g.dart';

/// Provides the use case for generating and persisting an exchange rate.
@riverpod
CreateExchangeRateUseCase createExchangeRateUseCase(Ref ref) {
  return CreateExchangeRateUseCase(
    createRate: ref.watch(createRateServiceProvider),
    clock: ref.watch(clockProvider),
  );
}
