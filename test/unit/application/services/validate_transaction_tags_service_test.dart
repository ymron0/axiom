@Tags(['application'])
library;

import 'package:axiom/src/application/services/validate_transaction_tags_service.dart';
import 'package:axiom/src/core/identity/ids/tag_id.dart';
import 'package:axiom/src/core/repositories/batch_lookup.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/tags/application/use_cases/get_tags_by_ids_use_case.dart';
import 'package:axiom/src/features/tags/domain/entities/tag.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_not_assignable_failure.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_not_found_failure.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_repository_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../fixtures/features/tags/tag_fixtures.dart';
import '../../../mocks/tag_repository_mock.dart';

void main() {
  late MockTagRepository repository;
  late ValidateTransactionTagsService service;

  final activeId = TagId.fromString('active');
  final archivedId = TagId.fromString('archived');
  final missingId = TagId.fromString('missing');
  final archivedAt = DateTime.utc(2026, 2, 1);

  setUp(() {
    repository = MockTagRepository();

    service = ValidateTransactionTagsService(
      getTagsByIds: GetTagsByIdsUseCase(repository),
    );
  });

  test('empty create validation succeeds without repository lookup', () async {
    final result = await service.validateForCreate(const []);

    expect(result.isSuccess, isTrue);
    verifyNever(() => repository.getByIds(any()));
  });

  test('create succeeds when every tag exists and is active', () async {
    final active = tagFixture(id: activeId.value);

    when(() => repository.getByIds(any())).thenAnswer(
      (_) async =>
          Success(BatchLookup<Tag, TagId>(found: [active], missing: const [])),
    );

    final result = await service.validateForCreate([activeId]);

    expect(result.isSuccess, isTrue);
  });

  test('missing tag returns TagNotFoundFailure', () async {
    when(() => repository.getByIds(any())).thenAnswer(
      (_) async => Success(
        BatchLookup<Tag, TagId>(found: const [], missing: [missingId]),
      ),
    );

    final result = await service.validateForCreate([missingId]);

    expect(result.failureOrNull, isA<TagNotFoundFailure>());
  });

  test('new assignment of archived tag is rejected', () async {
    final archived = tagFixture(
      id: archivedId.value,
      archivedAt: archivedAt,
      modifiedAt: archivedAt,
    );

    when(() => repository.getByIds(any())).thenAnswer(
      (_) async => Success(
        BatchLookup<Tag, TagId>(found: [archived], missing: const []),
      ),
    );

    final result = await service.validateForCreate([archivedId]);

    expect(result.failureOrNull, isA<TagNotAssignableFailure>());
  });

  test('update permits an archived tag already attached', () async {
    final archived = tagFixture(
      id: archivedId.value,
      archivedAt: archivedAt,
      modifiedAt: archivedAt,
    );

    when(() => repository.getByIds(any())).thenAnswer(
      (_) async => Success(
        BatchLookup<Tag, TagId>(found: [archived], missing: const []),
      ),
    );

    final result = await service.validateForUpdate(
      previousTagIds: [archivedId],
      nextTagIds: [archivedId],
    );

    expect(result.isSuccess, isTrue);
  });

  test('update rejects newly added archived tag', () async {
    final archived = tagFixture(
      id: archivedId.value,
      archivedAt: archivedAt,
      modifiedAt: archivedAt,
    );

    when(() => repository.getByIds(any())).thenAnswer(
      (_) async => Success(
        BatchLookup<Tag, TagId>(found: [archived], missing: const []),
      ),
    );

    final result = await service.validateForUpdate(
      previousTagIds: const [],
      nextTagIds: [archivedId],
    );

    expect(result.failureOrNull, isA<TagNotAssignableFailure>());
  });

  test('removed orphan tag is not resolved during update', () async {
    final result = await service.validateForUpdate(
      previousTagIds: [missingId],
      nextTagIds: const [],
    );

    expect(result.isSuccess, isTrue);
    verifyNever(() => repository.getByIds(any()));
  });

  test('restore accepts an existing archived tag', () async {
    final archived = tagFixture(
      id: archivedId.value,
      archivedAt: archivedAt,
      modifiedAt: archivedAt,
    );

    when(() => repository.getByIds(any())).thenAnswer(
      (_) async => Success(
        BatchLookup<Tag, TagId>(found: [archived], missing: const []),
      ),
    );

    final result = await service.validateForRestore([archivedId]);

    expect(result.isSuccess, isTrue);
  });

  test('repository failures are propagated', () async {
    const failure = TagRepositoryFailure(message: 'lookup failed');

    when(() => repository.getByIds(any())).thenAnswer((_) async => failure);

    final result = await service.validateForCreate([activeId]);

    expect(result.failureOrNull, same(failure));
  });
}
