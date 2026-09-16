@Tags(['di'])
library;

import 'package:axiom/src/application/di/services/get_jar_progress_service_provider.dart';
import 'package:axiom/src/application/services/get_jar_progress_service.dart';
import 'package:axiom/src/features/jars/application/use_cases/get_jar_by_id_use_case.dart';
import 'package:axiom/src/features/jars/di/get_jar_by_id_use_case_provider.dart';
import 'package:axiom/src/features/settings/application/use_cases/get_settings_use_case.dart';
import 'package:axiom/src/features/settings/di/get_settings_use_case_provider.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_transactions_by_jar_id_use_case.dart';
import 'package:axiom/src/features/transactions/di/get_transactions_by_jar_id_use_case_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

import '../../../../mocks/jar_repository_mock.dart';
import '../../../../mocks/settings_repository_mock.dart';
import '../../../../mocks/transaction_repository_mock.dart';

void main() {
  group('getJarProgressService provider', () {
    test('resolves the jar progress service', () {
      final container = ProviderContainer(
        overrides: [
          getJarByIdUseCaseProvider.overrideWithValue(
            GetJarByIdUseCase(MockJarRepository()),
          ),
          getSettingsUseCaseProvider.overrideWithValue(
            GetSettingsUseCase(MockSettingsRepository()),
          ),
          getTransactionsByJarIdUseCaseProvider.overrideWithValue(
            GetTransactionsByJarIdUseCase(MockTransactionRepository()),
          ),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(getJarProgressServiceProvider);

      expect(service, isA<GetJarProgressService>());
    });
  });
}
