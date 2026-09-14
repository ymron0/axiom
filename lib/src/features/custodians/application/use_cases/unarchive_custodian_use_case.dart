import 'package:axiom/src/core/identity/ids/custodian_id.dart';
import 'package:axiom/src/core/ports/clock/clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/custodians/domain/entities/custodian.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_failure.dart';
import 'package:axiom/src/features/custodians/domain/repositories/custodian_repository.dart';

/// Unarchives a custodian.
final class UnarchiveCustodianUseCase {
  /// Creates a use case with its repository and canonical time source.
  const UnarchiveCustodianUseCase({
    required CustodianRepository repository,
    required Clock clock,
  }) : _repository = repository, // ignore: prefer_initializing_formals
       _clock = clock; // ignore: prefer_initializing_formals

  final CustodianRepository _repository;
  final Clock _clock;

  /// Unarchives [id].
  Future<Result<Custodian, CustodianFailure>> call(CustodianId id) {
    return _repository.unarchive(id, _clock.nowUtc);
  }
}
