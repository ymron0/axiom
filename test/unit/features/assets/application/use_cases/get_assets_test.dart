import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_assets.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/assets/asset_fixtures.dart';
import '../../../../../mocks/asset_repository_mock.dart';

void main() {
  group('GetAssetsUseCase', () {
    test('returns every asset from the repository', () async {
      // Given
      final repository = MockAssetRepository();
      final assets = [currencyFixture()];
      when(() => repository.getAll()).thenAnswer((_) async => Success(assets));
      final useCase = GetAssetsUseCase(repository);

      // When
      final result = await useCase.call();

      // Then
      expect(result.valueOrNull, same(assets));
      verify(() => repository.getAll()).called(1);
    });
  });
}
