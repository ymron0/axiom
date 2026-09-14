@Tags(['application'])
library;

import 'package:axiom/src/application/di/services/delete_jar_service_provider.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/jars/di/delete_jar_use_case_provider.dart';
import 'package:axiom/src/features/transactions/di/transactions_exist_by_jar_id_use_case_provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

import '../../../../fixtures/features/jars/jar_fixtures.dart';
import '../../../../mocks/delete_jar_use_case_mock.dart';
import '../../../../mocks/transactions_exist_by_jar_id_use_case_mock.dart';

void main() {
  group('deleteJarServiceProvider', () {
    test('uses the configured transaction check and jar deletion', () async {
      // Given
      final transactionsExist = MockTransactionsExistByJarIdUseCase();
      final deleteJar = MockDeleteJarUseCase();
      final jar = jarFixture(id: 'provider-jar');
      when(() => transactionsExist(jar.id)).thenAnswer(
        (_) async => const Success(false),
      );
      when(() => deleteJar(jar.id)).thenAnswer(
        (_) async => Success(jar),
      );
      final container = ProviderContainer(
        overrides: [
          transactionsExistByJarIdUseCaseProvider.overrideWithValue(
            transactionsExist,
          ),
          deleteJarUseCaseProvider.overrideWithValue(deleteJar),
        ],
      );
      addTearDown(container.dispose);

      // When
      final result = await container.read(deleteJarServiceProvider)(jar.id);

      // Then
      expect(result.valueOrNull, same(jar));
      verify(() => transactionsExist(jar.id)).called(1);
      verify(() => deleteJar(jar.id)).called(1);
    });
  });
}
