import 'package:axiom/src/application/services/validate_transaction_allocations_service.dart';
import 'package:axiom/src/features/categories/di/get_category_by_id_use_case_provider.dart';
import 'package:axiom/src/features/jars/di/get_jar_by_id_use_case_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'validate_transaction_allocations_service_provider.g.dart';

/// Provides the service that validates cross-feature transaction allocations.
@riverpod
ValidateTransactionAllocationsService validateTransactionAllocationsService(
  Ref ref,
) {
  return ValidateTransactionAllocationsService(
    getCategoryById: ref.watch(getCategoryByIdUseCaseProvider),
    getJarById: ref.watch(getJarByIdUseCaseProvider),
  );
}
