import 'package:axiom/src/core/ports/clock/clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/custodians/application/commands/create_custodian_command.dart';
import 'package:axiom/src/features/custodians/domain/entities/custodian.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_failure.dart';
import 'package:axiom/src/features/custodians/domain/repositories/custodian_repository.dart';

/// Creates and persists a new active custodian.
final class CreateCustodianUseCase {
  /// Creates a use case with its repository and time source.
  const CreateCustodianUseCase({
    required CustodianRepository repository,
    required Clock clock,
  }) : _repository = repository, // ignore: prefer_initializing_formals
       _clock = clock; // ignore: prefer_initializing_formals

  final CustodianRepository _repository;
  final Clock _clock;

  /// Creates and persists a custodian from [command].
  ///
  /// Returns the created custodian on success or a [CustodianFailure].
  Future<Result<Custodian, CustodianFailure>> call(
    CreateCustodianCommand command,
  ) async {
    final custodian = Custodian.create(
      name: command.name,
      kind: command.kind,
      logo: command.logo,
      icon: command.icon,
      color: command.color,
      sortOrder: command.sortOrder,
      clock: _clock,
    );
    final createResult = await _repository.create(custodian);

    return createResult.when<Result<Custodian, CustodianFailure>>(
      success: (_) => Success(custodian),
      failure: (failure) => failure,
    );
  }
}
