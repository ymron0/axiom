@Tags(['application', 'di'])
library;

import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/features/tags/application/use_cases/archive_tag_use_case.dart';
import 'package:axiom/src/features/tags/application/use_cases/create_tag_use_case.dart';
import 'package:axiom/src/features/tags/application/use_cases/delete_tag_use_case.dart';
import 'package:axiom/src/features/tags/application/use_cases/get_active_tags_use_case.dart';
import 'package:axiom/src/features/tags/application/use_cases/get_archived_tags_use_case.dart';
import 'package:axiom/src/features/tags/application/use_cases/get_tag_by_id_use_case.dart';
import 'package:axiom/src/features/tags/application/use_cases/get_tag_by_name_use_case.dart';
import 'package:axiom/src/features/tags/application/use_cases/get_tags_by_ids_use_case.dart';
import 'package:axiom/src/features/tags/application/use_cases/get_tags_use_case.dart';
import 'package:axiom/src/features/tags/application/use_cases/restore_tag_use_case.dart';
import 'package:axiom/src/features/tags/application/use_cases/search_tags_use_case.dart';
import 'package:axiom/src/features/tags/application/use_cases/unarchive_tag_use_case.dart';
import 'package:axiom/src/features/tags/application/use_cases/update_tag_use_case.dart';
import 'package:axiom/src/features/tags/di/archive_tag_use_case_provider.dart';
import 'package:axiom/src/features/tags/di/create_tag_use_case_provider.dart';
import 'package:axiom/src/features/tags/di/delete_tag_use_case_provider.dart';
import 'package:axiom/src/features/tags/di/get_active_tags_use_case_provider.dart';
import 'package:axiom/src/features/tags/di/get_archived_tags_use_case_provider.dart';
import 'package:axiom/src/features/tags/di/get_tag_by_id_use_case_provider.dart';
import 'package:axiom/src/features/tags/di/get_tag_by_name_use_case_provider.dart';
import 'package:axiom/src/features/tags/di/get_tags_by_ids_use_case_provider.dart';
import 'package:axiom/src/features/tags/di/get_tags_use_case_provider.dart';
import 'package:axiom/src/features/tags/di/restore_tag_use_case_provider.dart';
import 'package:axiom/src/features/tags/di/search_tags_use_case_provider.dart';
import 'package:axiom/src/features/tags/di/tag_repository_provider.dart';
import 'package:axiom/src/features/tags/di/unarchive_tag_use_case_provider.dart';
import 'package:axiom/src/features/tags/di/update_tag_use_case_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

import '../../../../../mocks/tag_repository_mock.dart';

void main() {
  group('tag use-case providers', () {
    test('provide every tag use case', () {
      final repository = MockTagRepository();

      final container = ProviderContainer(
        overrides: [
          tagRepositoryProvider.overrideWithValue(repository),
          clockProvider.overrideWithValue(
            FixedClock(DateTime.utc(2026, 9, 19)),
          ),
        ],
      );

      addTearDown(container.dispose);

      expect(container.read(createTagUseCaseProvider), isA<CreateTagUseCase>());

      expect(container.read(getTagsUseCaseProvider), isA<GetTagsUseCase>());

      expect(
        container.read(getActiveTagsUseCaseProvider),
        isA<GetActiveTagsUseCase>(),
      );

      expect(
        container.read(getArchivedTagsUseCaseProvider),
        isA<GetArchivedTagsUseCase>(),
      );

      expect(
        container.read(getTagByIdUseCaseProvider),
        isA<GetTagByIdUseCase>(),
      );

      expect(
        container.read(getTagsByIdsUseCaseProvider),
        isA<GetTagsByIdsUseCase>(),
      );

      expect(
        container.read(getTagByNameUseCaseProvider),
        isA<GetTagByNameUseCase>(),
      );

      expect(
        container.read(searchTagsUseCaseProvider),
        isA<SearchTagsUseCase>(),
      );

      expect(container.read(updateTagUseCaseProvider), isA<UpdateTagUseCase>());

      expect(
        container.read(archiveTagUseCaseProvider),
        isA<ArchiveTagUseCase>(),
      );

      expect(
        container.read(unarchiveTagUseCaseProvider),
        isA<UnarchiveTagUseCase>(),
      );

      expect(container.read(deleteTagUseCaseProvider), isA<DeleteTagUseCase>());

      expect(
        container.read(restoreTagUseCaseProvider),
        isA<RestoreTagUseCase>(),
      );
    });
  });
}
