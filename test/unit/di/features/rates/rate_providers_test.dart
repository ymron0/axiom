import 'package:axiom/src/features/rates/application/services/resolve_conversion_rate_service.dart';
import 'package:axiom/src/features/rates/application/use_cases/get_rate_at_use_case.dart';
import 'package:axiom/src/features/rates/application/use_cases/get_rate_by_id_use_case.dart';
import 'package:axiom/src/features/rates/application/use_cases/get_rate_for_pair_use_case.dart';
import 'package:axiom/src/features/rates/data/repositories/in_memory_rate_repository_impl.dart';
import 'package:axiom/src/features/rates/di/get_rate_at_use_case_provider.dart';
import 'package:axiom/src/features/rates/di/get_rate_by_id_use_case_provider.dart';
import 'package:axiom/src/features/rates/di/get_rate_for_pair_use_case_provider.dart';
import 'package:axiom/src/features/rates/di/rate_repository_provider.dart';
import 'package:axiom/src/features/rates/di/resolve_conversion_rate_service_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

import '../../../../mocks/rate_repository_mock.dart';

void main() {
  group('rates providers', () {
    test('resolves all rates providers from the default dependencies', () {
      // Given
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // When
      final repository = container.read(rateRepositoryProvider);
      final providers = [
        container.read(getRateAtUseCaseProvider),
        container.read(getRateByIdUseCaseProvider),
        container.read(getRateForPairUseCaseProvider),
        container.read(resolveConversionRateServiceProvider),
      ];

      // Then
      expect(repository, isA<InMemoryRateRepositoryImpl>());
      expect(providers[0], isA<GetRateAtUseCase>());
      expect(providers[1], isA<GetRateByIdUseCase>());
      expect(providers[2], isA<GetRateForPairUseCase>());
      expect(providers[3], isA<ResolveConversionRateService>());
    });

    test('passes an overridden repository to rate use cases', () {
      // Given
      final repository = MockRateRepository();
      final container = ProviderContainer(
        overrides: [rateRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      // When
      final atUseCase = container.read(getRateAtUseCaseProvider);
      final byIdUseCase = container.read(getRateByIdUseCaseProvider);
      final forPairUseCase = container.read(getRateForPairUseCaseProvider);

      // Then
      expect(atUseCase.repository, same(repository));
      expect(byIdUseCase, isA<GetRateByIdUseCase>());
      expect(forPairUseCase, isA<GetRateForPairUseCase>());
    });
  });
}
