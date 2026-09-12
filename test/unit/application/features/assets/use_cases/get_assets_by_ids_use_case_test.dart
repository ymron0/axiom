import 'package:axiom/src/features/assets/domain/failures/asset_already_exists_failure.dart';
import 'package:axiom/src/core/repositories/batch_lookup.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_assets_by_ids_use_case.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/assets/asset_fixtures.dart';
import '../../../../../mocks/asset_repository_mock.dart';

void main() {
  group('GetAssetsByIdsUseCase', () {
    late MockAssetRepository repository;
    late GetAssetsByIdsUseCase useCase;

    setUp(() {
      repository = MockAssetRepository();
      useCase = GetAssetsByIdsUseCase(repository);
    });

    test('returns found and missing assets for a batch lookup', () async {
      // Given
      final asset = currencyFixture(id: 'batch-found', code: 'AAA');
      final ids = [asset.id, AssetId.fromString('batch-missing')];
      final lookup = BatchLookup<Asset, AssetId>(
        found: [asset],
        missing: [ids[1]],
      );
      when(
        () => repository.getByIds(ids),
      ).thenAnswer((_) async => Success<BatchLookup<Asset, AssetId>>(lookup));

      // When
      final result = await useCase.call(ids);

      // Then
      expect(result.valueOrNull, same(lookup));
      verify(() => repository.getByIds(ids)).called(1);
    });

    test('propagates repository failures', () async {
      // Given
      final ids = [AssetId.fromString('batch-failed')];
      const failure = AssetAlreadyExistsFailure(message: 'batch failed');
      when(() => repository.getByIds(ids)).thenAnswer((_) async => failure);

      // When
      final result = await useCase.call(ids);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
