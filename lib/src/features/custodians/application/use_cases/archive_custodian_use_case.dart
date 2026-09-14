import 'package:axiom/src/core/identity/ids/custodian_id.dart';
import 'package:axiom/src/core/ports/clock/clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/custodians/domain/entities/custodian.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_failure.dart';
import 'package:axiom/src/features/custodians/domain/repositories/custodian_repository.dart';

/// Archives a custodian without deleting it.
final class ArchiveCustodianUseCase {
  /// Creates a use case with its repository and canonical time source.
  const ArchiveCustodianUseCase({
    required CustodianRepository repository,
    required Clock clock,
  }) : _repository = repository, // ignore: prefer_initializing_formals
       _clock = clock; // ignore: prefer_initializing_formals

  final CustodianRepository _repository;
  final Clock _clock;

  /// Archives [id] and all of its direct child custodians atomically.
  Future<Result<Custodian, CustodianFailure>> call(CustodianId id) {
    return _repository.archive(id, _clock.nowUtc);
  }
}
