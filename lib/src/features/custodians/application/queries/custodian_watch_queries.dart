import 'package:axiom/src/core/identity/ids/custodian_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/custodians/domain/entities/custodian.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_failure.dart';
import 'package:axiom/src/features/custodians/domain/repositories/custodian_repository.dart';

/// Reactive custodian queries intended for presentation reads.
final class CustodianWatchQueries {
  final CustodianRepository _repository;

  /// Creates reactive custodian queries backed by [repository].
  CustodianWatchQueries(this._repository);

  /// Watches every persisted custodian.
  Stream<Result<List<Custodian>, CustodianFailure>> all() {
    return _repository.watchAll();
  }

  /// Watches active custodians.
  Stream<Result<List<Custodian>, CustodianFailure>> active() {
    return _repository.watchActive();
  }

  /// Watches archived custodians.
  Stream<Result<List<Custodian>, CustodianFailure>> archived() {
    return _repository.watchArchived();
  }

  /// Watches one custodian by identity.
  Stream<Result<Custodian?, CustodianFailure>> byId(CustodianId id) {
    return _repository.watchById(id);
  }
}
