import 'package:axiom/src/features/onboarding/application/use_cases/detect_first_run_use_case.dart';
import 'package:axiom/src/features/onboarding/di/onboarding_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'detect_first_run_use_case_provider.g.dart';

/// Provides first-run detection.
@riverpod
DetectFirstRunUseCase detectFirstRunUseCase(Ref ref) {
  return DetectFirstRunUseCase(ref.watch(onboardingRepositoryProvider));
}
