import 'package:mocktail/mocktail.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/src/database_client_impl.dart';
import 'package:sembast/src/store_impl.dart';

/// A mock Sembast database client for integrity-probe tests.
class MockIntegrityDatabaseClient extends Mock
    implements Database, SembastDatabaseClient {}

/// A mock Sembast store for integrity-probe tests.
class MockIntegrityStore extends Mock implements SembastStore {}
