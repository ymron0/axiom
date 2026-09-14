/// Reserved Sembast record keys used by persistence implementations.
///
/// Most persisted entities use their domain identifier value as their Sembast
/// record key. Constants belong here only when a persisted record has no
/// natural domain identifier and therefore requires a stable infrastructure
/// key.
///
/// Reserved keys are part of the persistent database schema and must not be
/// changed after release without a database migration.
abstract final class SembastRecordKeys {
  /// Key of the application's singleton settings record.
  static const String settings = 'settings';
}