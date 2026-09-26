import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/presentation/failures/presentation_failure.dart';
import 'package:axiom/src/core/presentation/failures/presentation_failure_kind.dart';

/// Maps domain and application failures to safe user-facing failures.
///
/// ## Semantics
///
/// Expected failures preserve useful domain-provided messages where those
/// messages are appropriate for presentation. Infrastructure failures do not
/// expose their internal details.
///
/// Unexpected exceptions are intentionally represented by a generic message.
///
/// ## Contract
///
/// Widgets must not inspect failure type identifiers themselves. All such
/// interpretation belongs here.
final class PresentationFailureMapper {
  /// Creates a presentation failure mapper.
  const PresentationFailureMapper();

  /// Converts an expected failure into a presentation failure.
  PresentationFailure fromFailure(BaseFailure failure) {
    final normalizedType = _normalizeType(failure.type);

    if (_containsAny(normalizedType, const [
      'repository',
      'database',
      'persistence',
      'sourceunavailable',
      'acquisition',
      'integrity',
      'migration',
    ])) {
      return PresentationFailure(
        kind: PresentationFailureKind.unavailable,
        title: 'Something went wrong',
        message: 'The data could not be loaded. Please try again.',
        failureType: failure.type,
      );
    }

    if (_containsAny(normalizedType, const ['notfound', 'notinitialized'])) {
      return PresentationFailure(
        kind: PresentationFailureKind.notFound,
        title: 'Not found',
        message: _preferredMessage(
          failure,
          fallback: 'The requested item could not be found.',
        ),
        failureType: failure.type,
      );
    }

    if (_containsAny(normalizedType, const [
      'alreadyexists',
      'versionconflict',
      'synchronizationconflict',
      'conflict',
    ])) {
      return PresentationFailure(
        kind: PresentationFailureKind.conflict,
        title: 'Unable to save changes',
        message: _preferredMessage(
          failure,
          fallback:
              'The data has changed since it was loaded. '
              'Refresh and try again.',
        ),
        failureType: failure.type,
      );
    }

    if (_containsAny(normalizedType, const [
      'inuse',
      'notdeleted',
      'notarchived',
      'notassignable',
    ])) {
      return PresentationFailure(
        kind: PresentationFailureKind.blocked,
        title: 'Action unavailable',
        message: _preferredMessage(
          failure,
          fallback: 'This action cannot be completed right now.',
        ),
        failureType: failure.type,
      );
    }

    if (_containsAny(normalizedType, const [
      'invalid',
      'wouldexceed',
      'wouldmake',
      'mismatch',
      'validation',
      'unsupported',
    ])) {
      return PresentationFailure(
        kind: PresentationFailureKind.validation,
        title: 'Check the entered information',
        message: _preferredMessage(
          failure,
          fallback: 'Some of the entered information is not valid.',
        ),
        failureType: failure.type,
      );
    }

    return PresentationFailure(
      kind: PresentationFailureKind.unknown,
      title: 'Unable to complete the action',
      message: _preferredMessage(
        failure,
        fallback: 'The operation could not be completed.',
      ),
      failureType: failure.type,
    );
  }

  /// Converts an arbitrary error into a safe presentation failure.
  PresentationFailure fromObject(Object error) {
    if (error case final BaseFailure failure) {
      return fromFailure(failure);
    }

    return const PresentationFailure(
      kind: PresentationFailureKind.unknown,
      title: 'Something went wrong',
      message: 'An unexpected error occurred. Please try again.',
    );
  }

  String _normalizeType(String value) {
    return value.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
  }

  bool _containsAny(String value, List<String> fragments) {
    return fragments.any(value.contains);
  }

  String _preferredMessage(BaseFailure failure, {required String fallback}) {
    final message = failure.message?.trim();

    if (message == null || message.isEmpty) {
      return fallback;
    }

    return message;
  }
}
