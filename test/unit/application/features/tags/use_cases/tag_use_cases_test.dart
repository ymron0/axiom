@Tags(['application'])
library;

import 'package:axiom/src/core/identity/ids/tag_id.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/core/repositories/batch_lookup.dart';
import 'package:axiom/src/core/result/result.dart';
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
import 'package:axiom/src/features/tags/domain/entities/tag.dart';
import 'package:axiom/src/features/tags/domain/failures/invalid_tag_name_failure.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_persistence_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/tags/tag_fixtures.dart';
import '../../../../../mocks/tag_repository_mock.dart';

void main() {
  late MockTagRepository repository;

  final timestamp = DateTime.utc(2026, 9, 19, 12);
  final id = TagId.fromString('tag-1');

  setUpAll(() {
    registerFallbackValue(tagFixture());
  });

  setUp(() {
    repository = MockTagRepository();
  });

  test('CreateTagUseCase creates normalized tag', () async {
    when(
      () => repository.create(any()),
    ).thenAnswer((_) async => const Success(null));

    final useCase = CreateTagUseCase(
      repository: repository,
      clock: FixedClock(timestamp),
    );

    final result = await useCase('  Business   Travel ');

    final tag = result.valueOrNull!;

    expect(tag.name, 'Business Travel');
    expect(tag.createdAt, timestamp);
    expect(tag.modifiedAt, timestamp);

    verify(() => repository.create(tag)).called(1);
  });

  test('CreateTagUseCase rejects blank name without persistence', () async {
    final useCase = CreateTagUseCase(
      repository: repository,
      clock: FixedClock(timestamp),
    );

    final result = await useCase('   ');

    expect(result.failureOrNull, isA<InvalidTagNameFailure>());
    verifyNever(() => repository.create(any()));
  });

  test('CreateTagUseCase propagates repository failure', () async {
    const failure = TagPersistenceFailure(message: 'failed');

    when(() => repository.create(any())).thenAnswer((_) async => failure);

    final result = await CreateTagUseCase(
      repository: repository,
      clock: FixedClock(timestamp),
    )('Business');

    expect(result.failureOrNull, same(failure));
  });

  test('GetTagsUseCase delegates getAll', () async {
    final tag = tagFixture();

    when(repository.getAll).thenAnswer((_) async => Success(<Tag>[tag]));

    final result = await GetTagsUseCase(repository)();

    expect(result.valueOrNull, [tag]);
    verify(repository.getAll).called(1);
  });

  test('GetActiveTagsUseCase delegates getActive', () async {
    when(repository.getActive).thenAnswer((_) async => const Success(<Tag>[]));

    await GetActiveTagsUseCase(repository)();

    verify(repository.getActive).called(1);
  });

  test('GetArchivedTagsUseCase delegates getArchived', () async {
    when(
      repository.getArchived,
    ).thenAnswer((_) async => const Success(<Tag>[]));

    await GetArchivedTagsUseCase(repository)();

    verify(repository.getArchived).called(1);
  });

  test('GetTagByIdUseCase delegates getById', () async {
    when(
      () => repository.getById(id),
    ).thenAnswer((_) async => const Success<Tag?>(null));

    await GetTagByIdUseCase(repository)(id);

    verify(() => repository.getById(id)).called(1);
  });

  test('GetTagsByIdsUseCase delegates getByIds', () async {
    final lookup = BatchLookup<Tag, TagId>(found: const [], missing: [id]);

    when(
      () => repository.getByIds([id]),
    ).thenAnswer((_) async => Success(lookup));

    final result = await GetTagsByIdsUseCase(repository)([id]);

    expect(result.valueOrNull, same(lookup));
  });

  test('GetTagByNameUseCase delegates getByName', () async {
    when(
      () => repository.getByName('Business'),
    ).thenAnswer((_) async => const Success<Tag?>(null));

    await GetTagByNameUseCase(repository)('Business');

    verify(() => repository.getByName('Business')).called(1);
  });

  test('SearchTagsUseCase delegates search', () async {
    when(
      () => repository.search('bus'),
    ).thenAnswer((_) async => const Success(<Tag>[]));

    await SearchTagsUseCase(repository)('bus');

    verify(() => repository.search('bus')).called(1);
  });

  test('UpdateTagUseCase delegates update', () async {
    final tag = tagFixture();

    when(
      () => repository.update(tag),
    ).thenAnswer((_) async => const Success(null));

    await UpdateTagUseCase(repository)(tag);

    verify(() => repository.update(tag)).called(1);
  });

  test('ArchiveTagUseCase supplies canonical current time', () async {
    final archived = tagFixture(archivedAt: timestamp, modifiedAt: timestamp);

    when(
      () => repository.archive(id, timestamp),
    ).thenAnswer((_) async => Success(archived));

    final result = await ArchiveTagUseCase(
      repository: repository,
      clock: FixedClock(timestamp),
    )(id);

    expect(result.valueOrNull, archived);
  });

  test('UnarchiveTagUseCase supplies canonical current time', () async {
    final tag = tagFixture();

    when(
      () => repository.unarchive(id, timestamp),
    ).thenAnswer((_) async => Success(tag));

    final result = await UnarchiveTagUseCase(
      repository: repository,
      clock: FixedClock(timestamp),
    )(id);

    expect(result.valueOrNull, tag);
  });

  test('DeleteTagUseCase delegates deletion', () async {
    final deleted = tagFixture(deletedAt: timestamp, modifiedAt: timestamp);

    when(() => repository.delete(id)).thenAnswer((_) async => Success(deleted));

    final result = await DeleteTagUseCase(repository)(id);

    expect(result.valueOrNull, deleted);
  });

  test('RestoreTagUseCase delegates restoration', () async {
    final deleted = tagFixture(deletedAt: timestamp, modifiedAt: timestamp);

    when(
      () => repository.restore(deleted),
    ).thenAnswer((_) async => const Success(null));

    final result = await RestoreTagUseCase(repository)(deleted);

    expect(result.isSuccess, isTrue);
  });
}
