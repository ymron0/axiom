import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/features/onboarding/application/use_cases/complete_onboarding_use_case.dart';
import 'package:axiom/src/features/onboarding/di/onboarding_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'complete_onboarding_use_case_provider.g.dart';

/// Provides onboarding completion.
@riverpod
CompleteOnboardingUseCase completeOnboardingUseCase(Ref ref) {
  return CompleteOnboardingUseCase(
    repository: ref.watch(onboardingRepositoryProvider),
    clock: ref.watch(clockProvider),
  );
}
