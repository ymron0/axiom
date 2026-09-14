import 'package:axiom/src/core/ports/clock/clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/jars/application/commands/create_jar_command.dart';
import 'package:axiom/src/features/jars/domain/entities/jar.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_failure.dart';
import 'package:axiom/src/features/jars/domain/repositories/jar_repository.dart';

/// Creates and persists a new active jar.
final class CreateJarUseCase {
  final JarRepository _repository;
  final Clock _clock;

  /// Creates a use case with its repository and canonical time source.
  const CreateJarUseCase({
    required JarRepository repository,
    required Clock clock,
  }) : _repository = repository, // ignore: prefer_initializing_formals
       _clock = clock; // ignore: prefer_initializing_formals

  /// Creates and persists a jar from [command].
  Future<Result<Jar, JarFailure>> call(CreateJarCommand command) async {
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

    return result.when<Result<Jar, JarFailure>>(
      success: (_) => Success(jar),
      failure: (failure) => failure,
    );
  }
}
