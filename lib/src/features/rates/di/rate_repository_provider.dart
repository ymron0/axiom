import 'package:axiom/src/features/rates/data/repositories/in_memory_rate_repository_impl.dart';
import 'package:axiom/src/features/rates/domain/repositories/rate_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'rate_repository_provider.g.dart';

/// Provides the rate repository used by the rates feature.
@riverpod
RateRepository rateRepository(Ref ref) {
  return InMemoryRateRepositoryImpl();
}
