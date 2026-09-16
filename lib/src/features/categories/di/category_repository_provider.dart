import 'package:axiom/src/core/di/validated_database_provider.dart';
import 'package:axiom/src/features/categories/data/repositories/sembast_category_repository_impl.dart';
import 'package:axiom/src/features/categories/domain/repositories/category_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'category_repository_provider.g.dart';

/// Provides the persistent repository used by the categories feature.
///
/// The database must already have completed the validated persistence
/// lifecycle before this provider is resolved.
@Riverpod(keepAlive: true)
CategoryRepository categoryRepository(Ref ref) {
  return SembastCategoryRepositoryImpl(
    database: ref.watch(validatedDatabaseProvider),
  );
}
