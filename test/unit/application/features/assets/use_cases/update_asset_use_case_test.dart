import 'package:axiom/src/core/failures/record_not_found_failure.dart';
import 'package:axiom/src/core/failures/unexpected_persistence_failure.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/application/use_cases/update_asset_use_case.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/assets/asset_fixtures.dart';
import '../../../../../mocks/asset_repository_mock.dart';

void main() {
  group('UpdateAssetUseCase', () {
    late MockAssetRepository repository;
    late UpdateAssetUseCase useCase;

    setUp(() {
      repository = MockAssetRepository();
      useCase = UpdateAssetUseCase(repository);
    });

    test('returns the updated asset', () async {
      // Given
      final asset = currencyFixture(id: 'update-asset', code: 'AAA');
      when(
        () => repository.update(asset),
      ).thenAnswer((_) async => Success<Asset>(asset));

      // When
      final result = await useCase.call(asset);

      // Then
      expect(result.valueOrNull, same(asset));
      verify(() => repository.update(asset)).called(1);
    });

    test('propagates not-found failures', () async {
      // Given
      final asset = currencyFixture(id: 'missing-update', code: 'AAA');
      const failure = RecordNotFoundFailure(message: 'asset not found');
      when(
        () => repository.update(asset),
      ).thenAnswer((_) async => failure);

      // When
      final result = await useCase.call(asset);

      // Then
      expect(result.failureOrNull, same(failure));
    });

    test('propagates repository failures', () async {
      // Given
      final asset = currencyFixture(id: 'failed-update', code: 'AAA');
      const failure = UnexpectedPersistenceFailure(message: 'update failed');
      when(
        () => repository.update(asset),
      ).thenAnswer((_) async => failure);

      // When
      final result = await useCase.call(asset);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
