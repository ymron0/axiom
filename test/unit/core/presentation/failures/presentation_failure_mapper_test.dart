@Tags(['presentation'])
library;

import 'package:axiom/src/application/failures/transaction_would_exceed_budget_failure.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_not_found_failure.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_repository_failure.dart';
import 'package:axiom/src/core/presentation/failures/presentation_failure_kind.dart';
import 'package:axiom/src/core/presentation/failures/presentation_failure_mapper.dart';
import 'package:test/test.dart';

void main() {
  group('PresentationFailureMapper', () {
    const mapper = PresentationFailureMapper();

    test('maps not-found failures', () {
      const failure = AccountNotFoundFailure(
        message: 'The account no longer exists.',
      );

      final error = mapper.fromFailure(failure);

      expect(error.kind, PresentationFailureKind.notFound);
      expect(error.title, 'Not found');
      expect(error.message, 'The account no longer exists.');
      expect(error.failureType, AccountNotFoundFailure.typeId);
    });

    test('maps validation failures', () {
      const failure = TransactionWouldExceedBudgetFailure(
        message: 'This transaction would exceed the category budget.',
      );

      final error = mapper.fromFailure(failure);

      expect(error.kind, PresentationFailureKind.validation);
      expect(
        error.message,
        'This transaction would exceed the category budget.',
      );
    });

    test('does not expose repository implementation details', () {
      const failure = AccountRepositoryFailure(
        message: 'Sembast write failed at accounts.store.',
      );

      final error = mapper.fromFailure(failure);

      expect(error.kind, PresentationFailureKind.unavailable);
      expect(error.message, 'The data could not be loaded. Please try again.');
      expect(error.message, isNot(contains('Sembast')));
    });

    test('maps unexpected errors to a safe generic message', () {
      final error = mapper.fromObject(
        StateError('Internal implementation detail'),
      );

      expect(error.kind, PresentationFailureKind.unknown);
      expect(error.title, 'Something went wrong');
      expect(error.message, 'An unexpected error occurred. Please try again.');
      expect(error.message, isNot(contains('Internal')));
    });
  });
}
