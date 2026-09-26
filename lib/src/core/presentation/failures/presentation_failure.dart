

import 'package:axiom/src/core/presentation/failures/presentation_failure_kind.dart';

/// User-facing representation of a failure.
///
/// Presentation failures deliberately contain no domain behavior. They translate
/// failures crossing into the presentation layer into information that can be
/// rendered consistently by widgets.
///
/// ## Invariants
///
/// [title] and [message] are always suitable for presentation to the user.
/// [failureType] is diagnostic metadata and must never be required for
/// rendering the failure.
///
/// ## Semantics
///
/// [kind] allows widgets to select presentation behavior without depending on
/// feature-specific domain failures.
///
/// ## Contract
///
/// Domain and application failures must be converted through
/// `PresentationFailureMapper` rather than interpreted directly by widgets.
final class PresentationFailure {
  final PresentationFailureKind kind;
  final String title;
  final String message;
  final String? failureType;

  /// Creates a presentation failure.
  const PresentationFailure({
    required this.kind,
    required this.title,
    required this.message,
    this.failureType,
  });
}
