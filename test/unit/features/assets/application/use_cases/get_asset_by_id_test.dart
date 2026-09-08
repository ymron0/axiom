import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_asset_by_id.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/assets/asset_fixtures.dart';
import '../../../../../mocks/asset_repository_mock.dart';

void main() {
  group('GetAssetByIdUseCase', () {
    test('returns the asset identified by the requested ID', () async {
      // Given
      final repository = MockAssetRepository();
      final asset = currencyFixture();
      when(
        () => repository.getById(asset.id),
      ).thenAnswer((_) async => Success(asset));
      final useCase = GetAssetByIdUseCase(repository);

      // When
      final result = await useCase.call(asset.id);

      // Then
      expect(result.valueOrNull, same(asset));
      verify(() => repository.getById(asset.id)).called(1);
    });
  });
}
