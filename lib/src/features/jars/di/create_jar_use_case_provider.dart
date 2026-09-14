import 'package:axiom/src/application/services/validate_jar_target_currencies_service.dart';
import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/features/jars/application/use_cases/create_jar_use_case.dart';
import 'package:axiom/src/features/jars/di/jar_repository_provider.dart';
import 'package:axiom/src/features/settings/di/get_settings_use_case_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'create_jar_use_case_provider.g.dart';

/// Provides the use case for creating a jar.
@riverpod
CreateJarUseCase createJarUseCase(Ref ref) {
  return CreateJarUseCase(
    repository: ref.watch(jarRepositoryProvider),
    clock: ref.watch(clockProvider),
    validateTargetCurrencies: ValidateJarTargetCurrenciesService(
      getSettings: ref.watch(getSettingsUseCaseProvider),
    ),
  );
}
