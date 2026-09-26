import 'package:axiom/src/core/ports/clock/clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/onboarding/domain/entities/onboarding_status.dart';
import 'package:axiom/src/features/onboarding/domain/failures/onboarding_failure.dart';
import 'package:axiom/src/features/onboarding/domain/repositories/onboarding_repository.dart';

/// Completes first-run onboarding.
final class CompleteOnboardingUseCase {
  /// Creates the use case.
  const CompleteOnboardingUseCase({
    required OnboardingRepository repository,
    required Clock clock,
  }) : _repository = repository, // ignore: prefer_initializing_formals
       _clock = clock; // ignore: prefer_initializing_formals

  final OnboardingRepository _repository;
  final Clock _clock;

  /// Marks onboarding complete using the configured application clock.
  Future<Result<OnboardingStatus, OnboardingFailure>> call() {
    return _repository.complete(_clock.nowUtc);
  }
}
