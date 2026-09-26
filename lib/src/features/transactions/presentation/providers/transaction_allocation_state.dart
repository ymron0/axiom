import 'package:axiom/src/features/jars/di/get_jars_use_case_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/failures/base_failure.dart';
import '../../../../core/presentation/mutations/result_mutation_state.dart';
import '../../../../core/result/result.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../categories/presentation/providers/categories_state.dart';
import '../../../jars/domain/entities/jar.dart';

part 'transaction_allocation_state.g.dart';

/// Categories currently assignable by the transaction editor.
@riverpod
Future<Result<List<Category>, BaseFailure>> allocationCategories(
  Ref ref,
) async {
  final result = await ref.watch(categoriesProvider.future);

  if (result case final Failure<BaseFailure> failure) {
    return failure;
  }

  final categories = result.valueOrNull!
      .where((category) => !category.isDeleted)
      .toList(growable: false);

  return Success(categories);
}

/// Jars currently assignable by the transaction editor.
@riverpod
Future<Result<List<Jar>, BaseFailure>> allocationJars(Ref ref) async {
  final useCase = ref.watch(getJarsUseCaseProvider);
  final result = widenResult(await useCase());

  if (result case final Failure<BaseFailure> failure) {
    return failure;
  }

  final jars = result.valueOrNull!
      .where((jar) => !jar.isDeleted && !jar.isArchived)
      .toList(growable: false);

  return Success(jars);
}
