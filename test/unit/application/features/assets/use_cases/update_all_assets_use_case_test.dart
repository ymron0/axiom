import 'package:axiom/src/features/assets/domain/failures/asset_not_found_failure.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/application/use_cases/update_all_assets_use_case.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/assets/asset_fixtures.dart';
import '../../../../../mocks/asset_repository_mock.dart';

void main() {
  group('UpdateAllAssetsUseCase', () {
    late MockAssetRepository repository;
    late UpdateAllAssetsUseCase useCase;

    setUp(() {
      repository = MockAssetRepository();
      useCase = UpdateAllAssetsUseCase(repository);
    });

    test('returns all updated assets', () async {
      // Given
      final assets = [
        currencyFixture(id: 'update-all-first', code: 'AAA'),
        currencyFixture(id: 'update-all-second', code: 'BBB'),
      ];
      when(
        () => repository.updateAll(assets),
      ).thenAnswer((_) async => Success<List<Asset>>(assets));

      // When
      final result = await useCase.call(assets);

      // Then
      expect(result.valueOrNull, same(assets));
      verify(() => repository.updateAll(assets)).called(1);
    });

    test('propagates not-found failures for a batch', () async {
      // Given
      final assets = [currencyFixture(id: 'missing-update-batch', code: 'AAA')];
      const failure = AssetNotFoundFailure(message: 'asset not found');
      when(() => repository.updateAll(assets)).thenAnswer((_) async => failure);

      // When
      final result = await useCase.call(assets);

      // Then
      expect(result.failureOrNull, same(failure));
    });

    test('propagates repository failures', () async {
      // Given
      final assets = [currencyFixture(id: 'failed-update-batch', code: 'AAA')];
      const failure = AssetNotFoundFailure(message: 'batch failed');
      when(() => repository.updateAll(assets)).thenAnswer((_) async => failure);

      // When
      final result = await useCase.call(assets);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
