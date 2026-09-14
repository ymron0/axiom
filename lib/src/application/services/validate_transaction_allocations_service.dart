import 'package:axiom/src/application/failures/allocation_category_kind_mismatch_failure.dart';
import 'package:axiom/src/application/failures/allocation_category_not_found_failure.dart';
import 'package:axiom/src/application/failures/allocation_jar_not_found_failure.dart';
import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/categories/application/use_cases/get_category_by_id_use_case.dart';
import 'package:axiom/src/features/categories/domain/enums/category_kind.dart';
import 'package:axiom/src/features/categories/domain/failures/category_failure.dart';
import 'package:axiom/src/features/jars/application/use_cases/get_jar_by_id_use_case.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_failure.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_kind.dart';

/// Validates cross-feature references used by transaction allocations.
///
/// [Transaction] and `TransactionSplit` own structural and monetary allocation
/// invariants. This service validates only rules that require loading entities
/// from other features.
///
/// ## Current responsibilities
///
/// For every category referenced by [Transaction.splits], the service verifies
/// that:
///
/// - the category exists; and
/// - the category kind is compatible with the transaction kind.
///
/// Repeated references to the same category are resolved only once.
///
/// Every referenced jar must exist. Archived jars are valid historical
/// references. Repeated references to the same jar are resolved only once.
///
/// ## Category compatibility
///
/// Expense transactions may reference only expense categories.
///
/// Income transactions may reference only income categories.
///
/// Transfers and balance corrections cannot contain allocation splits, as
/// enforced by the [Transaction] aggregate. Encountering a category allocation
/// for either kind therefore indicates an invalid program state rather than an
/// expected validation failure.
///
/// ## Failure semantics
///
/// Repository or Categories application failures are propagated unchanged.
///
/// A category identifier that resolves successfully to `null` produces
/// [AllocationCategoryNotFoundFailure].
///
/// A category whose [CategoryKind] does not match the transaction kind produces
/// [AllocationCategoryKindMismatchFailure].
///
/// A jar identifier that resolves successfully to `null` produces
/// [AllocationJarNotFoundFailure].
final class ValidateTransactionAllocationsService {
  final GetCategoryByIdUseCase _getCategoryById;
  final GetJarByIdUseCase _getJarById;

  /// Creates an allocation validator.
  const ValidateTransactionAllocationsService({
    required GetCategoryByIdUseCase getCategoryById,
    required GetJarByIdUseCase getJarById,
  }) : _getCategoryById = getCategoryById, // ignore: prefer_initializing_formals
       _getJarById = getJarById; // ignore: prefer_initializing_formals

  /// Validates all external allocation references in [transaction].
  ///
  /// Returns success when:
  ///
  /// - the transaction contains no allocations; or
  /// - every referenced category exists and has the expected kind; and
  /// - every referenced jar exists, including archived jars.
  ///
  /// Returns [AllocationCategoryNotFoundFailure] when a referenced category
  /// cannot be resolved.
  ///
  /// Returns [AllocationCategoryKindMismatchFailure] when a referenced category
  /// has a financial kind incompatible with [Transaction.kind].
  ///
  /// Failures produced by the Categories application boundary are propagated
  /// unchanged.
  Future<Result<void, BaseFailure>> call(Transaction transaction) async {
    final categoryIds = <CategoryId>{
      for (final split in transaction.splits)
        if (split.categoryId != null) split.categoryId!,
    };

    final jarIds = <JarId>{
      for (final split in transaction.splits)
        if (split.jarId != null) split.jarId!,
    };

    if (categoryIds.isEmpty && jarIds.isEmpty) {
      return const Success(null);
    }

    if (categoryIds.isNotEmpty) {
      final expectedKind = _expectedCategoryKind(transaction.kind);

      for (final categoryId in categoryIds) {
        final categoryResult = await _getCategoryById(categoryId);

        if (categoryResult case final Failure<CategoryFailure> failure) {
          return failure;
        }

        final category = categoryResult.valueOrNull;

        if (category == null) {
          return AllocationCategoryNotFoundFailure(
            message:
                'Transaction allocation references a category that does not '
                'exist: ${categoryId.value}',
          );
        }

        if (category.kind != expectedKind) {
          return AllocationCategoryKindMismatchFailure(
            message:
                'Transaction allocation category ${categoryId.value} has kind '
                '${category.kind.name}, but ${transaction.kind.name} '
                'transactions require ${expectedKind.name} categories.',
          );
        }
      }
    }

    for (final jarId in jarIds) {
      final jarResult = await _getJarById(jarId);

      if (jarResult case final Failure<JarFailure> failure) {
        return failure;
      }

      if (jarResult.valueOrNull == null) {
        return AllocationJarNotFoundFailure(
          message:
              'Transaction allocation references a jar that does not exist: '
              '${jarId.value}',
        );
      }
    }

    return const Success(null);
  }

  /// Returns the category kind required by [transactionKind].
  ///
  /// Only expense and income transactions can contain allocation splits.
  ///
  /// Reaching this method with a transfer or balance correction containing
  /// category allocations would mean that an invariant already guaranteed by
  /// [Transaction] has been violated.
  CategoryKind _expectedCategoryKind(TransactionKind transactionKind) {
    return switch (transactionKind) {
      TransactionKind.expense => CategoryKind.expense,
      TransactionKind.income => CategoryKind.income,
      // These cases are unreachable because Transaction rejects allocation
      // splits for these kinds before this service can be called.
      // coverage:ignore-start
      TransactionKind.transfer => throw StateError(
        'Transfer transactions cannot contain allocation splits.',
      ),
      TransactionKind.balanceCorrection => throw StateError(
        'Balance-correction transactions cannot contain allocation splits.',
      ),
      // coverage:ignore-end
    };
  }
}
