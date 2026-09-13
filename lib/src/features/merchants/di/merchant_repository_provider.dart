import 'package:axiom/src/features/merchants/data/repositories/in_memory_merchant_repository_impl.dart';
import 'package:axiom/src/features/merchants/domain/repositories/merchant_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'merchant_repository_provider.g.dart';

/// Provides the repository used by the merchants feature.
@riverpod
MerchantRepository merchantRepository(Ref ref) {
  return InMemoryMerchantRepositoryImpl();
}
