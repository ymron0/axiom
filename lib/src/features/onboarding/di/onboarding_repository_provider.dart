import 'package:axiom/src/core/di/validated_database_provider.dart';
import 'package:axiom/src/features/onboarding/data/repositories/sembast_onboarding_repository_impl.dart';
import 'package:axiom/src/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'onboarding_repository_provider.g.dart';

/// Provides onboarding persistence.
@Riverpod(keepAlive: true)
OnboardingRepository onboardingRepository(Ref ref) {
  return SembastOnboardingRepositoryImpl(
    database: ref.watch(validatedDatabaseProvider),
  );
}
