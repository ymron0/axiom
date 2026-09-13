import 'package:axiom/src/features/custodians/data/repositories/in_memory_custodian_repository_impl.dart';
import 'package:axiom/src/features/custodians/domain/repositories/custodian_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'custodian_repository_provider.g.dart';

/// Provides the repository used by the custodians feature.
@riverpod
CustodianRepository custodianRepository(Ref ref) {
  return InMemoryCustodianRepositoryImpl();
}
