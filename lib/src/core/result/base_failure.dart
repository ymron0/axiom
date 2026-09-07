// coverage:ignore-file

/// Defines the information exposed by every failure.
abstract interface class BaseFailure {
  /// The stable, namespaced identifier for this kind of failure.
  String get type;

  /// Describes the failure when additional context is available.
  String? get message;
}
