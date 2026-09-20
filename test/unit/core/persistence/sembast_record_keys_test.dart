@Tags(['core', 'data', 'persistence'])
library;

import 'package:axiom/src/core/persistence/sembast_record_keys.dart';
import 'package:test/test.dart';

void main() {
  group('SembastRecordKeys', () {
    test('uses stable settings record key', () {
      expect(SembastRecordKeys.settings, 'settings');
    });
  });
}
