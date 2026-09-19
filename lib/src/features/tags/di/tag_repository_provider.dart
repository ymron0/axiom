import 'package:axiom/src/core/di/validated_database_provider.dart';
import 'package:axiom/src/features/tags/data/repositories/sembast_tag_repository_impl.dart';
import 'package:axiom/src/features/tags/domain/repositories/tag_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'tag_repository_provider.g.dart';

/// Provides the persistent repository used by the tags feature.
@Riverpod(keepAlive: true)
TagRepository tagRepository(Ref ref) {
  return SembastTagRepositoryImpl(
    database: ref.watch(validatedDatabaseProvider),
  );
}
