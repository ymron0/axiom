import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/presentation/failures/presentation_failure.dart';
import 'package:axiom/src/core/presentation/failures/presentation_failure_mapper.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:flutter_riverpod/experimental/mutation.dart';

/// Resolves a Riverpod mutation state into an optional user-facing failure.
///
/// Expected domain/application failures are carried inside [Result] and
/// therefore appear inside [MutationSuccess].
///
/// Unexpected exceptions thrown while executing a mutation appear as
/// [MutationError].
///
/// ## Semantics
///
/// A `null` return value means that no failure should currently be presented.
///
/// ## Contract
///
/// Feature forms should use this mapper instead of interpreting mutation
/// failures themselves.
PresentationFailure?
mapMutationFailure<T extends Object?, F extends BaseFailure>(
  MutationState<Result<T, F>> state, {
  PresentationFailureMapper mapper = const PresentationFailureMapper(),
}) {
  return switch (state) {
    MutationError(:final error) => mapper.fromObject(error),
    MutationSuccess(:final value) when value.isFailure => mapper.fromFailure(
      value.failureOrNull!,
    ),
    _ => null,
  };
}
