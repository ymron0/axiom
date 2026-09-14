@Tags(['di'])
library;

import 'package:axiom/src/application/di/services/get_jar_progress_service_provider.dart';
import 'package:axiom/src/application/services/get_jar_progress_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

void main() {
  group('getJarProgressService provider', () {
    test('resolves the jar progress service', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final service = container.read(getJarProgressServiceProvider);

      expect(service, isA<GetJarProgressService>());
    });
  });
}
