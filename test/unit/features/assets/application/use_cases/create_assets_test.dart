import 'package:axiom/src/core/failures/record_already_exists_failure.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/application/use_cases/create_assets.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/assets/asset_fixtures.dart';
import '../../../../../mocks/asset_repository_mock.dart';

void main() {
  group('CreateAssetsUseCase', () {
    test('returns the created assets from the repository', () async {
      // Given
      final repository = MockAssetRepository();
      final assets = [
        currencyFixture(),
        currencyFixture(
          id: 'asset-2',
          name: 'United States Dollar',
          code: 'USD',
        ),
      ];
      final expected = Success(assets);
      when(
        () => repository.createAll(assets),
      ).thenAnswer((_) async => expected);
      final useCase = CreateAssetsUseCase(repository);

      // When
      final result = await useCase.call(assets);

      // Then
      expect(result, same(expected));
      verify(() => repository.createAll(assets)).called(1);
    });

    test('returns the repository failure when creation fails', () async {
      // Given
      final repository = MockAssetRepository();
      final assets = [currencyFixture()];
      const failure = RecordAlreadyExistsFailure(
        message: 'Asset ID already exists.',
      );
      when(
        () => repository.createAll(assets),
      ).thenAnswer((_) async => failure);
      final useCase = CreateAssetsUseCase(repository);

      // When
      final result = await useCase.call(assets);

      // Then
      expect(result.failureOrNull, same(failure));
      verify(() => repository.createAll(assets)).called(1);
    });
  });
}
