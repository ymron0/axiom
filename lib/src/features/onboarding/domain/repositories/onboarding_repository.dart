// coverage:ignore-file

import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/onboarding/domain/entities/onboarding_status.dart';
import 'package:axiom/src/features/onboarding/domain/failures/onboarding_failure.dart';

/// Persists first-run onboarding state.
///
/// ## Contract
///
/// A missing persistence record represents pending onboarding.
///
/// [complete] is idempotent. Completing an already completed onboarding flow
/// returns the existing completion state unchanged.
abstract interface class OnboardingRepository {
  /// Returns the current onboarding state.
  Future<Result<OnboardingStatus, OnboardingFailure>> getStatus();

  /// Marks onboarding complete.
  Future<Result<OnboardingStatus, OnboardingFailure>> complete(
    DateTime completedAt,
  );
}
