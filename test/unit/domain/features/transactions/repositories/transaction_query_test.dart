import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_kind.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_state.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_query.dart';
import 'package:test/test.dart';

void main() {
  group('TransactionQuery', () {
    test('is empty when constructed without criteria', () {
      // Given / When
      final query = TransactionQuery();

      // Then
      expect(query.isEmpty, isTrue);
      expect(query.kinds, isEmpty);
      expect(query.states, isEmpty);
      expect(query.merchantIds, isEmpty);
      expect(query.accountIds, isEmpty);
    });

    test('is not empty when kinds contains a criterion', () {
      // Given / When
      final query = TransactionQuery(kinds: {TransactionKind.expense});

      // Then
      expect(query.isEmpty, isFalse);
    });

    test('is not empty when states contains a criterion', () {
      // Given / When
      final query = TransactionQuery(states: {TransactionState.actual});

      // Then
      expect(query.isEmpty, isFalse);
    });

    test('is not empty when merchantIds contains a criterion', () {
      // Given
      final merchantId = MerchantId.fromString('merchant-1');

      // When
      final query = TransactionQuery(merchantIds: {merchantId});

      // Then
      expect(query.isEmpty, isFalse);
    });

    test('is not empty when accountIds contains a criterion', () {
      // Given
      final accountId = AccountId.fromString('account-1');

      // When
      final query = TransactionQuery(accountIds: {accountId});

      // Then
      expect(query.isEmpty, isFalse);
    });

    test('copies and exposes all criteria as unmodifiable sets', () {
      // Given
      final merchantId = MerchantId.fromString('merchant-1');
      final accountId = AccountId.fromString('account-1');
      final kinds = {TransactionKind.expense};
      final states = {TransactionState.actual};
      final merchantIds = {merchantId};
      final accountIds = {accountId};

      // When
      final query = TransactionQuery(
        kinds: kinds,
        states: states,
        merchantIds: merchantIds,
        accountIds: accountIds,
      );
      kinds.add(TransactionKind.income);
      states.add(TransactionState.planned);
      merchantIds.add(MerchantId.fromString('merchant-2'));
      accountIds.add(AccountId.fromString('account-2'));

      // Then
      expect(query.kinds, {TransactionKind.expense});
      expect(query.states, {TransactionState.actual});
      expect(query.merchantIds, {merchantId});
      expect(query.accountIds, {accountId});
      expect(
        () => query.kinds.add(TransactionKind.income),
        throwsUnsupportedError,
      );
      expect(
        () => query.states.add(TransactionState.planned),
        throwsUnsupportedError,
      );
      expect(
        () => query.merchantIds.add(MerchantId.fromString('merchant-2')),
        throwsUnsupportedError,
      );
      expect(
        () => query.accountIds.add(AccountId.fromString('account-2')),
        throwsUnsupportedError,
      );
    });
  });
}
