import 'package:axiom/src/application/services/validate_jar_target_currencies_service.dart';
import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/ports/clock/clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/jars/application/commands/create_jar_command.dart';
import 'package:axiom/src/features/jars/domain/entities/jar.dart';
import 'package:axiom/src/features/jars/domain/repositories/jar_repository.dart';

/// Creates and persists a new active jar.
final class CreateJarUseCase {
  final JarRepository _repository;
  final Clock _clock;
  final ValidateJarTargetCurrenciesService _validateTargetCurrencies;

  /// Creates a use case with its repository and canonical time source.
  const CreateJarUseCase({
    required JarRepository repository,
    required Clock clock,
    required ValidateJarTargetCurrenciesService validateTargetCurrencies,
  }) : _repository = repository, // ignore: prefer_initializing_formals
       _clock = clock, // ignore: prefer_initializing_formals
       _validateTargetCurrencies = // ignore: prefer_initializing_formals
           validateTargetCurrencies;

  /// Creates and persists a jar from [command].
  Future<Result<Jar, BaseFailure>> call(CreateJarCommand command) async {
    final validationResult = await _validateTargetCurrencies(command.targets);

    if (validationResult case final Failure<BaseFailure> failure) {
      return failure;
    }

    final jar = Jar.create(
      name: command.name,
      description: command.description,
      kind: command.kind,
      targets: command.targets,
      icon: command.icon,
      color: command.color,
      sortOrder: command.sortOrder,
      clock: _clock,
    );

    final result = await _repository.create(jar);

    return result.when<Result<Jar, BaseFailure>>(
      success: (_) => Success(jar),
      failure: (failure) => failure,
    );
  }
}
