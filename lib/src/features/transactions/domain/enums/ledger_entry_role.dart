// coverage:ignore-file

import 'package:dart_mappable/dart_mappable.dart';

part 'ledger_entry_role.mapper.dart';

/// Describes the economic purpose of a ledger entry within a transaction.
///
/// A ledger-entry role classifies why an entry exists. It does not describe
/// the direction of the asset movement, the transaction kind, or presentation
/// behaviour.
///
/// A transaction may contain one or more [primary] entries and, where
/// applicable, separate [fee] entries.
@MappableEnum()
enum LedgerEntryRole {
  /// Represents a principal economic movement of the transaction.
  ///
  /// This excludes amounts represented separately as [fee] entries.
  primary,

  /// Represents an amount attributable to a fee, commission, or similar
  /// transaction cost.
  fee,
}
