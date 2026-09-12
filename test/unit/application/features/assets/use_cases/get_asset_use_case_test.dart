import 'package:axiom/src/features/assets/domain/failures/asset_already_exists_failure.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_asset_use_case.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/assets/asset_fixtures.dart';
import '../../../../../mocks/asset_repository_mock.dart';

void main() {
  group('GetAssetUseCase', () {
    late MockAssetRepository repository;
    late GetAssetUseCase useCase;

    setUp(() {
      repository = MockAssetRepository();
      useCase = GetAssetUseCase(repository);
    });

    test('returns all assets from the injected repository', () async {
      // Given
      final assets = [currencyFixture(id: 'get-all-asset', code: 'AAA')];
      when(
        () => repository.getAll(),
      ).thenAnswer((_) async => Success<List<Asset>>(assets));

      // When
      final result = await useCase.call();

      // Then
      expect(result.valueOrNull, same(assets));
      verify(() => repository.getAll()).called(1);
    });

    test('propagates repository failures', () async {
      // Given
      const failure = AssetAlreadyExistsFailure(message: 'read failed');
      when(() => repository.getAll()).thenAnswer((_) async => failure);

      // When
      final result = await useCase.call();

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
