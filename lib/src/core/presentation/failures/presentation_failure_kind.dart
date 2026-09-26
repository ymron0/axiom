// coverage:ignore-file

/// Describes the presentation-level category of an operation failure.
enum PresentationFailureKind {
  validation,
  notFound,
  conflict,
  blocked,
  unavailable,
  unknown,
}
