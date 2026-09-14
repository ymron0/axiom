@Tags(['application'])
library;

import 'package:axiom/src/core/identity/ids/custodian_id.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/custodians/application/use_cases/archive_custodian_use_case.dart';
import 'package:axiom/src/features/custodians/application/use_cases/get_active_custodians_use_case.dart';
import 'package:axiom/src/features/custodians/application/use_cases/get_archived_custodians_use_case.dart';
import 'package:axiom/src/features/custodians/application/use_cases/unarchive_custodian_use_case.dart';
import 'package:axiom/src/features/custodians/domain/entities/custodian.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_not_found_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/custodians/custodian_fixtures.dart';
import '../../../../../mocks/custodian_repository_mock.dart';

void main() {
  final timestamp = DateTime.utc(2026, 1, 2);

  group('custodian archival use cases', () {
    late MockCustodianRepository repository;
    late ArchiveCustodianUseCase archive;
    late UnarchiveCustodianUseCase unarchive;

    setUpAll(() {
      registerFallbackValue(CustodianId.fromString('fallback-custodian'));
    });

    setUp(() {
      repository = MockCustodianRepository();
      final clock = FixedClock(timestamp);
      archive = ArchiveCustodianUseCase(
        repository: repository,
        clock: clock,
      );
      unarchive = UnarchiveCustodianUseCase(
        repository: repository,
        clock: clock,
      );
    });

    test('archive and unarchive forward the canonical timestamp', () async {
      // Given
      final custodian = custodianFixture(id: 'custodian');
      when(() => repository.archive(custodian.id, timestamp)).thenAnswer(
        (_) async => Success(custodian),
      );
      when(() => repository.unarchive(custodian.id, timestamp)).thenAnswer(
        (_) async => Success(custodian),
      );

      // When
      await archive(custodian.id);
      await unarchive(custodian.id);

      // Then
      verify(() => repository.archive(custodian.id, timestamp)).called(1);
      verify(() => repository.unarchive(custodian.id, timestamp)).called(1);
    });

    test('active and archived queries delegate unchanged', () async {
      // Given
      final active = custodianFixture(id: 'active');
      final archived = custodianFixture(id: 'archived');
      when(() => repository.getActive()).thenAnswer(
        (_) async => Success<List<Custodian>>([active]),
      );
      when(() => repository.getArchived()).thenAnswer(
        (_) async => Success<List<Custodian>>([archived]),
      );

      // When
      final activeResult = await GetActiveCustodiansUseCase(repository)();
      final archivedResult = await GetArchivedCustodiansUseCase(repository)();

      // Then
      expect(activeResult.valueOrNull, [active]);
      expect(archivedResult.valueOrNull, [archived]);
      verify(() => repository.getActive()).called(1);
      verify(() => repository.getArchived()).called(1);
    });

    test('propagates repository failures', () async {
      // Given
      const failure = CustodianNotFoundFailure(message: 'not found');
      when(() => repository.archive(any(), timestamp)).thenAnswer(
        (_) async => failure,
      );
      when(() => repository.getActive()).thenAnswer((_) async => failure);

      // When
      final archiveResult = await archive(custodianFixture(id: 'missing').id);
      final activeResult = await GetActiveCustodiansUseCase(repository)();

      // Then
      expect(archiveResult.failureOrNull, same(failure));
      expect(activeResult.failureOrNull, same(failure));
    });
  });
}
