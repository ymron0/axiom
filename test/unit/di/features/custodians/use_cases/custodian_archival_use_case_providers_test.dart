@Tags(['application', 'di'])
library;

import 'dart:io';

import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/core/di/database_lifecycle_service_provider.dart';
import 'package:axiom/src/core/di/database_root_path_provider.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/custodians/application/use_cases/archive_custodian_use_case.dart';
import 'package:axiom/src/features/custodians/application/use_cases/get_active_custodians_use_case.dart';
import 'package:axiom/src/features/custodians/application/use_cases/get_archived_custodians_use_case.dart';
import 'package:axiom/src/features/custodians/application/use_cases/unarchive_custodian_use_case.dart';
import 'package:axiom/src/features/custodians/di/archive_custodian_use_case_provider.dart';
import 'package:axiom/src/features/custodians/di/custodian_repository_provider.dart';
import 'package:axiom/src/features/custodians/di/get_active_custodians_use_case_provider.dart';
import 'package:axiom/src/features/custodians/di/get_archived_custodians_use_case_provider.dart';
import 'package:axiom/src/features/custodians/di/unarchive_custodian_use_case_provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/custodians/custodian_fixtures.dart';
import '../../../../../mocks/custodian_repository_mock.dart';

void main() {
  final timestamp = DateTime.utc(2026, 1, 2);

  group('custodian archival use-case providers', () {
    test('resolves all archival use cases with the default repository', () async {
      // Given
      final rootPath = _uniqueRootPath();
      final rootDirectory = Directory(rootPath);
      final container = ProviderContainer(
        overrides: [databaseRootPathProvider.overrideWithValue(rootPath)],
      );
      final lifecycleService = container.read(databaseLifecycleServiceProvider);
      addTearDown(() async {
        await lifecycleService.close();
        container.dispose();
        if (await rootDirectory.exists()) {
          await rootDirectory.delete(recursive: true);
        }
      });

      // Then
      expect((await lifecycleService.open()).isSuccess, isTrue);
      expect(container.read(archiveCustodianUseCaseProvider), isA<ArchiveCustodianUseCase>());
      expect(container.read(unarchiveCustodianUseCaseProvider), isA<UnarchiveCustodianUseCase>());
      expect(container.read(getActiveCustodiansUseCaseProvider), isA<GetActiveCustodiansUseCase>());
      expect(container.read(getArchivedCustodiansUseCaseProvider), isA<GetArchivedCustodiansUseCase>());
    });

    test('forwards overridden dependencies', () async {
      // Given
      final repository = MockCustodianRepository();
      final custodian = custodianFixture(id: 'provider-custodian');
      when(() => repository.archive(custodian.id, timestamp)).thenAnswer(
        (_) async => Success(custodian),
      );
      when(() => repository.unarchive(custodian.id, timestamp)).thenAnswer(
        (_) async => Success(custodian),
      );
      when(() => repository.getActive()).thenAnswer(
        (_) async => Success([custodian]),
      );
      when(() => repository.getArchived()).thenAnswer(
        (_) async => Success([custodian]),
      );
      final container = ProviderContainer(
        overrides: [
          custodianRepositoryProvider.overrideWithValue(repository),
          clockProvider.overrideWithValue(FixedClock(timestamp)),
        ],
      );
      addTearDown(container.dispose);

      // When
      await container.read(archiveCustodianUseCaseProvider)(custodian.id);
      await container.read(unarchiveCustodianUseCaseProvider)(custodian.id);
      await container.read(getActiveCustodiansUseCaseProvider)();
      await container.read(getArchivedCustodiansUseCaseProvider)();

      // Then
      verify(() => repository.archive(custodian.id, timestamp)).called(1);
      verify(() => repository.unarchive(custodian.id, timestamp)).called(1);
      verify(() => repository.getActive()).called(1);
      verify(() => repository.getArchived()).called(1);
    });
  });
}

String _uniqueRootPath() {
  return p.join(
    Directory.systemTemp.path,
    'custodian-archival-use-case-providers-'
    '${DateTime.now().microsecondsSinceEpoch}',
  );
}
