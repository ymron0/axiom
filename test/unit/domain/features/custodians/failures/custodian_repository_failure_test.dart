import 'package:axiom/src/features/custodians/domain/failures/custodian_repository_failure.dart';
import 'package:test/test.dart';

void main() {
  group('CustodianRepositoryFailure', () {
    test('preserves its diagnostic failure information', () {
      const failure = CustodianRepositoryFailure(message: 'repository failed');

      expect(failure.message, 'repository failed');
      expect(failure.type, CustodianRepositoryFailure.typeId);
      expect(failure.failureOrNull, same(failure));
    });
  });
}
