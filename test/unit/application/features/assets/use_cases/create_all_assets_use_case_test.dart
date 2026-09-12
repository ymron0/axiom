import 'package:axiom/src/features/assets/domain/failures/asset_already_exists_failure.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/application/use_cases/create_all_assets_use_case.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/assets/asset_fixtures.dart';
import '../../../../../mocks/asset_repository_mock.dart';

void main() {
  group('CreateAllAssetsUseCase', () {
    late MockAssetRepository repository;
    late CreateAllAssetsUseCase useCase;

    setUp(() {
      repository = MockAssetRepository();
      useCase = CreateAllAssetsUseCase(repository);
    });

    test('returns all created assets', () async {
      // Given
      final assets = [
        currencyFixture(id: 'create-all-first', code: 'AAA'),
        currencyFixture(id: 'create-all-second', code: 'BBB'),
      ];
      when(
        () => repository.createAll(assets),
      ).thenAnswer((_) async => Success<List<Asset>>(assets));

      // When
      final result = await useCase.call(assets);

      // Then
      expect(result.valueOrNull, same(assets));
      verify(() => repository.createAll(assets)).called(1);
    });

    test('propagates duplicate failures for a batch', () async {
      // Given
      final assets = [
        currencyFixture(id: 'duplicate-first', code: 'AAA'),
        currencyFixture(id: 'duplicate-second', code: 'AAA'),
      ];
      const failure = AssetAlreadyExistsFailure(message: 'duplicate code');
      when(() => repository.createAll(assets)).thenAnswer((_) async => failure);

      // When
      final result = await useCase.call(assets);

      // Then
      expect(result.failureOrNull, same(failure));
    });

    test('propagates repository failures', () async {
      // Given
      final assets = [currencyFixture(id: 'failed-batch', code: 'AAA')];
      const failure = AssetAlreadyExistsFailure(message: 'batch failed');
      when(() => repository.createAll(assets)).thenAnswer((_) async => failure);

      // When
      final result = await useCase.call(assets);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
