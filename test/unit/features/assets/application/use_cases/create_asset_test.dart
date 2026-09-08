import 'package:axiom/src/core/failures/record_already_exists_failure.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/application/use_cases/create_asset.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/assets/asset_fixtures.dart';
import '../../../../../mocks/asset_repository_mock.dart';

void main() {
  group('CreateAssetUseCase', () {
    test('returns the created asset from the repository', () async {
      // Given
      final repository = MockAssetRepository();
      final asset = currencyFixture();
      final expected = Success(asset);
      when(
        () => repository.create(asset),
      ).thenAnswer((_) async => expected);
      final useCase = CreateAssetUseCase(repository);

      // When
      final result = await useCase.call(asset);

      // Then
      expect(result, same(expected));
      verify(() => repository.create(asset)).called(1);
    });

    test('returns the repository failure when creation fails', () async {
      // Given
      final repository = MockAssetRepository();
      final asset = currencyFixture();
      const failure = RecordAlreadyExistsFailure(
        message: 'Asset ID already exists.',
      );
      when(
        () => repository.create(asset),
      ).thenAnswer((_) async => failure);
      final useCase = CreateAssetUseCase(repository);

      // When
      final result = await useCase.call(asset);

      // Then
      expect(result.failureOrNull, same(failure));
      verify(() => repository.create(asset)).called(1);
    });
  });
}
