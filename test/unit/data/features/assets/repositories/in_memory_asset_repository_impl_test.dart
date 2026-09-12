import 'package:axiom/src/features/assets/data/repositories/in_memory_asset_repository_impl.dart';
import 'package:axiom/src/features/assets/domain/failures/asset_already_exists_failure.dart';
import 'package:axiom/src/features/assets/domain/failures/asset_not_found_failure.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_code.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/assets/asset_fixtures.dart';

void main() {
  group('InMemoryAssetRepositoryImpl', () {
    group('create', () {
      test('creates an asset', () async {
        // Given
        final repository = _createRepository();
        final asset = currencyFixture(id: 'create-asset', code: 'AAA');

        // When
        final result = await repository.create(asset);

        // Then
        expect(result.valueOrNull, same(asset));
        expect((await repository.getById(asset.id)).valueOrNull, same(asset));
      });

      test('returns AssetAlreadyExistsFailure when the asset exists', () async {
        // Given
        final repository = _createRepository();
        final original = currencyFixture(id: 'create-duplicate', code: 'AAA');
        await repository.create(original);
        final duplicate = currencyFixture(
          id: 'create-duplicate',
          name: 'Duplicate',
          code: 'AAA',
        );

        // When
        final result = await repository.create(duplicate);

        // Then
        expect(result.failureOrNull, isA<AssetAlreadyExistsFailure>());
        expect(
          (await repository.getById(original.id)).valueOrNull,
          same(original),
        );
      });

      test('returns AssetAlreadyExistsFailure when the code exists', () async {
        // Given
        final repository = _createRepository();
        final original = currencyFixture(
          id: 'create-code-original',
          code: 'AAA',
        );
        await repository.create(original);
        final duplicate = currencyFixture(
          id: 'create-code-duplicate',
          code: original.code.value,
        );

        // When
        final result = await repository.create(duplicate);

        // Then
        expect(result.failureOrNull, isA<AssetAlreadyExistsFailure>());
        expect((await repository.getById(duplicate.id)).valueOrNull, isNull);
      });

      test('rejects concurrent creates with the same ID', () async {
        // Given
        final repository = _createRepository();
        final first = currencyFixture(id: 'create-concurrent', code: 'AAA');
        final second = currencyFixture(id: 'create-concurrent', code: 'BBB');

        // When
        final results = [repository.create(first), repository.create(second)];
        final completedResults = await Future.wait(results);

        // Then
        expect(
          completedResults.where((result) => result.valueOrNull != null),
          hasLength(1),
        );
        expect(
          completedResults.where(
            (result) => result.failureOrNull is AssetAlreadyExistsFailure,
          ),
          hasLength(1),
        );
        expect((await repository.getById(first.id)).valueOrNull, isNotNull);
      });
    });

    group('createAll', () {
      test('creates two assets at the same time', () async {
        // Given
        final repository = _createRepository();
        final first = currencyFixture(id: 'create-all-first', code: 'AAA');
        final second = currencyFixture(id: 'create-all-second', code: 'BBB');

        // When
        final result = await repository.createAll([first, second]);

        // Then
        expect(result.valueOrNull, hasLength(2));
        expect(result.valueOrNull![0], same(first));
        expect(result.valueOrNull![1], same(second));
      });

      test('rejects duplicate IDs without partial mutation', () async {
        // Given
        final repository = _createRepository();
        final first = currencyFixture(
          id: 'create-all-duplicate-id',
          code: 'AAA',
        );
        final duplicate = currencyFixture(
          id: 'create-all-duplicate-id',
          code: 'BBB',
        );

        // When
        final result = await repository.createAll([first, duplicate]);

        // Then
        expect(result.failureOrNull, isA<AssetAlreadyExistsFailure>());
        expect((await repository.getById(first.id)).valueOrNull, isNull);
      });

      test(
        'returns AssetAlreadyExistsFailure when one asset already exists',
        () async {
          // Given
          final repository = _createRepository();
          final newAsset = currencyFixture(id: 'create-all-new', code: 'AAA');
          final existingAsset = currencyFixture(id: 'asset-eur');

          // When
          final result = await repository.createAll([newAsset, existingAsset]);

          // Then
          expect(result.failureOrNull, isA<AssetAlreadyExistsFailure>());
          expect((await repository.getById(newAsset.id)).valueOrNull, isNull);
        },
      );

      test('rejects duplicate codes without partial mutation', () async {
        // Given
        final repository = _createRepository();
        final first = currencyFixture(id: 'create-all-code-first', code: 'AAA');
        final duplicate = currencyFixture(
          id: 'create-all-code-second',
          code: first.code.value,
        );

        // When
        final result = await repository.createAll([first, duplicate]);

        // Then
        expect(result.failureOrNull, isA<AssetAlreadyExistsFailure>());
        expect((await repository.getById(first.id)).valueOrNull, isNull);
        expect((await repository.getById(duplicate.id)).valueOrNull, isNull);
      });

      test('rejects a code that already exists', () async {
        // Given
        final repository = _createRepository();
        final duplicate = currencyFixture(
          id: 'create-all-existing-code',
          code: 'EUR',
        );

        // When
        final result = await repository.createAll([duplicate]);

        // Then
        expect(result.failureOrNull, isA<AssetAlreadyExistsFailure>());
        expect((await repository.getById(duplicate.id)).valueOrNull, isNull);
      });
    });

    group('getAll', () {
      test('returns the full list of assets', () async {
        // Given
        final repository = _createRepository();

        // When
        final result = await repository.getAll();

        // Then
        final assets = result.valueOrNull!;
        expect(assets.map((asset) => asset.id.value).toList(), [
          'asset-eur',
          'asset-chf',
          'asset-usd',
        ]);
      });
    });

    group('getById', () {
      test('returns the asset with the requested ID', () async {
        // Given
        final repository = _createRepository();
        final first = currencyFixture(id: 'get-by-id-first', code: 'AAA');
        final second = currencyFixture(id: 'get-by-id-second', code: 'BBB');
        await repository.createAll([first, second]);

        // When
        final result = await repository.getById(second.id);

        // Then
        expect(result.valueOrNull, same(second));
      });

      test('returns null when the ID is not found', () async {
        // Given
        final repository = _createRepository();

        // When
        final result = await repository.getById(
          currencyFixture(id: 'missing-id').id,
        );

        // Then
        expect(result.valueOrNull, isNull);
      });
    });

    group('getByCode', () {
      test('returns the asset with the requested code', () async {
        // Given
        final repository = _createRepository();
        final first = currencyFixture(id: 'get-by-code-first', code: 'AAA');
        final second = currencyFixture(id: 'get-by-code-second', code: 'BBB');
        await repository.createAll([first, second]);

        // When
        final result = await repository.getByCode(AssetCode('BBB'));

        // Then
        expect(result.valueOrNull, hasLength(1));
        expect(result.valueOrNull!.single, same(second));
      });

      test('returns an empty list when the code is not found', () async {
        // Given
        final repository = _createRepository();

        // When
        final result = await repository.getByCode(AssetCode('MISSING'));

        // Then
        expect(result.valueOrNull, isEmpty);
      });
    });

    group('getByIds', () {
      test('returns the two requested assets but not the third', () async {
        // Given
        final repository = _createRepository();
        final first = currencyFixture(id: 'get-by-ids-first', code: 'AAA');
        final second = currencyFixture(id: 'get-by-ids-second', code: 'BBB');
        final third = currencyFixture(id: 'get-by-ids-third', code: 'CCC');
        await repository.createAll([first, second, third]);

        // When
        final result = await repository.getByIds([first.id, second.id]);

        // Then
        final lookup = result.valueOrNull!;
        expect(lookup.found, hasLength(2));
        expect(lookup.found[0], same(first));
        expect(lookup.found[1], same(second));
        expect(lookup.found, isNot(contains(same(third))));
      });

      test('deduplicates requests and preserves missing ID order', () async {
        // Given
        final repository = _createRepository();
        final existing = currencyFixture(
          id: 'get-by-ids-existing',
          code: 'AAA',
        );
        await repository.create(existing);
        final firstMissing = currencyFixture(id: 'get-by-ids-missing-first').id;
        final secondMissing = currencyFixture(
          id: 'get-by-ids-missing-second',
        ).id;

        // When
        final result = await repository.getByIds([
          secondMissing,
          existing.id,
          firstMissing,
          secondMissing,
        ]);

        // Then
        final lookup = result.valueOrNull!;
        expect(lookup.found, [same(existing)]);
        expect(lookup.missing, [secondMissing, firstMissing]);
      });
    });

    group('update', () {
      test('updates an existing asset', () async {
        // Given
        final repository = _createRepository();
        final original = currencyFixture(id: 'update-asset', code: 'AAA');
        await repository.create(original);
        final updated = currencyFixture(
          id: 'update-asset',
          name: 'Updated Euro',
          code: 'AAA',
        );

        // When
        final result = await repository.update(updated);

        // Then
        expect(result.valueOrNull, same(updated));
        expect(
          (await repository.getById(updated.id)).valueOrNull,
          same(updated),
        );
      });

      test(
        'returns AssetNotFoundFailure when the asset does not exist',
        () async {
          // Given
          final repository = _createRepository();
          final missing = currencyFixture(id: 'update-missing');

          // When
          final result = await repository.update(missing);

          // Then
          expect(result.failureOrNull, isA<AssetNotFoundFailure>());
        },
      );

      test(
        'returns AssetAlreadyExistsFailure for a conflicting code',
        () async {
          // Given
          final repository = _createRepository();
          final original = currencyFixture(
            id: 'update-code-original',
            code: 'AAA',
          );
          final other = currencyFixture(id: 'update-code-other', code: 'BBB');
          await repository.createAll([original, other]);
          final conflicting = currencyFixture(
            id: original.id.value,
            code: other.code.value,
          );

          // When
          final result = await repository.update(conflicting);

          // Then
          expect(result.failureOrNull, isA<AssetAlreadyExistsFailure>());
          expect(
            (await repository.getById(original.id)).valueOrNull,
            same(original),
          );
        },
      );
    });

    group('updateAll', () {
      test('updates several assets together', () async {
        // Given
        final repository = _createRepository();
        final first = currencyFixture(id: 'update-all-first', code: 'AAA');
        final second = currencyFixture(id: 'update-all-second', code: 'BBB');
        await repository.createAll([first, second]);
        final firstUpdate = currencyFixture(
          id: 'update-all-first',
          name: 'Updated first',
          code: 'AAA',
        );
        final secondUpdate = currencyFixture(
          id: 'update-all-second',
          name: 'Updated second',
          code: 'BBB',
        );

        // When
        final result = await repository.updateAll([firstUpdate, secondUpdate]);

        // Then
        expect(result.valueOrNull, hasLength(2));
        expect(
          (await repository.getById(first.id)).valueOrNull,
          same(firstUpdate),
        );
        expect(
          (await repository.getById(second.id)).valueOrNull,
          same(secondUpdate),
        );
      });

      test(
        'returns AssetAlreadyExistsFailure for duplicate update IDs',
        () async {
          // Given
          final repository = _createRepository();
          final original = currencyFixture(
            id: 'update-all-duplicate',
            code: 'AAA',
          );
          await repository.create(original);
          final firstUpdate = currencyFixture(
            id: 'update-all-duplicate',
            name: 'First update',
            code: 'AAA',
          );
          final secondUpdate = currencyFixture(
            id: 'update-all-duplicate',
            name: 'Second update',
            code: 'AAA',
          );

          // When
          final result = await repository.updateAll([
            firstUpdate,
            secondUpdate,
          ]);

          // Then
          expect(result.failureOrNull, isA<AssetAlreadyExistsFailure>());
          expect(
            (await repository.getById(original.id)).valueOrNull,
            same(original),
          );
        },
      );

      test(
        'returns AssetAlreadyExistsFailure when a code belongs to another asset',
        () async {
          // Given
          final repository = _createRepository();
          final original = currencyFixture(
            id: 'update-all-existing-code',
            code: 'AAA',
          );
          await repository.create(original);
          final conflicting = currencyFixture(
            id: original.id.value,
            code: 'EUR',
          );

          // When
          final result = await repository.updateAll([conflicting]);

          // Then
          expect(result.failureOrNull, isA<AssetAlreadyExistsFailure>());
          expect(
            (await repository.getById(original.id)).valueOrNull,
            same(original),
          );
        },
      );

      test(
        'returns AssetNotFoundFailure when an asset does not exist',
        () async {
          // Given
          final repository = _createRepository();
          final existing = currencyFixture(
            id: 'update-all-existing',
            code: 'AAA',
          );
          await repository.create(existing);
          final existingUpdate = currencyFixture(
            id: 'update-all-existing',
            name: 'Updated existing',
            code: 'AAA',
          );
          final missing = currencyFixture(
            id: 'update-all-missing',
            code: 'BBB',
          );

          // When
          final result = await repository.updateAll([existingUpdate, missing]);

          // Then
          expect(result.failureOrNull, isA<AssetNotFoundFailure>());
          expect(
            (await repository.getById(existing.id)).valueOrNull,
            same(existing),
          );
        },
      );

      test('rejects conflicting codes without partial mutation', () async {
        // Given
        final repository = _createRepository();
        final first = currencyFixture(id: 'update-all-code-first', code: 'AAA');
        final second = currencyFixture(
          id: 'update-all-code-second',
          code: 'BBB',
        );
        await repository.createAll([first, second]);
        final firstUpdate = currencyFixture(id: first.id.value, code: 'CCC');
        final secondUpdate = currencyFixture(id: second.id.value, code: 'CCC');

        // When
        final result = await repository.updateAll([firstUpdate, secondUpdate]);

        // Then
        expect(result.failureOrNull, isA<AssetAlreadyExistsFailure>());
        expect((await repository.getById(first.id)).valueOrNull, same(first));
        expect((await repository.getById(second.id)).valueOrNull, same(second));
      });
    });
  });
}

InMemoryAssetRepositoryImpl _createRepository() {
  return InMemoryAssetRepositoryImpl(
    initialAssets: [
      currencyFixture(id: 'asset-eur', name: 'Euro', code: 'EUR'),
      currencyFixture(id: 'asset-chf', name: 'Swiss franc', code: 'CHF'),
      currencyFixture(id: 'asset-usd', name: 'US dollar', code: 'USD'),
    ],
  );
}
