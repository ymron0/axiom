import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/categories/domain/failures/category_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'category_persistence_failure.mapper.dart';

/// Indicates that category persistence could not complete successfully.
///
/// This failure represents storage-level problems exposed through the
/// Categories domain failure contract.
///
/// Infrastructure-specific failures and exceptions must not escape through
/// `CategoryRepository`. Persistent repository implementations translate
/// expected persistence problems into this failure instead.
///
/// Examples include:
///
/// - Sembast database failures;
/// - file-system failures;
/// - malformed persisted category records;
/// - malformed persisted budget rules;
/// - malformed persisted asset amounts; and
/// - records that cannot be reconstructed according to the current Categories
///   domain invariants.
///
/// Domain failures such as `CategoryNotFoundFailure` and
/// `CategoryAlreadyExistsFailure` remain distinct typed failures.
///
/// Programmer errors and violated internal assumptions are deliberately not
/// translated into this failure and must continue to propagate normally.
@MappableClass()
final class CategoryPersistenceFailure
    extends Failure<CategoryPersistenceFailure>
    with CategoryPersistenceFailureMappable
    implements CategoryFailure {
  /// Creates a category-persistence failure with optional details.
  const CategoryPersistenceFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'categories.persistence';

  @override
  CategoryPersistenceFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
