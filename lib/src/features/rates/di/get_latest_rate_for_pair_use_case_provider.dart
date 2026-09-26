import 'package:axiom/src/features/rates/application/use_cases/get_latest_rate_for_pair_use_case.dart';
import 'package:axiom/src/features/rates/di/rate_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'get_latest_rate_for_pair_use_case_provider.g.dart';

/// Provides exact-pair latest-rate retrieval.
@riverpod
GetLatestRateForPairUseCase getLatestRateForPairUseCase(Ref ref) {
  return GetLatestRateForPairUseCase(ref.watch(rateRepositoryProvider));
}
