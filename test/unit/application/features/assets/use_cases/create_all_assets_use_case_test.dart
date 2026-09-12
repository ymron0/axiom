import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/features/assets/domain/failures/asset_already_exists_failure.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/application/commands/create_all_assets_command.dart';
import 'package:axiom/src/features/assets/application/use_cases/create_all_assets_use_case.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/assets/asset_command_fixtures.dart';
import '../../../../../mocks/asset_repository_mock.dart';

void main() {
  group('CreateAllAssetsUseCase', () {
    late MockAssetRepository repository;
    late CreateAllAssetsUseCase useCase;
    final timestamp = DateTime.utc(2026, 1, 1);

    setUpAll(() {
      registerFallbackValue(<Asset>[]);
    });

    setUp(() {
      repository = MockAssetRepository();
      useCase = CreateAllAssetsUseCase(
        repository: repository,
        clock: FixedClock(timestamp),
      );
    });

    test('returns all created assets', () async {
      // Given
      final command = CreateAllAssetsCommand(
        commands: [
          createAssetCommandFixture(code: 'AAA'),
          createAssetCommandFixture(code: 'BBB'),
        ],
      );
      when(
        () => repository.createAll(any()),
      ).thenAnswer((_) async => const Success<List<Asset>>([]));

      // When
      final result = await useCase.call(command);

      // Then
      final assets = result.valueOrNull!;
      expect(assets.map((asset) => asset.code), [
        command.commands[0].code,
        command.commands[1].code,
      ]);
      expect(assets.map((asset) => asset.createdAt), everyElement(timestamp));
      verify(() => repository.createAll(assets)).called(1);
    });

    test('propagates duplicate failures for a batch', () async {
      // Given
      final command = CreateAllAssetsCommand(
        commands: [
          createAssetCommandFixture(code: 'AAA'),
          createAssetCommandFixture(code: 'AAA'),
        ],
      );
      const failure = AssetAlreadyExistsFailure(message: 'duplicate code');
      when(() => repository.createAll(any())).thenAnswer((_) async => failure);

      // When
      final result = await useCase.call(command);

      // Then
      expect(result.failureOrNull, same(failure));
    });

    test('propagates repository failures', () async {
      // Given
      final command = CreateAllAssetsCommand(
        commands: [createAssetCommandFixture(code: 'AAA')],
      );
      const failure = AssetAlreadyExistsFailure(message: 'batch failed');
      when(() => repository.createAll(any())).thenAnswer((_) async => failure);

      // When
      final result = await useCase.call(command);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
