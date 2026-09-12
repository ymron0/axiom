import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/features/assets/domain/failures/asset_already_exists_failure.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/application/use_cases/create_asset_use_case.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/assets/asset_command_fixtures.dart';
import '../../../../../fixtures/features/assets/asset_fixtures.dart';
import '../../../../../mocks/asset_repository_mock.dart';

void main() {
  group('CreateAssetUseCase', () {
    late MockAssetRepository repository;
    late CreateAssetUseCase useCase;
    final timestamp = DateTime.utc(2026, 1, 1);

    setUpAll(() {
      registerFallbackValue(currencyFixture(id: 'fallback', code: 'AAA'));
    });

    setUp(() {
      repository = MockAssetRepository();
      useCase = CreateAssetUseCase(
        repository: repository,
        clock: FixedClock(timestamp),
      );
    });

    test('returns the created asset', () async {
      // Given
      final command = createAssetCommandFixture(code: 'AAA');
      when(
        () => repository.create(any()),
      ).thenAnswer(
        (_) async => Success<Asset>(
          currencyFixture(id: 'repository-result', code: 'AAA'),
        ),
      );

      // When
      final result = await useCase.call(command);

      // Then
      final asset = result.valueOrNull!;
      expect(asset, isA<Currency>());
      expect(asset.name, command.name);
      expect(asset.code, command.code);
      expect(asset.createdAt, timestamp);
      expect(asset.modifiedAt, timestamp);
      expect(asset.entityVersion, 1);
      verify(() => repository.create(asset)).called(1);
    });

    test('propagates duplicate failures', () async {
      // Given
      final command = createAssetCommandFixture(code: 'AAA');
      const failure = AssetAlreadyExistsFailure(message: 'duplicate asset');
      when(() => repository.create(any())).thenAnswer((_) async => failure);

      // When
      final result = await useCase.call(command);

      // Then
      expect(result.failureOrNull, same(failure));
    });

    test('propagates repository failures', () async {
      // Given
      final command = createAssetCommandFixture(code: 'AAA');
      const failure = AssetAlreadyExistsFailure(message: 'write failed');
      when(() => repository.create(any())).thenAnswer((_) async => failure);

      // When
      final result = await useCase.call(command);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
