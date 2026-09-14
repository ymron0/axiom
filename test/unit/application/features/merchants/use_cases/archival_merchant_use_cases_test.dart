import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/merchants/application/use_cases/archive_merchant_use_case.dart';
import 'package:axiom/src/features/merchants/application/use_cases/get_active_merchants_use_case.dart';
import 'package:axiom/src/features/merchants/application/use_cases/get_archived_merchants_use_case.dart';
import 'package:axiom/src/features/merchants/application/use_cases/unarchive_merchant_use_case.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/merchants/merchant_fixtures.dart';
import '../../../../../mocks/merchant_repository_mock.dart';

void main() {
  final timestamp = DateTime.utc(2026, 1, 2);

  group('merchant archival use cases', () {
    late MockMerchantRepository repository;
    late ArchiveMerchantUseCase archive;
    late UnarchiveMerchantUseCase unarchive;

    setUp(() {
      repository = MockMerchantRepository();
      final clock = FixedClock(timestamp);
      archive = ArchiveMerchantUseCase(repository: repository, clock: clock);
      unarchive = UnarchiveMerchantUseCase(repository: repository, clock: clock);
    });

    test('archive and unarchive forward the canonical timestamp', () async {
      // Given
      final merchant = merchantFixture(id: 'merchant');
      when(() => repository.archive(merchant.id, timestamp)).thenAnswer(
        (_) async => Success(merchant),
      );
      when(() => repository.unarchive(merchant.id, timestamp)).thenAnswer(
        (_) async => Success(merchant),
      );

      // When
      await archive(merchant.id);
      await unarchive(merchant.id);

      // Then
      verify(() => repository.archive(merchant.id, timestamp)).called(1);
      verify(() => repository.unarchive(merchant.id, timestamp)).called(1);
    });

    test('active and archived queries delegate unchanged', () async {
      // Given
      final active = merchantFixture(id: 'active');
      final archived = merchantFixture(
        id: 'archived',
        archivedAt: timestamp,
        modifiedAt: timestamp,
      );
      when(() => repository.getActive()).thenAnswer(
        (_) async => Success([active]),
      );
      when(() => repository.getArchived()).thenAnswer(
        (_) async => Success([archived]),
      );

      // When
      final activeResult = await GetActiveMerchantsUseCase(repository)();
      final archivedResult = await GetArchivedMerchantsUseCase(repository)();

      // Then
      expect(activeResult.valueOrNull, [active]);
      expect(archivedResult.valueOrNull, [archived]);
      verify(() => repository.getActive()).called(1);
      verify(() => repository.getArchived()).called(1);
    });
  });
}
