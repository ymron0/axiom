import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/onboarding/domain/failures/onboarding_failure.dart';
import 'package:axiom/src/features/onboarding/domain/repositories/onboarding_repository.dart';

/// Determines whether the application must present first-run onboarding.
///
/// ## Semantics
///
/// First-run state is based on the dedicated onboarding completion marker,
/// rather than Settings existence.
///
/// This distinction matters because Settings are initialized before optional
/// onboarding steps such as custodian, account, and initial-balance setup.
final class DetectFirstRunUseCase {
  /// Creates the first-run detector.
  const DetectFirstRunUseCase(this._repository);

  final OnboardingRepository _repository;

  /// Returns `true` while onboarding remains incomplete.
  Future<Result<bool, OnboardingFailure>> call() async {
    final result = await _repository.getStatus();

    return result.when<Result<bool, OnboardingFailure>>(
      success: (status) => Success(!status.isCompleted),
      failure: (failure) => failure,
    );
  }
}
