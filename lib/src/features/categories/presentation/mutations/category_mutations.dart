import 'dart:math' as math;

import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/features/categories/application/commands/create_category_command.dart';
import 'package:axiom/src/features/categories/di/create_category_use_case_provider.dart';
import 'package:axiom/src/features/categories/di/get_categories_use_case_provider.dart';
import 'package:axiom/src/features/categories/di/update_category_use_case_provider.dart';
import 'package:flutter_riverpod/experimental/mutation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../application/di/services/delete_category_service_provider.dart';
import '../../../../core/failures/base_failure.dart';
import '../../../../core/presentation/mutations/result_mutation_state.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/category.dart';
import '../providers/categories_state.dart';
import '../state/category_form_state.dart';

final createCategoryMutation = Mutation<Result<Category, BaseFailure>>(
  label: 'create-category',
);

final updateCategoryMutation = Mutation<Result<void, BaseFailure>>(
  label: 'update-category',
);

final deleteCategoryMutation = Mutation<Result<Object?, BaseFailure>>(
  label: 'delete-category',
);

Future<Result<Category, BaseFailure>> executeCreateCategory(
  WidgetRef ref,
  CategoryFormState form,
) {
  return createCategoryMutation.run(ref, (transaction) async {
    final getCategories = transaction.get(getCategoriesUseCaseProvider);
    final createCategory = transaction.get(createCategoryUseCaseProvider);

    final existingResult = widenResult(await getCategories());

    if (existingResult case final Failure<BaseFailure> failure) {
      return failure;
    }

    final existing = existingResult.valueOrNull!;

    final nextSortOrder = existing.isEmpty
        ? 0
        : existing.map((category) => category.sortOrder).reduce(math.max) + 1;

    final command = CreateCategoryCommand(
      name: form.name.trim(),
      parentCategoryId: form.parentCategoryId,
      kind: form.kind,
      icon: form.icon,
      color: form.color,
      sortOrder: nextSortOrder,
    );

    final result = widenResult(await createCategory(command));

    if (result.isSuccess) {
      ref.invalidate(categoriesProvider);
    }

    return result;
  });
}

Future<Result<void, BaseFailure>> executeUpdateCategory(
  WidgetRef ref, {
  required Category original,
  required CategoryFormState form,
}) {
  return updateCategoryMutation.run(ref, (transaction) async {
    final updateCategory = transaction.get(updateCategoryUseCaseProvider);

    final updated = original.copyWith(
      name: form.name.trim(),
      parentCategoryId: form.parentCategoryId,
      kind: form.kind,
      icon: form.icon,
      color: form.color,
    );

    final result = widenResult(await updateCategory(updated));

    if (result.isSuccess) {
      ref
        ..invalidate(categoriesProvider)
        ..invalidate(categoryDetailsProvider(original.id));
    }

    return result;
  });
}

Future<Result<Object?, BaseFailure>> executeDeleteCategory(
  WidgetRef ref,
  CategoryId categoryId,
) {
  final mutation = deleteCategoryMutation(categoryId);

  return mutation.run(ref, (transaction) async {
    final service = transaction.get(deleteCategoryServiceProvider);
    final result = await service(categoryId);

    final widened = result.when<Result<Object?, BaseFailure>>(
      success: (value) => Success<Object?>(value),
      failure: (failure) => failure,
    );

    if (widened.isSuccess) {
      ref
        ..invalidate(categoriesProvider)
        ..invalidate(categoryDetailsProvider(categoryId));
    }

    return widened;
  });
}
