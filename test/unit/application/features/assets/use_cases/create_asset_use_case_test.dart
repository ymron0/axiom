import 'package:axiom/src/features/assets/domain/failures/asset_already_exists_failure.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/application/use_cases/create_asset_use_case.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/assets/asset_fixtures.dart';
import '../../../../../mocks/asset_repository_mock.dart';

void main() {
  group('CreateAssetUseCase', () {
    late MockAssetRepository repository;
    late CreateAssetUseCase useCase;

    setUp(() {
      repository = MockAssetRepository();
      useCase = CreateAssetUseCase(repository);
    });

    test('returns the created asset', () async {
      // Given
      final asset = currencyFixture(id: 'create-asset', code: 'AAA');
      when(
        () => repository.create(asset),
      ).thenAnswer((_) async => Success<Asset>(asset));

      // When
      final result = await useCase.call(asset);

      // Then
      expect(result.valueOrNull, same(asset));
      verify(() => repository.create(asset)).called(1);
    });

    test('propagates duplicate failures', () async {
      // Given
      final asset = currencyFixture(id: 'duplicate-asset', code: 'AAA');
      const failure = AssetAlreadyExistsFailure(message: 'duplicate asset');
      when(() => repository.create(asset)).thenAnswer((_) async => failure);

      // When
      final result = await useCase.call(asset);

      // Then
      expect(result.failureOrNull, same(failure));
    });

    test('propagates repository failures', () async {
      // Given
      final asset = currencyFixture(id: 'failed-create', code: 'AAA');
      const failure = AssetAlreadyExistsFailure(message: 'write failed');
      when(() => repository.create(asset)).thenAnswer((_) async => failure);

      // When
      final result = await useCase.call(asset);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
