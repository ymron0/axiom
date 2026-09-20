@Tags(['data', 'persistence'])
library;

import 'package:axiom/src/core/identity/ids/tag_id.dart';
import 'package:axiom/src/core/persistence/sembast_stores.dart';
import 'package:axiom/src/features/tags/data/models/tag_persistence_model.dart';
import 'package:axiom/src/features/tags/data/repositories/sembast_tag_repository_impl.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_name_already_exists_failure.dart';
import 'package:axiom/src/features/tags/data/failures/tag_persistence_failure.dart';
import 'package:sembast/sembast.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/core/persistence/persistence_test_environment.dart';
import '../../../../../fixtures/features/tags/tag_fixtures.dart';

void main() {
  late Database database;
  late SembastTagRepositoryImpl repository;

  setUp(() async {
    final sembastDatabase = await createTestSembastDatabase();

    database = await sembastDatabase.open();

    repository = SembastTagRepositoryImpl(database: database);
  });

  test('created record contains canonical nameKey', () async {
    final tag = tagFixture(id: 'indexed', name: 'Business Trip');

    await repository.create(tag);

    final record = await SembastStores.tags.record(tag.id.value).get(database);

    expect(record![TagPersistenceModel.nameKeyField], 'business trip');
  });

  test('getByName recovers legacy record without nameKey', () async {
    final tag = tagFixture(id: 'legacy', name: 'Business Trip');

    final record = TagPersistenceModel.fromEntity(tag).toRecord()
      ..remove(TagPersistenceModel.nameKeyField);

    await SembastStores.tags.record(tag.id.value).put(database, record);

    final result = await repository.getByName('  BUSINESS   TRIP ');

    expect(result.valueOrNull?.id, tag.id);
  });

  test('legacy record still reserves normalized name', () async {
    final existing = tagFixture(id: 'legacy', name: 'Business Trip');

    final legacyRecord = TagPersistenceModel.fromEntity(existing).toRecord()
      ..remove(TagPersistenceModel.nameKeyField);

    await SembastStores.tags
        .record(existing.id.value)
        .put(database, legacyRecord);

    final duplicate = tagFixture(id: 'new', name: ' BUSINESS   TRIP ');

    final result = await repository.create(duplicate);

    expect(result.failureOrNull, isA<TagNameAlreadyExistsFailure>());
  });

  test('corrupted name index is translated to persistence failure', () async {
    final tag = tagFixture(id: 'corrupt-index', name: 'Business');

    final record = TagPersistenceModel.fromEntity(tag).toRecord();

    record[TagPersistenceModel.nameKeyField] = 'personal';

    await SembastStores.tags.record(tag.id.value).put(database, record);

    final result = await repository.getById(tag.id);

    expect(result.failureOrNull, isA<TagPersistenceFailure>());
  });

  test('duplicate persisted name index is treated as corruption', () async {
    final first = tagFixture(id: 'duplicate-1', name: 'Business');

    final second = tagFixture(id: 'duplicate-2', name: 'BUSINESS');

    await SembastStores.tags
        .record(first.id.value)
        .put(database, TagPersistenceModel.fromEntity(first).toRecord());

    await SembastStores.tags
        .record(second.id.value)
        .put(database, TagPersistenceModel.fromEntity(second).toRecord());

    final result = await repository.getByName('business');

    expect(result.failureOrNull, isA<TagPersistenceFailure>());
  });

  test('update ignores own indexed identity during uniqueness check', () async {
    final original = tagFixture(id: 'update-self', name: 'Business');

    await repository.create(original);

    final changed = tagFixture(
      id: original.id.value,
      name: 'BUSINESS',
      modifiedAt: DateTime.utc(2026, 2, 1),
    );

    final result = await repository.update(changed);

    expect(result.isSuccess, isTrue);

    final stored = await repository.getById(TagId.fromString('update-self'));

    expect(stored.valueOrNull?.name, 'BUSINESS');
  });
}
