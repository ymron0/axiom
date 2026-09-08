import 'package:axiom/src/core/failures/record_not_found_failure.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/application/use_cases/update_asset.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/assets/asset_fixtures.dart';
import '../../../../../mocks/asset_repository_mock.dart';

void main() {
  group('UpdateAssetUseCase', () {
    test('returns the updated asset from the repository', () async {
      // Given
      final repository = MockAssetRepository();
      final asset = currencyFixture();
      final expected = Success(asset);
      when(
        () => repository.update(asset),
      ).thenAnswer((_) async => expected);
      final useCase = UpdateAssetUseCase(repository);

      // When
      final result = await useCase.call(asset);

      // Then
      expect(result, same(expected));
      verify(() => repository.update(asset)).called(1);
    });

    test('returns the repository failure when updating fails', () async {
      // Given
      final repository = MockAssetRepository();
      final asset = currencyFixture();
      const failure = RecordNotFoundFailure(
        message: 'Asset ID was not found.',
      );
      when(
        () => repository.update(asset),
      ).thenAnswer((_) async => failure);
      final useCase = UpdateAssetUseCase(repository);

      // When
      final result = await useCase.call(asset);

      // Then
      expect(result.failureOrNull, same(failure));
      verify(() => repository.update(asset)).called(1);
    });
  });
}
