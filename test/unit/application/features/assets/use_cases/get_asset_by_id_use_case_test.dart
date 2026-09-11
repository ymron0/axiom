import 'package:axiom/src/core/failures/unexpected_persistence_failure.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_asset_by_id_use_case.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/assets/asset_fixtures.dart';
import '../../../../../mocks/asset_repository_mock.dart';

void main() {
  group('GetAssetByIdUseCase', () {
    late MockAssetRepository repository;
    late GetAssetByIdUseCase useCase;

    setUp(() {
      repository = MockAssetRepository();
      useCase = GetAssetByIdUseCase(repository);
    });

    test('returns the matching asset from the injected repository', () async {
      // Given
      final asset = currencyFixture(id: 'by-id-asset', code: 'AAA');
      when(
        () => repository.getById(asset.id),
      ).thenAnswer((_) async => Success<Asset?>(asset));

      // When
      final result = await useCase.call(asset.id);

      // Then
      expect(result.valueOrNull, same(asset));
      verify(() => repository.getById(asset.id)).called(1);
    });

    test('preserves a missing asset result', () async {
      // Given
      final id = AssetId.fromString('missing-asset');
      when(
        () => repository.getById(id),
      ).thenAnswer((_) async => const Success<Asset?>(null));

      // When
      final result = await useCase.call(id);

      // Then
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, isNull);
    });

    test('propagates repository failures', () async {
      // Given
      final id = AssetId.fromString('failed-asset');
      const failure = UnexpectedPersistenceFailure(message: 'read failed');
      when(
        () => repository.getById(id),
      ).thenAnswer((_) async => failure);

      // When
      final result = await useCase.call(id);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
