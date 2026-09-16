@Tags(['data', 'persistence'])
library;

import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/persistence/sembast_stores.dart';
import 'package:axiom/src/features/assets/data/repositories/sembast_asset_repository_impl.dart';
import 'package:axiom/src/features/assets/domain/failures/asset_already_exists_failure.dart';
import 'package:axiom/src/features/assets/domain/failures/asset_not_found_failure.dart';
import 'package:axiom/src/features/assets/domain/failures/asset_persistence_failure.dart';
import 'package:axiom/src/features/assets/domain/repositories/asset_repository.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_code.dart';
import 'package:sembast/sembast.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/core/persistence/persistence_test_environment.dart';
import '../../../../../fixtures/features/assets/asset_fixtures.dart';

void main() {
  late Database database;
  late AssetRepository repository;

  setUp(() async {
    final sembastDatabase = await createTestSembastDatabase();
    database = await sembastDatabase.open();

    repository = SembastAssetRepositoryImpl(database: database);
  });

  group('SembastAssetRepositoryImpl', () {
    group('initial state', () {
      test('starts empty and exposes an immutable result', () async {
        // When
        final result = await repository.getAll();

        // Then
        expect(result.isSuccess, isTrue);

        final assets = result.valueOrNull!;
        expect(assets, isEmpty);
        expect(() => assets.clear(), throwsUnsupportedError);
      });
    });

    group('create', () {
      test('persists and reconstructs an asset', () async {
        // Given
        final asset = currencyFixture(
          id: 'persistent-create',
          name: 'Test Currency',
          code: 'AAA',
        );

        // When
        final result = await repository.create(asset);

        // Then
        expect(result.isSuccess, isTrue);

        final stored = (await repository.getById(asset.id)).valueOrNull;

        expect(stored, isNotNull);
        expect(stored!.id, asset.id);
        expect(stored.name, asset.name);
        expect(stored.code, asset.code);
        expect(stored.decimalPlaces, asset.decimalPlaces);
        expect(stored.entityVersion, asset.entityVersion);
      });

      test('returns AssetAlreadyExistsFailure for a duplicate ID', () async {
        // Given
        final original = currencyFixture(
          id: 'duplicate-id',
          name: 'Original',
          code: 'AAA',
        );
        final duplicate = currencyFixture(
          id: original.id.value,
          name: 'Replacement',
          code: 'BBB',
        );

        await repository.create(original);

        // When
        final result = await repository.create(duplicate);

        // Then
        expect(result.failureOrNull, isA<AssetAlreadyExistsFailure>());

        final stored = (await repository.getById(original.id)).valueOrNull;
        expect(stored?.name, 'Original');
        expect(stored?.code.value, 'AAA');
      });

      test('returns AssetAlreadyExistsFailure for a duplicate code', () async {
        // Given
        final original = currencyFixture(
          id: 'duplicate-code-original',
          code: 'AAA',
        );
        final duplicate = currencyFixture(
          id: 'duplicate-code-new',
          code: 'AAA',
        );

        await repository.create(original);

        // When
        final result = await repository.create(duplicate);

        // Then
        expect(result.failureOrNull, isA<AssetAlreadyExistsFailure>());
        expect((await repository.getById(duplicate.id)).valueOrNull, isNull);
      });
    });

    group('createAll', () {
      test(
        'persists all assets atomically and returns an immutable list',
        () async {
          // Given
          final first = currencyFixture(id: 'batch-first', code: 'AAA');
          final second = currencyFixture(id: 'batch-second', code: 'BBB');

          // When
          final result = await repository.createAll([first, second]);

          // Then
          expect(result.isSuccess, isTrue);

          final created = result.valueOrNull!;
          expect(created.map((asset) => asset.id), [first.id, second.id]);
          expect(() => created.clear(), throwsUnsupportedError);

          expect(
            (await repository.getById(first.id)).valueOrNull?.id,
            first.id,
          );
          expect(
            (await repository.getById(second.id)).valueOrNull?.id,
            second.id,
          );
        },
      );

      test('accepts an empty batch', () async {
        // When
        final result = await repository.createAll([]);

        // Then
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull, isEmpty);
        expect(() => result.valueOrNull!.clear(), throwsUnsupportedError);
      });

      test('is atomic when an ID already exists', () async {
        // Given
        final existing = currencyFixture(id: 'batch-existing', code: 'AAA');
        final fresh = currencyFixture(id: 'batch-fresh', code: 'BBB');

        await repository.create(existing);

        // When
        final result = await repository.createAll([fresh, existing]);

        // Then
        expect(result.failureOrNull, isA<AssetAlreadyExistsFailure>());
        expect((await repository.getById(fresh.id)).valueOrNull, isNull);
      });

      test('is atomic when request contains duplicate codes', () async {
        // Given
        final first = currencyFixture(id: 'batch-code-first', code: 'AAA');
        final second = currencyFixture(id: 'batch-code-second', code: 'AAA');

        // When
        final result = await repository.createAll([first, second]);

        // Then
        expect(result.failureOrNull, isA<AssetAlreadyExistsFailure>());
        expect((await repository.getAll()).valueOrNull, isEmpty);
      });
    });

    group('queries', () {
      test('gets an asset by code', () async {
        // Given
        final first = currencyFixture(id: 'by-code-first', code: 'AAA');
        final second = currencyFixture(id: 'by-code-second', code: 'BBB');

        await repository.createAll([first, second]);

        // When
        final result = await repository.getByCode(AssetCode('BBB'));

        // Then
        expect(result.valueOrNull?.id, second.id);
      });

      test('returns null when ID or code is missing', () async {
        // When
        final byId = await repository.getById(AssetId.fromString('missing-id'));
        final byCode = await repository.getByCode(AssetCode('ZZZ'));

        // Then
        expect(byId.isSuccess, isTrue);
        expect(byId.valueOrNull, isNull);

        expect(byCode.isSuccess, isTrue);
        expect(byCode.valueOrNull, isNull);
      });

      test(
        'getByIds deduplicates requests and preserves request order',
        () async {
          // Given
          final first = currencyFixture(id: 'lookup-first', code: 'AAA');
          final second = currencyFixture(id: 'lookup-second', code: 'BBB');
          final missing = AssetId.fromString('lookup-missing');

          await repository.createAll([first, second]);

          // When
          final result = await repository.getByIds([
            missing,
            second.id,
            first.id,
            missing,
            second.id,
          ]);

          // Then
          final lookup = result.valueOrNull!;

          expect(lookup.found.map((asset) => asset.id), [second.id, first.id]);
          expect(lookup.missing, [missing]);

          expect(() => lookup.found.clear(), throwsUnsupportedError);
          expect(() => lookup.missing.clear(), throwsUnsupportedError);
        },
      );
    });

    group('update', () {
      test('replaces an existing asset', () async {
        // Given
        final original = currencyFixture(
          id: 'update-asset',
          name: 'Original',
          code: 'AAA',
        );
        final replacement = currencyFixture(
          id: original.id.value,
          name: 'Replacement',
          code: 'AAA',
        );

        await repository.create(original);

        // When
        final result = await repository.update(replacement);

        // Then
        expect(result.isSuccess, isTrue);

        final stored = (await repository.getById(original.id)).valueOrNull;
        expect(stored?.name, 'Replacement');
      });

      test('returns AssetNotFoundFailure for a missing asset', () async {
        // Given
        final missing = currencyFixture(id: 'update-missing', code: 'AAA');

        // When
        final result = await repository.update(missing);

        // Then
        expect(result.failureOrNull, isA<AssetNotFoundFailure>());
      });

      test('rejects a conflicting code without mutation', () async {
        // Given
        final first = currencyFixture(
          id: 'update-code-first',
          name: 'First',
          code: 'AAA',
        );
        final second = currencyFixture(
          id: 'update-code-second',
          name: 'Second',
          code: 'BBB',
        );

        await repository.createAll([first, second]);

        final conflicting = currencyFixture(
          id: first.id.value,
          name: 'Conflicting',
          code: second.code.value,
        );

        // When
        final result = await repository.update(conflicting);

        // Then
        expect(result.failureOrNull, isA<AssetAlreadyExistsFailure>());

        final stored = (await repository.getById(first.id)).valueOrNull;
        expect(stored?.name, 'First');
        expect(stored?.code, first.code);
      });
    });

    group('updateAll', () {
      test(
        'updates all assets atomically and returns immutable results',
        () async {
          // Given
          final first = currencyFixture(
            id: 'update-all-first',
            name: 'First',
            code: 'AAA',
          );
          final second = currencyFixture(
            id: 'update-all-second',
            name: 'Second',
            code: 'BBB',
          );

          await repository.createAll([first, second]);

          final firstUpdate = currencyFixture(
            id: first.id.value,
            name: 'First updated',
            code: 'AAA',
          );
          final secondUpdate = currencyFixture(
            id: second.id.value,
            name: 'Second updated',
            code: 'BBB',
          );

          // When
          final result = await repository.updateAll([
            firstUpdate,
            secondUpdate,
          ]);

          // Then
          expect(result.isSuccess, isTrue);

          final updated = result.valueOrNull!;
          expect(updated, hasLength(2));
          expect(() => updated.clear(), throwsUnsupportedError);

          expect(
            (await repository.getById(first.id)).valueOrNull?.name,
            'First updated',
          );
          expect(
            (await repository.getById(second.id)).valueOrNull?.name,
            'Second updated',
          );
        },
      );

      test('does not partially update when one ID is missing', () async {
        // Given
        final original = currencyFixture(
          id: 'atomic-update-original',
          name: 'Original',
          code: 'AAA',
        );
        await repository.create(original);

        final replacement = currencyFixture(
          id: original.id.value,
          name: 'Replacement',
          code: 'AAA',
        );
        final missing = currencyFixture(
          id: 'atomic-update-missing',
          code: 'BBB',
        );

        // When
        final result = await repository.updateAll([replacement, missing]);

        // Then
        expect(result.failureOrNull, isA<AssetNotFoundFailure>());
        expect(
          (await repository.getById(original.id)).valueOrNull?.name,
          'Original',
        );
      });
    });

    group('persistence failure translation', () {
      test('translates malformed persisted data', () async {
        // Given
        const id = 'corrupt-asset';

        await SembastStores.assets
            .record(id)
            .put(database, <String, Object?>{});

        // When
        final result = await repository.getById(AssetId.fromString(id));

        // Then
        expect(result.failureOrNull, isA<AssetPersistenceFailure>());
      });
    });
  });
}
