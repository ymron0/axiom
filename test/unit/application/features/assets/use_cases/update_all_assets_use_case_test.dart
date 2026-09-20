@Tags(['application'])
library;

import 'package:axiom/src/core/repositories/batch_lookup.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/application/failures/asset_type_change_not_allowed_failure.dart';
import 'package:axiom/src/features/assets/application/use_cases/update_all_assets_use_case.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/assets/domain/failures/asset_not_found_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/assets/asset_fixtures.dart';
import '../../../../../mocks/asset_repository_mock.dart';

void main() {
  late MockAssetRepository repository;
  late UpdateAllAssetsUseCase useCase;

  setUp(() {
    repository = MockAssetRepository();
    useCase = UpdateAllAssetsUseCase(repository);
  });

  test('updates an empty batch directly', () async {
    when(
      () => repository.updateAll(const []),
    ).thenAnswer((_) async => const Success<List<Asset>>([]));

    final result = await useCase(const []);

    expect(result.valueOrNull, isEmpty);
    verify(() => repository.updateAll(const [])).called(1);
    verifyNever(() => repository.getByIds(any()));
  });

  test('validates all types before updating the batch', () async {
    final existing = currencyFixture(id: 'currency');
    final updated = currencyFixture(id: 'currency', name: 'Updated');
    when(() => repository.getByIds([existing.id])).thenAnswer(
      (_) async => Success(
        BatchLookup<Asset, AssetId>(found: [existing], missing: const []),
      ),
    );
    when(
      () => repository.updateAll([updated]),
    ).thenAnswer((_) async => Success<List<Asset>>([updated]));

    final result = await useCase([updated]);

    expect(result.valueOrNull, [updated]);
    verify(() => repository.updateAll([updated])).called(1);
  });

  test('returns a missing-id failure without updating', () async {
    final updated = currencyFixture(id: 'missing');
    when(() => repository.getByIds([updated.id])).thenAnswer(
      (_) async => Success(
        BatchLookup<Asset, AssetId>(found: const [], missing: [updated.id]),
      ),
    );

    final result = await useCase([updated]);

    expect(result.failureOrNull, isA<AssetNotFoundFailure>());
    verifyNever(() => repository.updateAll(any()));
  });

  test('rejects a subtype change without updating', () async {
    final existing = currencyFixture(id: 'same');
    final updated = cryptoAssetFixture(id: 'same');
    when(() => repository.getByIds([existing.id])).thenAnswer(
      (_) async => Success(
        BatchLookup<Asset, AssetId>(found: [existing], missing: const []),
      ),
    );

    final result = await useCase([updated]);

    expect(result.failureOrNull, isA<AssetTypeChangeNotAllowedFailure>());
    verifyNever(() => repository.updateAll(any()));
  });
}
