import 'package:axiom/src/core/repositories/batch_lookup.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_assets_by_ids.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_id.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart' hide TestFailure;

import '../../../../../fixtures/core/result/test_failure.dart';
import '../../../../../fixtures/features/assets/asset_fixtures.dart';
import '../../../../../mocks/asset_repository_mock.dart';

void main() {
  group('GetAssetsByIdsUseCase', () {
    test('returns the repository batch lookup result', () async {
      // Given
      final repository = MockAssetRepository();
      final first = currencyFixture(id: 'asset-1');
      final missingId = AssetId.fromString('asset-missing');
      final ids = [first.id, missingId];
      final expected = Success(
        BatchLookup(found: [first], missing: [missingId]),
      );
      when(
        () => repository.getByIds(ids),
      ).thenAnswer((_) async => expected);
      final useCase = GetAssetsByIdsUseCase(repository);

      // When
      final result = await useCase.call(ids);

      // Then
      expect(result, same(expected));
      verify(() => repository.getByIds(ids)).called(1);
    });

    test('returns the repository failure', () async {
      // Given
      final repository = MockAssetRepository();
      final ids = [AssetId.fromString('asset-1')];
      final failure = TestFailure(message: 'Lookup failed.');
      when(
        () => repository.getByIds(ids),
      ).thenAnswer((_) async => failure);
      final useCase = GetAssetsByIdsUseCase(repository);

      // When
      final result = await useCase.call(ids);

      // Then
      expect(result.failureOrNull, same(failure));
      verify(() => repository.getByIds(ids)).called(1);
    });
  });
}
