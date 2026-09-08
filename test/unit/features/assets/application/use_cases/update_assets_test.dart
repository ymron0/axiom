import 'package:axiom/src/core/failures/record_not_found_failure.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/application/use_cases/update_assets.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/assets/asset_fixtures.dart';
import '../../../../../mocks/asset_repository_mock.dart';

void main() {
  group('UpdateAssetsUseCase', () {
    test('returns the updated assets from the repository', () async {
      // Given
      final repository = MockAssetRepository();
      final assets = [
        currencyFixture(),
        currencyFixture(
          id: 'asset-2',
          name: 'Swiss Franc',
          code: 'CHF',
        ),
      ];
      final expected = Success(assets);
      when(
        () => repository.updateAll(assets),
      ).thenAnswer((_) async => expected);
      final useCase = UpdateAssetsUseCase(repository);

      // When
      final result = await useCase.call(assets);

      // Then
      expect(result, same(expected));
      verify(() => repository.updateAll(assets)).called(1);
    });

    test('returns the repository failure when updating fails', () async {
      // Given
      final repository = MockAssetRepository();
      final assets = [currencyFixture()];
      const failure = RecordNotFoundFailure(
        message: 'An asset ID was not found.',
      );
      when(
        () => repository.updateAll(assets),
      ).thenAnswer((_) async => failure);
      final useCase = UpdateAssetsUseCase(repository);

      // When
      final result = await useCase.call(assets);

      // Then
      expect(result.failureOrNull, same(failure));
      verify(() => repository.updateAll(assets)).called(1);
    });
  });
}
