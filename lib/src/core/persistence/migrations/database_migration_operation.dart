// coverage:ignore-file

import 'package:sembast/sembast_io.dart';

/// Performs one database schema migration inside an existing transaction.
///
/// Migration operations receive a [Transaction] rather than a [Database] so
/// that every write performed by a migration participates in the atomic
/// migration transaction managed by [DatabaseMigrator].
typedef DatabaseMigrationOperation =
    Future<void> Function(Transaction transaction);
