@Tags(['application', 'di'])
library;

import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/custodians/application/use_cases/create_custodian_use_case.dart';
import 'package:axiom/src/features/custodians/application/use_cases/delete_custodian_use_case.dart';
import 'package:axiom/src/features/custodians/application/use_cases/get_custodian_by_id_use_case.dart';
import 'package:axiom/src/features/custodians/application/use_cases/get_custodians_use_case.dart';
import 'package:axiom/src/features/custodians/application/use_cases/restore_custodian_use_case.dart';
import 'package:axiom/src/features/custodians/application/use_cases/search_custodians_use_case.dart';
import 'package:axiom/src/features/custodians/application/use_cases/update_custodian_use_case.dart';
import 'package:axiom/src/features/custodians/data/repositories/in_memory_custodian_repository_impl.dart';
import 'package:axiom/src/features/custodians/di/create_custodian_use_case_provider.dart';
import 'package:axiom/src/features/custodians/di/custodian_repository_provider.dart';
import 'package:axiom/src/features/custodians/di/delete_custodian_use_case_provider.dart';
import 'package:axiom/src/features/custodians/di/get_custodian_by_id_use_case_provider.dart';
import 'package:axiom/src/features/custodians/di/get_custodians_use_case_provider.dart';
import 'package:axiom/src/features/custodians/di/restore_custodian_use_case_provider.dart';
import 'package:axiom/src/features/custodians/di/search_custodians_use_case_provider.dart';
import 'package:axiom/src/features/custodians/di/update_custodian_use_case_provider.dart';
import 'package:axiom/src/features/custodians/domain/entities/custodian.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/custodians/custodian_command_fixtures.dart';
import '../../../../../fixtures/features/custodians/custodian_fixtures.dart';
import '../../../../../mocks/custodian_repository_mock.dart';

void main() {
  group('custodian use-case providers', () {
    setUpAll(() {
      registerFallbackValue(custodianFixture(id: 'fallback'));
    });

    test('resolves every use case from the default repository', () {
      // Given
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // When
      final repository = container.read(custodianRepositoryProvider);
      final useCases = [
        container.read(createCustodianUseCaseProvider),
        container.read(getCustodiansUseCaseProvider),
        container.read(getCustodianByIdUseCaseProvider),
        container.read(searchCustodiansUseCaseProvider),
        container.read(updateCustodianUseCaseProvider),
        container.read(deleteCustodianUseCaseProvider),
        container.read(restoreCustodianUseCaseProvider),
      ];

      // Then
      expect(repository, isA<InMemoryCustodianRepositoryImpl>());
      expect(useCases, hasLength(7));
      expect(useCases[0], isA<CreateCustodianUseCase>());
      expect(useCases[1], isA<GetCustodiansUseCase>());
      expect(useCases[2], isA<GetCustodianByIdUseCase>());
      expect(useCases[3], isA<SearchCustodiansUseCase>());
      expect(useCases[4], isA<UpdateCustodianUseCase>());
      expect(useCases[5], isA<DeleteCustodianUseCase>());
      expect(useCases[6], isA<RestoreCustodianUseCase>());
    });

    test('injects an overridden repository into every use case', () async {
      // Given
      final repository = MockCustodianRepository();
      final custodian = custodianFixture(id: 'provider-custodian');
      final deleted = custodianFixture(
        id: 'provider-deleted',
        deletedAt: DateTime.utc(2026, 1, 2),
      );
      final custodians = [custodian];
      when(
        () => repository.create(any()),
      ).thenAnswer((_) async => const Success(null));
      when(
        () => repository.getAll(),
      ).thenAnswer((_) async => Success<List<Custodian>>(custodians));
      when(
        () => repository.getById(custodian.id),
      ).thenAnswer((_) async => Success<Custodian?>(custodian));
      when(
        () => repository.search('custodian'),
      ).thenAnswer((_) async => Success<List<Custodian>>(custodians));
      when(
        () => repository.update(custodian),
      ).thenAnswer((_) async => const Success(null));
      when(
        () => repository.delete(custodian.id),
      ).thenAnswer((_) async => Success(custodian));
      when(
        () => repository.restore(deleted),
      ).thenAnswer((_) async => const Success(null));
      final container = ProviderContainer(
        overrides: [
          custodianRepositoryProvider.overrideWithValue(repository),
          clockProvider.overrideWithValue(
            FixedClock(DateTime.utc(2026, 1, 1)),
          ),
        ],
      );
      addTearDown(container.dispose);

      // When
      final created = await container.read(createCustodianUseCaseProvider)(
        createCustodianCommandFixture(),
      );
      await container.read(getCustodiansUseCaseProvider)();
      await container.read(getCustodianByIdUseCaseProvider)(custodian.id);
      await container.read(searchCustodiansUseCaseProvider)('custodian');
      await container.read(updateCustodianUseCaseProvider)(custodian);
      await container.read(deleteCustodianUseCaseProvider)(custodian.id);
      await container.read(restoreCustodianUseCaseProvider)(deleted);

      // Then
      verify(() => repository.create(created.valueOrNull!)).called(1);
      verify(() => repository.getAll()).called(1);
      verify(() => repository.getById(custodian.id)).called(1);
      verify(() => repository.search('custodian')).called(1);
      verify(() => repository.update(custodian)).called(1);
      verify(() => repository.delete(custodian.id)).called(1);
      verify(() => repository.restore(deleted)).called(1);
    });
  });
}
