import 'package:dart_mappable/dart_mappable.dart';

part 'account_kind.mapper.dart';

/// Describes the financial purpose or behavior of an account.
///
/// The kind provides semantic information for presentation, filtering,
/// reporting, and future account-specific behavior without determining the
/// account's currency or current balance.
@MappableEnum()
enum AccountKind {
  cash,
  checking,
  creditCard,
  investment,
  onlineWallet,
  savings,
}
