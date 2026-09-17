import 'package:axiom/src/application/failures/allocation_category_not_found_failure.dart';
import 'package:axiom/src/application/failures/allocation_jar_not_found_failure.dart';
import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/categories/application/use_cases/get_category_by_id_use_case.dart';
import 'package:axiom/src/features/categories/domain/failures/category_failure.dart';
import 'package:axiom/src/features/jars/application/use_cases/get_jar_by_id_use_case.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_failure.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';

/// Validates cross-feature references used by transaction allocations.
///
/// [Transaction] and `TransactionSplit` own structural and monetary allocation
/// invariants. This service validates only rules that require loading entities
/// from other features.
///
/// ## Category semantics
///
/// Every category referenced by [Transaction.splits] must exist.
///
/// Category kind does not restrict transaction direction. Expense transactions
/// may be allocated to income categories, and income transactions may be
/// allocated to expense categories.
///
/// This allows financial adjustments such as refunds, reimbursements,
/// chargebacks, reversals, and repayments to remain classified under the
/// category to which they economically belong.
///
/// Repeated references to the same category are resolved only once.
///
/// ## Jar semantics
///
/// Every referenced jar must exist. Archived jars are valid historical
/// references. Repeated references to the same jar are resolved only once.
///
/// ## Failure semantics
///
/// Repository or Categories application failures are propagated unchanged.
///
/// A category identifier that resolves successfully to `null` produces
/// [AllocationCategoryNotFoundFailure].
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
  /// Returns success when every referenced category and jar exists.
  ///
  /// Category kind is deliberately not compared with transaction kind.
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

    for (final categoryId in categoryIds) {
      final categoryResult = await _getCategoryById(categoryId);

      if (categoryResult case final Failure<CategoryFailure> failure) {
        return failure;
      }

      if (categoryResult.valueOrNull == null) {
        return AllocationCategoryNotFoundFailure(
          message:
              'Transaction allocation references a category that does not '
              'exist: ${categoryId.value}',
        );
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
}