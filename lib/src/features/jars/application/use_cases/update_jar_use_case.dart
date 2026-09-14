import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/application/services/validate_jar_target_currencies_service.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/jars/domain/entities/jar.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_already_deleted_failure.dart';
import 'package:axiom/src/features/jars/domain/repositories/jar_repository.dart';

/// Replaces one persisted jar snapshot.
final class UpdateJarUseCase {
  final JarRepository _repository;
  final ValidateJarTargetCurrenciesService _validateTargetCurrencies;

  /// Creates a use case backed by [repository].
  UpdateJarUseCase({
    required JarRepository repository,
    required ValidateJarTargetCurrenciesService validateTargetCurrencies,
  }) : _repository = repository, // ignore: prefer_initializing_formals
       _validateTargetCurrencies = // ignore: prefer_initializing_formals
           validateTargetCurrencies;

  /// Persists [jar] as the complete new snapshot.
  ///
  /// Archived jars may still be updated.
  Future<Result<void, BaseFailure>> call(Jar jar) async {
    if (jar.isDeleted) {
      return JarAlreadyDeletedFailure(
        message: 'Deleted jar cannot be updated: ${jar.id.value}',
      );
    }

    final validationResult = await _validateTargetCurrencies(jar.targets);

    if (validationResult case final Failure<BaseFailure> failure) {
      return failure;
    }

    return _repository.update(jar);
  }
}
