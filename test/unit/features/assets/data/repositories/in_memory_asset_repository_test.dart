import 'package:axiom/src/core/failures/record_already_exists_failure.dart';
import 'package:axiom/src/core/failures/record_not_found_failure.dart';
import 'package:axiom/src/features/assets/data/repositories/in_memory_asset_repository.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_code.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/assets/asset_fixtures.dart';

void main() {
  group('InMemoryAssetRepository', () {
    group('create', () {
      test('creates an asset', () async {
        // Given
        final repository = InMemoryAssetRepository();
        final asset = currencyFixture(id: 'create-asset');

        // When
        final result = await repository.create(asset);

        // Then
        expect(result.valueOrNull, same(asset));
        expect((await repository.getById(asset.id)).valueOrNull, same(asset));
      });

      test('returns RecordAlreadyExistsFailure when the asset exists', () async {
        // Given
        final repository = InMemoryAssetRepository();
        final original = currencyFixture(id: 'create-duplicate');
        await repository.create(original);
        final duplicate = currencyFixture(
          id: 'create-duplicate',
          name: 'Duplicate',
        );

        // When
        final result = await repository.create(duplicate);

        // Then
        expect(result.failureOrNull, isA<RecordAlreadyExistsFailure>());
        expect(
          (await repository.getById(original.id)).valueOrNull,
          same(original),
        );
      });
    });

    group('createAll', () {
      test('creates two assets at the same time', () async {
        // Given
        final repository = InMemoryAssetRepository();
        final first = currencyFixture(id: 'create-all-first');
        final second = currencyFixture(
          id: 'create-all-second',
          code: 'CHF',
        );

        // When
        final result = await repository.createAll([first, second]);

        // Then
        expect(result.valueOrNull, hasLength(2));
        expect(result.valueOrNull![0], same(first));
        expect(result.valueOrNull![1], same(second));
      });

      test(
        'returns RecordAlreadyExistsFailure when one asset already exists',
        () async {
          // Given
          final repository = InMemoryAssetRepository();
          final newAsset = currencyFixture(id: 'create-all-new');
          final existingAsset = currencyFixture(id: 'asset-eur');

          // When
          final result = await repository.createAll([
            newAsset,
            existingAsset,
          ]);

          // Then
          expect(result.failureOrNull, isA<RecordAlreadyExistsFailure>());
          expect(
            (await repository.getById(newAsset.id)).valueOrNull,
            isNull,
          );
        },
      );
    });

    group('getAll', () {
      test('returns the full list of assets', () async {
        // Given
        final repository = InMemoryAssetRepository();

        // When
        final result = await repository.getAll();

        // Then
        final assets = result.valueOrNull!;
        expect(
          assets.map((asset) => asset.id.value).toList(),
          ['asset-eur', 'asset-chf', 'asset-usd'],
        );
      });
    });

    group('getById', () {
      test('returns the asset with the requested ID', () async {
        // Given
        final repository = InMemoryAssetRepository();
        final first = currencyFixture(id: 'get-by-id-first');
        final second = currencyFixture(id: 'get-by-id-second', code: 'CHF');
        await repository.createAll([first, second]);

        // When
        final result = await repository.getById(second.id);

        // Then
        expect(result.valueOrNull, same(second));
      });

      test('returns null when the ID is not found', () async {
        // Given
        final repository = InMemoryAssetRepository();

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
        final repository = InMemoryAssetRepository();
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
        final repository = InMemoryAssetRepository();

        // When
        final result = await repository.getByCode(AssetCode('MISSING'));

        // Then
        expect(result.valueOrNull, isEmpty);
      });
    });

    group('getByIds', () {
      test('returns the two requested assets but not the third', () async {
        // Given
        final repository = InMemoryAssetRepository();
        final first = currencyFixture(id: 'get-by-ids-first');
        final second = currencyFixture(id: 'get-by-ids-second', code: 'CHF');
        final third = currencyFixture(id: 'get-by-ids-third', code: 'USD');
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
    });

    group('update', () {
      test('updates an existing asset', () async {
        // Given
        final repository = InMemoryAssetRepository();
        final original = currencyFixture(id: 'update-asset');
        await repository.create(original);
        final updated = currencyFixture(
          id: 'update-asset',
          name: 'Updated Euro',
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
        'returns RecordNotFoundFailure when the asset does not exist',
        () async {
          // Given
          final repository = InMemoryAssetRepository();
          final missing = currencyFixture(id: 'update-missing');

          // When
          final result = await repository.update(missing);

          // Then
          expect(result.failureOrNull, isA<RecordNotFoundFailure>());
        },
      );
    });

    group('updateAll', () {
      test('updates several assets together', () async {
        // Given
        final repository = InMemoryAssetRepository();
        final first = currencyFixture(id: 'update-all-first');
        final second = currencyFixture(id: 'update-all-second', code: 'CHF');
        await repository.createAll([first, second]);
        final firstUpdate = currencyFixture(
          id: 'update-all-first',
          name: 'Updated first',
        );
        final secondUpdate = currencyFixture(
          id: 'update-all-second',
          name: 'Updated second',
          code: 'CHF',
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
        'returns RecordAlreadyExistsFailure for duplicate update IDs',
        () async {
          // Given
          final repository = InMemoryAssetRepository();
          final original = currencyFixture(id: 'update-all-duplicate');
          await repository.create(original);
          final firstUpdate = currencyFixture(
            id: 'update-all-duplicate',
            name: 'First update',
          );
          final secondUpdate = currencyFixture(
            id: 'update-all-duplicate',
            name: 'Second update',
          );

          // When
          final result = await repository.updateAll([
            firstUpdate,
            secondUpdate,
          ]);

          // Then
          expect(result.failureOrNull, isA<RecordAlreadyExistsFailure>());
          expect(
            (await repository.getById(original.id)).valueOrNull,
            same(original),
          );
        },
      );

      test(
        'returns RecordNotFoundFailure when an asset does not exist',
        () async {
          // Given
          final repository = InMemoryAssetRepository();
          final existing = currencyFixture(id: 'update-all-existing');
          await repository.create(existing);
          final existingUpdate = currencyFixture(
            id: 'update-all-existing',
            name: 'Updated existing',
          );
          final missing = currencyFixture(id: 'update-all-missing');

          // When
          final result = await repository.updateAll([
            existingUpdate,
            missing,
          ]);

          // Then
          expect(result.failureOrNull, isA<RecordNotFoundFailure>());
          expect(
            (await repository.getById(existing.id)).valueOrNull,
            same(existing),
          );
        },
      );
    });
  });
}
